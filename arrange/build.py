#!/usr/bin/env python3
"""Build the Pink Sweets "Rosy Arrange" u4 program ROM.

Usage:  python3 build.py <your pinkswts_u4> <output pinkswts_u4>

Input is either
  * the original 2006/04/06 MASTER VER. u4 (CRC32 5d812c9e): builds the
    standalone Rosy Arrange ROM (Rosy Arrange is the only mode; no Rosy
    Future code), or
  * the Pink Sweets Rosy Future u4 (CRC32 2b1d0fb1, rosy_arrange branch):
    makes its 5th menu entry ROSY'S ARRANGE play Rosy Arrange; the other four
    modes stay Rosy Future.
No game data is stored in this repository; everything is applied to your dump.

What it does
  * checks the Rosy Future HUD code is at u4 0x100000 (data/rosy_future_hud.bin)
  * assembles src/arrange.s and writes it at u4 0x101000 (CPU 0xA0101000)
  * points the reset code's unpacker call (literal at 0x18C) at boot_patch,
    which runs the original unpacker and then patches the unpacked program
    in RAM (Rosy Future hooks + Rosy Arrange hooks), so the compressed program
    itself is never modified.
Requires binutils for sh-elf (sh-elf-as, sh-elf-ld).
"""
import os, struct, subprocess, sys, tempfile, zlib

ROSY_FUTURE_CRC = 0x2B1D0FB1     # Rosy Future, rosy_arrange branch (ROSY'S ARRANGE menu entry)
ORIGINAL_CRC = 0x5D812C9E

HERE = os.path.dirname(os.path.abspath(__file__))
CODE_OFF = 0x101000
CODE_CPU = 0xA0101000      # ROM copy (boot_patch runs here once)
RAM_BASE = 0x0C7C0000      # boot_patch copies the patch here; everything else runs from RAM
HUD_OFF = 0x100000
BOOT_LIT = 0x18C
DECOMP = 0x0C002AC4

# (destination in unpacked program, bytes or symbol) -- written via the
# uncached alias 0xAC000000 | (addr & 0x00FFFFFF). The first entries match
# what Rosy Future already has; they are rewritten so the menu literal can
# point at the 5-entry menu and the frame hook at arr_frame.
PATCHES = [
    # Rosy Future: title-screen mode menu stub (calls through the literal below)
    (0x0C06E64A, bytes.fromhex("d002400b0009a0130009")),
    (0x0C06E654, "title_menu5"),
    (0x0C06E658, bytes.fromhex("0009" * 17)),
    # Rosy Future: credit-message gate for the idle player side
    (0x0C0754A0, bytes.fromhex("d001402b00090009a01006b4")),
    # per-frame gameplay hook (pool entry) -> arr_frame -> Rosy Future HUD -> original
    (0x0C0720EC, "arr_frame"),
    # port-read routine: jump to arr_input (mov.l @(lit),r1 / jmp @r1 / nop / nop)
    (0x0C0610F8, bytes.fromhex("d101412b00090009")),
    (0x0C061100, "arr_input"),
    # common item setup routine: jump to arr_item (mov.l @(lit),r1 / jmp @r1 / nop / nop)
    (0x0C083320, bytes.fromhex("d101412b00090009")),
    (0x0C083328, "arr_item"),
    # enemy drop routine: jump to arr_drop (mov.l @(lit),r1 / jmp @r1 / nop)
    (0x0C082B22, bytes.fromhex("d101412b0009")),
    (0x0C082B28, "arr_drop"),
    # 1UP pickup: jump to arr_life for the 5-icon cap (mov.l @(lit),r3 / jmp @r3 / nop)
    (0x0C084716, bytes.fromhex("d301432b0009")),
    (0x0C08471C, "arr_life"),
    (0x0C084720, bytes.fromhex("00090009")),
    # rose cracker hits -> 1,000-point items
    (0x0C0767C8, "arr_crkdmg"),         # cracker-vs-enemy damage call literal
    (0x0C076ACC, "arr_bullet"),         # cracker-vs-bullet cancel call literal
    (0x0C085038, bytes.fromhex("d501452b00090009")),  # mov.l @(lit),r5 / jmp @r5 / nop / nop
    (0x0C085040, "arr_hit"),
    # item pickup -> arr_collect (cracker-flower chain bonus); every caller of
    # the collect routine 0x0C0935C0 goes through its own literal
    (0x0C082E38, "arr_collect"),
    (0x0C083044, "arr_collect"),
    (0x0C083218, "arr_collect"),
    (0x0C0847A8, "arr_collect"),
    (0x0C0847F4, "arr_collect"),
    # top HUD score printer literal -> arr_print (9-digit scores one row lower)
    (0x0C072560, "arr_print"),
    (0x0C075928, "arr_print"),
    # respawn rank-down call literal -> arr_rankdn (flat 10 RK points)
    (0x0C07EB60, "arr_rankdn"),
    # sprite routine entry -> arr_spr (Rosy Arrange How to Play screen)
    (0x0C07C210, bytes.fromhex("d001402b0009")),
    (0x0C07C218, "arr_spr"),
    # main loop's blitter kick: jump to arr_kick (mov.l @(lit),r0 / jmp @r0 / nop / lit)
    (0x0C062082, bytes.fromhex("d001402b0009")),
    (0x0C062088, "arr_kick"),
]

# ---- "1000x2" .. "1000x64" pop-up labels -------------------------------------
# The labels are put together in video RAM at run time by a blitter list: the
# "x" (data/popup_x.bin, our own 16x11 ARGB1555 glyph) is uploaded once, and
# the game's own "1000" and digit sprites are copied next to it. Only VRAM
# coordinates are stored here, no game graphics.
# The pop-up sheet's page is at VRAM (0x1900, 0x300); the screen is rotated, so
# a label's left-to-right reading order runs along VRAM y.
PAGE_X, PAGE_Y = 0x1900, 0x300
SRC_1000 = (0x19E0, 0x378 + 2, 45)      # "1000" (upright columns 2..46)
SRC_ONE = (0x19E0, 0x378 + 2, 8)        # its "1"
SRC_DIGIT = {d: (PAGE_X + (w >> 8), PAGE_Y + (w & 0xFF) + 2, 13)   # first digit of
             for d, w in ((2, 0xF028), (3, 0xF050), (4, 0xF078),       # "200".."800"
                          (6, 0xF0C8), (8, 0xE028))}
X_SCRATCH = (0x30, 240)                 # page offsets of the uploaded "x"
LABELS = []   # the "1000x<n>" labels are put together at run time by mk_label
              # (src/arrange.s); this list only uploads the "x"


def labels_inc():
    xpix = open(os.path.join(HERE, "data", "popup_x.bin"), "rb").read()
    assert len(xpix) == 16 * 11 * 2
    words = [0xC000, 0x0000,                                  # clip: whole VRAM
             0x2000, 0x0000, 0x9999, 0x9999,                  # upload the "x"
             PAGE_X + X_SCRATCH[0], PAGE_Y + X_SCRATCH[1], 15, 10]
    words += list(struct.unpack(">176H", xpix))
    defs = []

    def draw(src, dx, dy):
        sx, sy, h = src
        words.extend([0x1100, 0x0000, sx, sy, dx, dy, 15, h - 1, 0x0080, 0x8080])

    for mult, ox, oy in LABELS:
        lx, ly = PAGE_X + ox, PAGE_Y + oy
        draw(SRC_1000, lx, ly + 1)
        draw((PAGE_X + X_SCRATCH[0], PAGE_Y + X_SCRATCH[1], 11), lx, ly + 46)
        pos = 57
        for i, ch in enumerate(str(mult) if mult else ""):
            src = SRC_ONE if ch == "1" else SRC_DIGIT[int(ch)]
            if i and src[2] == 13 and prev == 13:
                pos -= 1                                    # digits share an outline column
            draw(src, lx, ly + pos)
            pos += src[2]
            prev = src[2]
        h = (pos + 2) & ~1
        assert oy + h <= (96 if oy == 0 else 256) and oy % 32 == 0
        defs.append((ox, oy, h))
    words += [0x0000, 0x0000]
    if len(words) % 2:
        words.append(0)
    lines = ["        .align 2", "blit_list:"]
    for i in range(0, len(words), 8):
        lines.append("        .word " + ",".join(f"0x{w:04X}" for w in words[i:i + 8]))
    lines += ["blit_end:", "        .align 2", "lab_frames:"]
    # the sprite routine takes flip flags from the top two bits of a def
    # pointer, so point at the defs through the plain physical address
    lines += [f"        .long lab_def{i}, 0x0C106310" for i in range(len(defs))]
    for i, (ox, oy, h) in enumerate(defs):
        lines += [f"lab_def{i}:",
                  f"        .word 0x1401, 0x{ox:02X}{oy:02X}, 0xF8{(-(h // 2)) & 0xFF:02X}, 0x0F{h - 1:02X}, 0, 0, 0, 0, 0"]
    lines += ["        .align 2", ""]
    return "\n".join(lines)


def unswap(b):
    o = bytearray(len(b))
    o[0::2] = b[1::2]
    o[1::2] = b[0::2]
    return o


STANDALONE_PATCHES = [
    # title-screen mode select: always Rosy Arrange (title_menu5 built STANDALONE)
    (0x0C06E64A, bytes.fromhex("d002400b0009a0130009")),
    (0x0C06E654, "title_menu5"),
    (0x0C06E658, bytes.fromhex("0009" * 17)),
    # credit-message gate for the idle player side (our own copy of Rosy Future's)
    (0x0C0754A0, bytes.fromhex("d001402b00090009")),
    (0x0C0754A8, "cred_gate"),
]



# ---- boss health bar tiles (combined build, ROSY'S ARRANGE HUD) --------------
# 3 colours x (left end 0..7 px, middle 0..8 px, right end 0..7 px) filled:
# char BAR_CHAR + colour * 32 + type * 9 + n. 8 x 8 cells: white outline on
# rows 1 and 7 (and the outer column of the ends), fill on rows 2..6, the rest
# transparent. Uploaded once into the unused text-font chars 0x400..
# (char k at VRAM x = 0x8F8 - (k >> 5) * 8, y = (k & 31) * 8, stored rotated
# 90 deg clockwise).
BAR_CHAR = 0x400
BAR_DIGC = 0x460                  # countdown cells (after the 3 x 32 bar chars)
BAR_COLOURS = [(40, 220, 60), (240, 220, 40), (230, 30, 30)]   # green, yellow, red


def bar_inc():
    from PIL import Image
    W = (255, 255, 255)
    vram = {}
    for c, col in enumerate(BAR_COLOURS):
        for t, (cap, x0) in enumerate(((7, 1), (8, 0), (7, 0))):
            for n in range(cap + 1):
                tile = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
                for x in range(8):
                    tile.putpixel((x, 1), W + (255,))
                    tile.putpixel((x, 7), W + (255,))
                ox = 0 if t == 0 else (7 if t == 2 else None)
                if ox is not None:
                    for y in range(1, 8):
                        tile.putpixel((ox, y), W + (255,))
                for x in range(x0, x0 + n):
                    for y in range(2, 7):
                        tile.putpixel((x, y), col + (255,))
                k = BAR_CHAR + c * 32 + t * 9 + n
                tile = tile.rotate(-90)
                vx, vy = 0x8F8 - (k >> 5) * 8, (k & 31) * 8
                for yy in range(8):
                    for xx in range(8):
                        r, g, b_, al = tile.getpixel((xx, yy))
                        w = ((r >> 3) << 10) | ((g >> 3) << 5) | (b_ >> 3)
                        vram[(vx + xx, vy + yy)] = (w | 0x8000) if al else 0
    # countdown cells (red bar, health 1..15): the middle cell (cell 4) with
    # the number in white 3 x 5 digits over its fill n = 0..8:
    # char BAR_DIGC + (health - 1) * 9 + n
    font = {"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
            "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
            "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
            "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
            "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"]}
    red = BAR_COLOURS[2]
    for hp in range(1, 16):
        txt = str(hp)
        gx = 1 if len(txt) == 2 else 3          # two digits: x 1..3 and 5..7 (gap at 4); one: x 3..5
        for n in range(9):
            tile = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
            for x in range(8):
                tile.putpixel((x, 1), W + (255,))
                tile.putpixel((x, 7), W + (255,))
            for x in range(n):
                for y in range(2, 7):
                    tile.putpixel((x, y), red + (255,))
            for d, ch in enumerate(txt):
                for yy, row in enumerate(font[ch]):
                    for xx, bit in enumerate(row):
                        if bit == "1":
                            tile.putpixel((gx + d * 4 + xx - (1 if len(txt) == 2 else 0) * 0, 2 + yy), W + (255,))
            k = BAR_DIGC + (hp - 1) * 9 + n
            tile = tile.rotate(-90)
            vx, vy = 0x8F8 - (k >> 5) * 8, (k & 31) * 8
            for yy in range(8):
                for xx in range(8):
                    r, g, b_, al = tile.getpixel((xx, yy))
                    w = ((r >> 3) << 10) | ((g >> 3) << 5) | (b_ >> 3)
                    vram[(vx + xx, vy + yy)] = (w | 0x8000) if al else 0
    x0 = min(x for x, y in vram); x1 = max(x for x, y in vram)
    y0 = min(y for x, y in vram); y1 = max(y for x, y in vram)
    words = [0xC000, 0x0000, 0x2000, 0x0000, 0x9999, 0x9999, x0, y0, x1 - x0, y1 - y0]
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            words.append(vram.get((x, y), 0))
    words += [0x0000, 0x0000]
    if len(words) % 2:
        words.append(0)
    lines = ["        .align 2", "bar_list:"]
    for i in range(0, len(words), 8):
        lines.append("        .word " + ",".join(f"0x{w:04X}" for w in words[i:i + 8]))
    lines += ["        .align 2", ""]
    return "\n".join(lines)


def _warning(block):
    # the boot warning: 14 lines of 30 characters (each NUL-terminated) per
    # region block; the last line is the version/date
    lines = ["   PINK SWEETS ROSY ARRANGE   ",
             "         CAVE OWNS!!!         "] + [" " * 30] * 11 + \
            ["    2026/10/16 ROSY ARRANGE   "]
    assert all(len(x) == 30 for x in lines)
    return (block, b"".join(x.encode() + b"\0" for x in lines))


STANDALONE_PATCHES += [
    _warning(0x0C1066F4),               # Japan warning
    _warning(0x0C1068A6),               # overseas warning
    # the date is normally filled in from the build info: keep our text
    (0x0C0703D2, bytes.fromhex("0009")),
    (0x0C0703E2, bytes.fromhex("0009")),
    (0x0C0703F0, bytes.fromhex("0009")),
    # title footer "(c)2006 CAVE CO.,LTD." / "SALE BY AMI" -> "ROSY ARRANGE"
    (0x0C1063A8, b"   ROSY ARRANGE    "),
    (0x0C1063BC, b" " * 11),
    # no Start-button pause (the game allows it in free play): the per-frame
    # pause check 0x0C075970 always answers "not paused"
    (0x0C075970, bytes.fromhex("000be000")),
    # rose cracker meter fills from tick-points only (meter_tick):
    (0x0C07AAB8, bytes.fromhex("7500")),        # no +1 a frame once it has started
    (0x0C07AC80, bytes.fromhex("0009")),        # no "almost full" voice on every shot
    (0x0C07ACBE, bytes.fromhex("af05")),        # a shot doesn't empty the meter
    # tick-point (score += 10 at 0x0C076CC4) -> tick_hook, via dead padding at 0x0C076694
    (0x0C076CC4, bytes.fromhex("ace6750a")),    # bra 0x0C076694 / add #10,r5
    (0x0C076694, bytes.fromhex("da014a2b0009")),  # mov.l @(lit),r10 / jmp @r10 / nop
    (0x0C07669C, "tick_hook"),
    # bullet graze tick-point (score += 10 at 0x0C07701E) -> tick_hook2, via
    # dead padding at 0x0C076F68 (after an rts) and 0x0C07705C (after a bra)
    (0x0C07701E, bytes.fromhex("afa37b0a")),    # bra 0x0C076F68 / add #10,r11
    (0x0C076F68, bytes.fromhex("d63c462b0009")),  # mov.l @(0x0C07705C),r6 / jmp @r6 / nop
    (0x0C07705C, "tick_hook2"),
    # rank only rises on item pickups in a real game: rank-up routine -> arr_rankup
    (0x0C0781A0, bytes.fromhex("d001402b00090009")),
    (0x0C0781A8, "arr_rankup"),
    # character select: every select button gives TYPE A (D switches in play)
    (0x0C08C076, bytes.fromhex("e010")),
    # DIP menu: ranking save defaults to ON (default settings byte 0x7A -> 0xFA)
    (0x0C069C2A, bytes.fromhex("e3fa")),
    # DIP menu: hide difficulty1 / difficulty2 / extend / player counts (items 11-14).
    # rows of items 15..18 (ranking save .. exit) move up into the gap
    (0x0C105A9C + 15, bytes([18, 16, 14, 12])),
    # ... and the fixed labels "load default setting" / "save" / "exit" with them
    (0x0C105CE4 + 20, bytes([16])),
    (0x0C105CE4 + 28, bytes([14])),
    (0x0C105CE4 + 36, bytes([12])),
] + [
    # cursor: up from ranking save -> demo sound, down from demo sound -> ranking save
    p for t in range(9) for p in (
        (0x0C105AEC + 0x28 * t + 15, bytes([10])),
        (0x0C105B00 + 0x28 * t + 10, bytes([15])))
] + [
    # don't draw the hidden items
    (0x0C0673D0, bytes.fromhex("000b0009")),
    (0x0C067430, bytes.fromhex("000b0009")),
    (0x0C067560, bytes.fromhex("000b0009")),
    (0x0C067490, bytes.fromhex("000b0009")),
] + [p for p in PATCHES if p[0] not in (0x0C06E64A, 0x0C06E654, 0x0C06E658, 0x0C0754A0)]


# Combined build: Rosy Future keeps its menu stub and credit-message gate; the
# menu literal points at title_menu5 (which calls Rosy Future's menu first).
COMBO_PATCHES = [p for p in PATCHES if p[0] not in (0x0C06E64A, 0x0C06E658, 0x0C0754A0)] + [
    (0x0C076CC4, bytes.fromhex("ace6750a")),
    (0x0C076694, bytes.fromhex("da014a2b0009")),
    (0x0C07669C, "tick_hook"),
    (0x0C07701E, bytes.fromhex("afa37b0a")),
    (0x0C076F68, bytes.fromhex("d63c462b0009")),
    (0x0C07705C, "tick_hook2"),
    (0x0C0781A0, bytes.fromhex("d001402b00090009")),   # arr_rankup passes every call outside Rosy Arrange
    (0x0C0781A8, "arr_rankup"),
    # score extend (DIP) -> ext_hook: Rosy Arrange drops a lipstick instead of adding a life
    (0x0C07AF30, bytes.fromhex("a0070009")),            # bra 0x0C07AF42 / nop
    (0x0C07AF42, bytes.fromhex("d101412b0009")),        # mov.l @(0x0C07AF48),r1 / jmp @r1 / nop
    (0x0C07AF48, "ext_hook"),
    # sound driver channel start -> snd_hook (louder pickup sound for cracker flowers)
    (0x0C05FB24, "snd_hook"),
    # title: PRESS START one row lower (row 16), a blank row under the menu
    (0x0C06E84A, bytes.fromhex("e510")),
    # high-score table: 9 score digits (was 8), 11 px apart (was 12), right edge 4 px further right
    (0x0C0911B6, bytes.fromhex("e808")),
    (0x0C091118, bytes.fromhex("e30b")),
    (0x0C09112C, bytes.fromhex("7a74")),
]

def _warning_rf(block):
    # Pink Sweets Rosy Future boot warning (14 lines of 30 characters per
    # region block, each NUL-terminated; the last line is the version/date)
    import textwrap
    t = ("This project is unofficial and is not affiliated with, endorsed by, "
         "or authorized by CAVE. All rights to the original game and its "
         "associated intellectual property remain with their respective "
         "rights holders.")
    lines = [("  " + l).ljust(30) for l in textwrap.wrap(t, 26)] + [" " * 30, "HAVE FUN!!!".center(30)]
    lines += [" " * 30] * (13 - len(lines)) + ["2026/10/30 ROSY FUTURE".center(30)]
    assert len(lines) == 14 and all(len(x) == 30 for x in lines)
    return (block, b"".join(x.encode() + b"\0" for x in lines))


COMBO_PATCHES += [
    _warning_rf(0x0C1066F4),            # Japan warning
    _warning_rf(0x0C1068A6),            # overseas warning
    # title footer: "SALE BY AMI" -> "NOT FOR SALE" (the print's string literal)
    (0x0C06E77C, "nfs_str"),
]

# Combined build: changes that must only be in the program during a Rosy Arrange
# credit game; mode_apply swaps them in and out: (address, original, Rosy Arrange)
TOGGLES = [
    (0x0C075970, "2f862f96", "000be000"),   # no Start-button pause
    (0x0C07AAB8, "7501", "7500"),           # meter: no +1 a frame
    (0x0C07AC80, "892e", "0009"),           # no "almost full" voice on every shot
    (0x0C07ACBE, "afc2", "af05"),           # a shot doesn't empty the meter
    (0x0C08C076, "c9f0", "e010"),           # character select: TYPE A
]


def toggle_table_inc(standalone):
    lines = ["        .align 2", "toggle_table:"]
    for addr, orig, new in ([] if standalone else TOGGLES):
        o, n = bytes.fromhex(orig), bytes.fromhex(new)
        assert len(o) == len(n)
        lines += [f"        .long 0x{addr:08X}, {len(o)}",
                  "        .byte " + ",".join(f"0x{x:02X}" for x in o + n),
                  "        .align 2"]
    lines += ["        .long 0", ""]
    return "\n".join(lines)


def patch_table_inc(patches):
    lines = ["        .align 2", "patch_table:"]
    for addr, data in patches:
        dest = 0xAC000000 | (addr & 0x00FFFFFF)
        if isinstance(data, str):
            assert addr % 4 == 0
            lines += [f"        .long 0x{dest:08X}, 4", f"        .long {data}"]
        else:
            lines += [f"        .long 0x{dest:08X}, {len(data)}",
                      "        .byte " + ",".join(f"0x{x:02X}" for x in data),
                      "        .align 2"]
    lines += ["        .long 0", ""]
    return "\n".join(lines)


def assemble(standalone):
    tmp = tempfile.mkdtemp()
    with open(os.path.join(tmp, "patch_table.inc"), "w") as f:
        f.write(patch_table_inc(STANDALONE_PATCHES if standalone else COMBO_PATCHES))
    with open(os.path.join(tmp, "bar.inc"), "w") as f:
        f.write(bar_inc() if not standalone else "")
    with open(os.path.join(tmp, "toggle_table.inc"), "w") as f:
        f.write(toggle_table_inc(standalone))
    with open(os.path.join(tmp, "labels.inc"), "w") as f:
        f.write(labels_inc())
    obj = os.path.join(tmp, "arrange.o")
    out = os.path.join(tmp, "arrange.bin")
    elf = os.path.join(tmp, "arrange.elf")
    subprocess.run(["sh-elf-as", "-big", "-W", "-I", tmp, "-o", obj]
                   + (["--defsym", "STANDALONE=1"] if standalone else []) + [
                    os.path.join(HERE, "src", "arrange.s")], check=True)
    subprocess.run(["sh-elf-ld", "-EB", f"-Ttext=0x{RAM_BASE:08X}", "-e", "_start",
                    "-o", elf, obj], check=True)
    subprocess.run(["sh-elf-objcopy", "-O", "binary", "-j", ".text", elf, out], check=True)
    syms = {}
    nm = subprocess.run(["sh-elf-nm", elf], capture_output=True, text=True, check=True).stdout
    for line in nm.splitlines():
        p = line.split()
        if len(p) == 3:
            syms[p[2]] = int(p[0], 16)
    return open(out, "rb").read(), syms


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    raw = open(sys.argv[1], "rb").read()
    if len(raw) != 0x200000:
        sys.exit("u4 must be 2 MB")
    crc = zlib.crc32(raw)
    if crc not in (ORIGINAL_CRC, ROSY_FUTURE_CRC):
        sys.exit(f"u4 CRC32 is {crc:08x}; expected the original u4 ({ORIGINAL_CRC:08x}) "
                 f"or the Rosy Future u4 ({ROSY_FUTURE_CRC:08x})")
    standalone = crc == ORIGINAL_CRC
    rom = unswap(raw)

    lit = struct.unpack(">I", rom[BOOT_LIT:BOOT_LIT + 4])[0]
    if lit != DECOMP:
        sys.exit(f"unexpected boot literal 0x{lit:08X}: not a supported u4")

    if not standalone:
        hud = open(os.path.join(HERE, "data", "rosy_future_hud.bin"), "rb").read()
        if rom[HUD_OFF:HUD_OFF + len(hud)] != hud:
            sys.exit("Rosy Future HUD code at 0x100000 not found")

    code, syms = assemble(standalone)
    region = rom[CODE_OFF:CODE_OFF + len(code)]
    if set(region) != {0xFF} and region != code:
        sys.exit("0x101000 is not free; refusing to overwrite")
    rom[CODE_OFF:CODE_OFF + len(code)] = code
    if syms["boot_patch"] != RAM_BASE:
        sys.exit("boot_patch must be first")
    rom[BOOT_LIT:BOOT_LIT + 4] = struct.pack(">I", CODE_CPU)

    out = bytes(unswap(rom))
    open(sys.argv[2], "wb").write(out)
    print(f"output CRC32 {zlib.crc32(out):08x}" + ("  (standalone Rosy Arrange)" if standalone else ""))
    print(f"code 0x{CODE_OFF:X}-0x{CODE_OFF + len(code):X} ({len(code)} bytes)")
    for k in ("boot_patch", "title_menu5", "arr_input", "arr_frame"):
        print(f"  {k:12s} 0x{syms[k]:08X}")
    print("wrote", sys.argv[2])


if __name__ == "__main__":
    main()
