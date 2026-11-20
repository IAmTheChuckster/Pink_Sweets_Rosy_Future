# CLAUDE.md: Pink Sweets Rosy Future (full handoff)

This file is everything a new Claude session needs to rebuild this project from scratch or keep working on it, with nothing assumed from earlier sessions. Read it all before you touch code.

**Current state:** Build **35** · published patched u4 CRC32 **`d351bd1b`** (⚠ `arrange.s` source changed since; needs rebuild, see section 11) · Rosy Future base CRC `2b1d0fb1` · original u4 `5d812c9e` · last updated 2026-11-20.

## 0. Rules for keeping this file and the README current (MANDATORY, without being asked)
Every change you make in this repo must, **in the same commit**:
1. **Update CLAUDE.md**: the "Current state" line, the section the change touches (features, addresses, CRCs, file names, traps found, decisions), and the **Change log** at the bottom (one line: date, build number, what changed).
2. **Update README.md**: Patch Notes for anything players see, the CRC table, patcher usage and file names. Don't edit the user's "To Do" list unless they ask.
3. **Bump the build number** if the change is a new build (anything that changes `index.html`, `patch.py`, `arrange/` code or the patched u4): `Build <span id="build">N</span>` in the `index.html` header +1, and the same number in "Current state" above.
4. If you learn something non-obvious (a trap, an address, a user decision), add it here, even if no code changed.

The user shouldn't have to ask for any of this.

## 1. What the project is
A fan patch for **Pink Sweets: Ibara Sorekara (Japan, 2006/04/06 MASTER VER.)**, Cave CV1000-B, SH-3 CPU. Repo: https://github.com/IAmTheChuckster/Pink_Sweets_Rosy_Future (older names: Pink_Sweets_Forever; GitHub redirects). The web patcher runs on GitHub Pages: https://iamthechuckster.github.io/Pink_Sweets_Rosy_Future/
The user plans and tests everything; Claude does the reverse engineering and the patcher code. Tested on MAME 0.289 and the ikacore CV1k core for MiSTer (by Raki).

## 2. Inputs (never store, commit or share ROM data)
- `pinkswts.zip`: u4 is 2 MB, CRC32 `5d812c9e` (reject anything else). u2 `a2fa5363`, u23 `4b82d250`, u24 `e93f0627` stay unchanged.
- `ibara.zip` (MAME set `ibarao`): its u2 is 138412032 bytes, CRC32 `55840976`. The HADOUGUN sprites are copied from it **at patch time** (`IBARA_FILL` rows); nothing from Ibara is in the repo.
- The repo contains only our own code (as byte runs), tools, notes and verification CRCs. No xdelta, no ROM bytes.

## 3. House rules
- MAME **0.289** only. Patchers: a Python 3 stdlib-only script (`patch.py`) and a single-file web page (`index.html`).
- Work in small steps, say in plain words what you're doing, show results or screenshots, offer rollback, stop at once when the user interrupts.
- Never push a half-finished state: the build, both patchers, README, MRA and CRCs must all match the same u4.
- `git pull --rebase` before committing; push to `main` only when the user asks. Commit messages end with the attribution trailer from the session's system reminder.
- Roll back only your own uncommitted work, and save a `git diff` first.
- Naming: MRA `mister/Pink Sweets Rosy Future.mra` (spaces), setname `pinkswtsrf`, zip `pinkswtsrf.zip`, program file `pinkswtsrf_u4`, MRA title footer `2026/11/7 ROSY FUTURE`. The MRA lists the u4 twice (undecoded-A21 mirror) and the DDR3 roms (index 1, 2) before index 0.
- Audio: don't change sounds unless asked (the Ibara 5a sound replacement is on hold).

## 4. Repo layout
```
CLAUDE.md            this file
README.md            player-facing notes, patch notes, CRC table, credits
index.html           web patcher (GitHub Pages), shows "Build N" in the header. Box 1 = pinkswts.zip, box 2 = ibara.zip (or loose u2), 3 = check, 4 = download. Offers only pinkswtsrf.zip and the MRA (no separate u4 downloads, no feature list); needs the real pinkswts.zip (a loose u4 isn't accepted)
.claude/launch.json  "patcher": python http.server on 127.0.0.1:8765 for testing index.html in the browser pane
roms/                (ignored) the user's pinkswts.zip and ibara.zip live here on this PC
patch.py             Python patcher (renamed from pinkswts_patch.py at build 31)
.nojekyll  .gitignore (roms/, work/, *.zip, *_u4, __pycache__/, .images/: keep dumps and build output there, never committed)
mister/Pink Sweets Rosy Future.mra
arrange/README.md    ROSY'S ARRANGE source notes
arrange/build.py     assembles arrange.s and writes the combined u4
arrange/src/arrange.s   ~6000 lines of SH-3 asm
arrange/data/        hadougun.gif, popup_x.bin, rosy_future_hud.bin (our code at u4 0x100000, used to check the input)
arrange/tools/mame/  harness.lua, dip.lua, schedules/*.txt
```

## 5. What's in the patch (three layers)
SH-3 is big-endian in MAME memory and byte-swapped (16-bit) inside the u4 file.

**1. Rosy Future base (u4 `2b1d0fb1`).** Our code sits at u4 `0x100000`. The game program is LZ-compressed in u4 at `0x51000`; the patcher unpacks it, applies `PROGRAM` (address, new bytes, expected old bytes) and repacks (about a minute; `pack()` is DP LZ with window 2047, length 3..34). Features:
- ZAN counter (hidden 1UP counter: starts 2500, kills lower it, bomb kills raise it, READY at 0, back to 2500 after the extend item).
- Boss/midboss timer with one decimal, plus boss health (stages 1 to 7).
- RK rank meter in place of the 2P score (starts 18.75, 100.00 is hardest).
- Title menu after a coin: ARCADE / HARDER / EXTENDED / SCORE ATTACK / ROSY'S ARRANGE. The menu sits two rows higher, with a blank row before PRESS START. Harder, Extended and Score Attack are unlocked.
- 9-digit high scores; a warning screen (unofficial, not affiliated with CAVE, HAVE FUN!!!, date footer); the title footer says NOT FOR SALE.
- HUD per mode: ZAN under RK for Arcade/Harder/Extended, nothing extra for Score Attack. In 2-player games ZAN, the timer and the rank meter are removed and the 2P score comes back.
- Variables live at `0x0C7E0000..0x0C7E01FF` (zeroed at boot). The patch must stay <= `0x20000`. Symbol patches need a 4-aligned address.

**2. ROSY'S ARRANGE (`arrange/src/arrange.s`).** Linked at RAM `0x0C7C0000`, stored at u4 `0x101000` (CPU `0xA0101000`). The literal at u4 `0x18C` is redirected to `boot_patch`, which runs the game's unpacker (`DECOMP` = `0x0C002AC4`), patches the unpacked program in RAM and copies our code to RAM. The compressed program itself is never modified by this layer.
- Plays the Pink Sweets Rosy Arrange rules (1 player): TYPE, RANK, a rose cracker meter filled by tick points and shield cancels, weak/full cracker with a 2 s cooldown, flower chain, D or Start changes the shot type, its own How to Play page.
- Differences from the standalone Rosy Arrange: extends follow the DIP item (a lipstick 1UP drops from the top), each extend gives RANK +5, each death RANK -3, x32 multiplier, cracker flower pickup sound 50% louder.
- The boss timer sits top right under RANK, with a health bar (white outline; green, yellow from 30, red at 15 and below with a 15..1 countdown inside) that refills each phase.
- HADOUGUN: start with 1, +1 per death, max 4, icons lower right. A B tap (or letting go before it's ready) fires the cracker. Holding B for 1/4 s swings the options forward and grows aim lines; it's ready after 1 s. On release it flies up with sound 0x29, leaving a red trail for 15 s (1 damage per 12 frames, cancels bullets into medals) and white smoke. It passes through weak enemies (HP <= 10) and sticks to the first strong one (even one that can't be hit yet) as a red ball (1 damage per 12 frames, cancels bullets, up to 15 s). Up to 4 can be out at once. It's drawn after the scenery tile layers, with the ship drawn over it.
- Mode-only code is swapped in and out at run time (`TOGGLES`, `mode_apply`, `COMBO_PATCHES`), so the other four modes play exactly as before.

**3. DIP item "rosy's arrange extends" (item 19).** Same options as "extend" (0 NO EXTRA, 1..9 = 1000000p..9000000p each, 10..18 = "... only"). Default 1. Used only by ROSY'S ARRANGE. See section 7.

## 6. Key addresses (unpacked program at 0x0C000000)
Rank `0x0C453AB0` · real-play flag `0x0C4535F7` · enemy table `0x0C416968` (x192, stride `0xCC`, HP at +0x44) · P1 struct `0x0C49C5DC` · DIP "extend" `0x0C3B0A7C` · extend score `[0x0C5C009C]` and `[0x0C4AFAF0]` · game print `0x0C062980` · number print `0x0C075AF0`.

## 7. DIP menu internals
- Row table `0x0C105A9C + item`, labels `0x0C105CE4 + 8*n`, option counts `0x0C105AB0 + item` (extend = 18), cursor order `0x0C105AEC + 0x28*t` (up at +item, down at +20+item, t = 0..8), variable pointers `dip_varptr` `0x0C066778` (20 entries), player-counts line call `0x0C0667B0` (wrapped by `arr_dip_wrap`).
- The label goes on its own row with the value below it; the rows under it move down.
- The value is stored straight in the EEPROM buffer byte `0x0C3AE487`. The settings block (`0x0C3B0A8A`/`0x0C3B0A97`) does **not** persist. A value > 18 is read as 1.
- `arr_effext` reads it each title frame and writes the extend score (1000000 = `0x000F4240`).
- "load default setting" does not reset it (the user's decision). The game's default routine `0x0C069C20` is called from `0x0C066C36`, `0x0C0670A0` and `0x0C06A4EA` (power-on); an unconditional hook would wipe the saved value at boot.

## 8. Toolchain and build
- Needs `binutils` for sh-elf (`sh-elf-as`, `sh-elf-ld`). Disassemble with `sh-elf-objdump -D -b binary -m sh3 -EB --adjust-vma=ADDR`. Also Python 3 and Pillow for the graphics tools.
- Build: `IBARA_U2=<ibara u2 path> python3 arrange/build.py <rosy future u4 2b1d0fb1> <out_u4>`. **Without `IBARA_U2` the CRC won't match the patchers.** The build prints the CRC, code range, symbols and `IBARA_FILL` rows.
- Assembler traps: a `bsr` to a far routine overflows 12 bits (use `mov.l label,r0 / jsr @r0`). Keep literal pools per routine in pc-relative range. Never rename a shared label globally (use unique prefixes like `LZ_`, `LT_`). Watch for `MISALIGN` lines.

## 9. MAME testing (0.289, headless)
- `mame pinkswts -rompath <dir> -cfg_directory <fresh dir> -nvram_directory <dir> -video none -sound none -nothrottle -seconds_to_run N -autoboot_script script.lua`. Only one autoboot script is used, so concatenate Lua files if you need two. Always use a **fresh cfg dir**: a stale `pinkswts.cfg` boots into the test menu.
- `harness.lua` (env `PS_MODE`, `PS_STATE`, `PS_SCHED`, `PS_FRAMES`, `PS_OUT`, `PS_DUMP`, `PS_SNAP`, `PS_INVULN`). `dip.lua` (`SCHED=`, `SNAPS=`, `USEX=1`). Schedule lines are `<frame> <tokens>`: U D L R A B, S = Start, K = Coin, X = test switch. Hold a coin about 6 frames. `bootarr.txt` starts ROSY'S ARRANGE; `boot_m0..3` start the other modes (the only schedules kept; the ad-hoc ones were deleted at build 32).
- MAME isn't frame-deterministic (RTC), so compare trends. Unpack Lua dumps big-endian (`'>I'`).
- **On this PC:** WSL `Ubuntu-24.04` has `sh-elf-as` and MAME 0.289 in `~/mame` (`bin/cv1k`, `scripts/run.sh`, `boot_test.sh`; README in `D:\GitHub\mame0.289_dev_headless`). Make a set folder `~/mame/roms/pinkswts/` with pinkswts_u2, u23, u24 and the patched u4 renamed `pinkswts_u4`, then `GAME=pinkswts ROMPATH=~/mame/roms BT_SCHED=<sched> BT_SNAP=300 scripts/run.sh 4500`; snapshots go to `~/mame/work/snap/pinkswts/`. `bootarr.txt` plus `1900 A` reaches ROSY'S ARRANGE stage 1. Boot twice on a fresh work dir (EEPROM init).
- The `learn-cv1000-game` skill sets up the MAME 0.289 env from IAmTheChuckster/mame0.289_claude.
- Regression checklist: all 5 modes start, non-Arrange modes unchanged, ZAN/timer/health/RK show, HADOUGUN works, a fresh EEPROM gives item 19 = 1, a saved value survives a reboot, no crash over several minutes.

## 10. Regenerating the patchers (every time the u4 changes)
1. Build with `IBARA_U2` and note the CRC.
2. Diff the Rosy Future base against the new u4 outside the `IBARA_FILL` regions, merging runs with gaps of 8 bytes or less, into `[offset, base64]` lists: `EXTRA` in `patch.py`, and `extra` in `const PATCH = {program, hook, extra}` in `index.html`. `PROGRAM`, `HOOK_CODE` and `IBARA_FILL` don't change.
3. Replace the CRC everywhere: `PATCHED_CRC` and the error strings in both patchers, the embedded MRA string (both patchers), the README table, `arrange/README.md` and `mister/*.mra`.
4. Verify: `python3 patch.py pinkswts.zip ibara.zip -o out` must be byte-identical to the build. The web page must show "Matches Build N" and two downloads (pinkswtsrf.zip, MRA). Test: start the `patcher` launch config, fetch `/roms/*.zip` in the page and dispatch drop events on `#dropPink` / `#dropIbara`. The embedded MRA must equal `mister/`.
5. Bump the build number and update this file and the README (section 0).

## 11. Open items and decisions
- **Rebuild pending (build 32):** 13 unreferenced literal-pool entries were removed from `arrange/src/arrange.s` (L3_cfrm, L8_boss, LS_after, WG2_4000, WG2_1024, WG2_90, LG2_bx, LG2_crkflag, LG2_dmgfn, LG2_bul, LG2_puff, LG2_nohit, WP_f0). The source no longer builds `d351bd1b`; the patchers still output `d351bd1b` from the old embedded bytes. The next session with sh-elf binutils and the dumps must rebuild, regenerate both patchers (section 10), update the CRCs and retest in MAME. (This PC has no sh-elf toolchain or MAME on PATH.)
- **To Do (from the user):** finish fixing HADOUGUN (investigation paused, the user will resume); add skills.
- A rare crash about 40 s into stage 1 was seen once and never reproduced.
- Possible double music on MiSTer at stage 5 after weak crackers: suspected core timing, the user chose no change.
- The README's warning-screen line says `2026/10/30 ROSY FUTURE`, and `index.html` line ~123 still mentions `2026/10/15` and "CAVE OWNS!!!". These are stale texts to check against the actual ROM before the next release.
- The old `skills/pink-sweets-rosy-future-build/` directory was deleted by the user (commit dcf97e7); this file replaces it.

## 12. Change log
- 2026-10-24: ROSY'S ARRANGE entry added to the title menu; Pink Sweets Forever naming.
- 2026-10-29/30: Rosy Arrange rules, DIP extends, rank +5/-3; renamed to Rosy Future (`pinkswtsrf`); boss timer and health bar; HADOUGUN with Ibara graphics.
- 2026-10-31: HADOUGUN tuning (damage, stick rules, cancels into medals, draw order). u4 `6002c5e6`.
- 2026-11-07: MRA renamed `Pink Sweets Rosy Future.mra`; DIP item "rosy's arrange extends". u4 `d351bd1b`.
- 2026-11-20 · Build 31: build counter added to the `index.html` header; `pinkswts_patch.py` renamed to `patch.py`; CLAUDE.md written as the full handoff.
- 2026-11-20 · Build 32: removed unused code: 13 dead literal-pool words in arrange.s, 7 undocumented MAME schedules (cool, mag2, mbC, mbI, play, play90, sel_RR), unused `dlhint` id in index.html. Patchers unchanged; rebuild pending. .gitignore now also ignores roms/, work/, *.zip, *_u4 and .images/.
- 2026-11-20 · Build 33: web patcher split into separate pinkswts.zip (1) and ibara.zip (2) boxes; only pinkswtsrf.zip and the MRA are offered; stale feature list removed. Tested with the user's roms: d351bd1b, Matches, both downloads OK.
- 2026-11-20 · Build 34: web patcher status pill says "Matches Build N" (N read from the header's #build span).
- 2026-11-20: MAME 0.289 (WSL) test of d351bd1b: boots, warning screen, attract mode, ROSY'S ARRANGE character select and stage 1 all OK. The user reported a MiSTer no-boot; the user's pinkswts.zip is a merged set (clone subfolders), and the patchers copy those into pinkswtsrf.zip too.
- 2026-11-20 · Build 35: pinkswtsrf.zip (both patchers) now holds only pinkswts_u2, u23, u24 (picked by CRC, written under those names) and pinkswtsrf_u4, about 43 MB; clone folders from a merged input set are dropped. Tested: Python and web both produce the 4 files. MiSTer boot not retested yet.
- 2026-11-20: MiSTer no-boot investigation. In MAME 0.289, original pinkswts and patched d351bd1b boot the same way: identical EEPROM/NAND after two fresh boots, same log apart from timing jitter. The reset code differs only in the literal at 0x18C. The cache is still off when boot_patch runs (the reset code calls the unpacker before the game sets up the cache at 0x0C002A30), so uncached patch writes are safe. A static scan found no misaligned word/long accesses. For a bisect, the pre-DIP build (commit f23f0e3, u4 d48c4d23) was rebuilt into work/prev_dip/ for a MiSTer test. Suspects if d48c4d23 boots and d351bd1b doesn't: the DIP item code (EEPROM buffer byte 0x0C3AE487, dip_varptr, arr_dip_wrap).
- 2026-11-21: **The user confirmed Build 35 boots on MiSTer** and is the version to use (u4 d351bd1b; pinkswtsrf.zip with only the 4 files). The earlier no-boot was most likely the untrimmed zip, which carried clone folders from a merged pinkswts.zip. Keep pinkswtsrf.zip trimmed.
