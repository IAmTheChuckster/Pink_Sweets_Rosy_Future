! Pink Sweets: Rosy Arrange patch (SH-3, big-endian)
! Placed at u4 offset 0x101000 (CPU 0xA0101000), after the Rosy Future HUD code at 0x100000.
!
! Entry points
!   boot_patch   reset calls this instead of the LZ unpacker; it unpacks, then patches RAM
!   title_menu5  5-entry mode menu (ARCADE/HARDER/EXTENDED/SCORE ATTACK/ROSY ARRANGE)
!   arr_input    hooked into the port-read routine at 0x0C0610F8
!   arr_frame    per-frame gameplay hook (wraps the Rosy Future HUD routine)

        .ifdef  STANDALONE
        .set    ZANHUD,     0x0C078F80      ! standalone: the game's own per-frame routine
        .else
        .set    ZANHUD,     0xA0100000      ! Rosy Future per-frame HUD routine
        .endif
        .set    DECOMP,     0x0C002AC4      ! boot LZ unpacker (RAM copy)
        .set    INPUT_RET,  0x0C061104      ! resume point in port-read routine

        .set    P1,         0x0C49C5DC      ! player 1 struct
        .set    P2STAT,     0x0C49C894      ! player 2 status word
        .set    MODE_SEL,   0x0C4B01CA      ! game mode chosen on title (0..3)
        .set    MENU_PREV,  0x0C7E0000      ! Rosy Future: previous menu input
        .set    VAR_SEL,    0x0C7E0002      ! menu cursor 0..4
        .set    VAR_FLAG,   0x0C7E0003      ! 1 = Rosy Arrange selected
        .set    VAR_PREV,   0x0C7E0004      ! previous physical A/B/C
        .set    VAR_ACC,    0x0C7E0005      ! charge speed-up accumulator
        .set    ACC_ADD,    0               ! extra charge steps per ACC_DIV frames (0 = arcade 148 frames)
        .set    ACC_DIV,    90
        .set    VAR_LATCH,  0x0C7E0006      ! C hold-over counter
        .set    VAR_PEND,   0x0C7E0007      ! lipstick 1UPs waiting to drop
        .set    VAR_NEXT,   0x0C7E0008      ! next 10,000,000 score threshold (u32)
        .set    VAR_CRK,    0x0C7E000C      ! 1 while the rose cracker's damage call runs (arrange)
        .set    QCOUNT,     0x0C7E000D      ! queued cracker-hit items
        .set    VAR_SEED,   0x0C7E0110      ! random seed (u32)
        .set    QBUF,       0x0C7E0010      ! up to 32 x (Y, X)
        .set    VAR_CHAIN,  0x0C7E0114      ! (unused byte; VAR_CTIME etc. follow)
        .set    VAR_MULT,   0x0C7E0140      ! (u32) last flower multiplier, 0 = no chain
        .set    VAR_LSLOT,  0x0C7E0144      ! next label slot (0..7)
        .set    VAR_LPTR,   0x0C7E0148      ! (u32) end of the pending label blitter list, 0 = none
        .set    VAR_CSHOWN, 0x0C7E014C      ! (u32) chain count on screen (0 = blank)
        .set    CHAIN_ROW,  33              ! text row of the first chain line (top left, under the subtitle)
        .set    VAR_FIFO,   0x0C7E0150      ! last 10 chain pickups' points (u32 x 10, oldest first)
        .set    VAR_FCOUNT, 0x0C7E0178      ! how many of them are in use (0..10)
        .set    VAR_FDIRTY, 0x0C7E0179      ! 1 = redraw the list
        .set    LBL_RING,   0x0C7D0000      ! 8 x 32 bytes: frame record + sprite def per label slot
        .set    LBLBUF,     0xAC7E0600      ! label blitter list (uncached), up to 0x1000 bytes
        .set    VAR_CTIME,  0x0C7E0115      ! frames since the last cracker flower was collected (caps at 100)
        .set    VAR_CFRM,   0x0C7E0116      ! frames until the pop-up labels are redrawn in VRAM
        .set    VAR_CPEND,  0x0C7E0117      ! 1 = draw the labels at the next blitter kick
        .set    VAR_KPART,  0x0C7E011C      ! enemy part hit by the cracker in the current damage call (u32)
        .set    VAR_FCNT,   0x0C7E0120      ! flower counter (u32)
        .set    VAR_FSHOW,  0x0C7E0124      ! counter display: 0 off, 1 counting, 2 fading
        .set    VAR_FALPHA, 0x0C7E0125      ! fade level 255..0
        .set    VAR_NPEND,  0x0C7E0126      ! 1 = draw the counter digits into VRAM at the next blitter kick
        .set    BLITBUF2,   0xAC7E0600      ! counter blitter list (uncached)
        .set    VAR_FOBJ,   0x0C7E0128      ! counter pop-up object (u32 pointer, 0 = none)
        .set    VAR_PLIVES, 0x0C7E0130      ! P1 lives + 1 last frame (0 = not yet known)
        .set    VAR_PRANK,  0x0C7E0134      ! rank last frame (u32)
        .set    VAR_PSCORE, 0x0C7E0180      ! P1 score last seen by score_cap (u32)
        .set    VAR_PREVD,  0x0C7E0184      ! D (button 4) held last frame (0x80)
        .set    VAR_KILLS,  0x0C7E0188      ! (u32) enemies destroyed by the cracker in this chain
        .set    VAR_TICKS,  0x0C7E01B8      ! (u32) tick-points since the last frame
        .set    VAR_HIDE,   0x0C7E01BC      ! 1 = a full meter was shown as 127 to a shot this frame
        .set    VAR_START,  0x0C7E01BD      ! 1 = new game: fill the meter on the first live frame
        .set    VAR_WEAK,   0x0C7E01C0      ! frames left of a weak rose cracker (B below full)
        .set    VAR_WOLD,   0x0C7E01C1      ! meter before the weak cracker (put back if none fired)
        .set    VAR_WMASK,  0x0C7E01C2      ! (u16) cracker slots already seen
        .set    VAR_COOL,   0x0C7E01C4      ! rose cracker cooldown, frames left (B ignored)
        .set    COOLDOWN,   120             ! 2 seconds after the cracker has finished
        .set    VAR_AHOLD,  0x0C7E01C9      ! frames button A (button 1) has been held, max 127
        .set    MAGNET_AT,  120             ! A held this long (2 s): cracker flowers fly to the ship
        .set    MAGNET_STEP,0x000C0000      ! up to 12 px a frame on each axis (16.16)
        .set    VAR_FLWSND, 0x0C7E01CA      ! frames left to play the pickup sound louder (a cracker flower was collected)
        .set    FLW_PHRASE, 0x24            ! sound phrase of a score item pickup
        .set    VAR_BUP,    0x0C7E01CD      ! (combined) 1 = upload the boss health bar tiles at the next blitter kick
        .set    VAR_HPMAX,  0x0C7E01CE      ! (combined, word) boss health at the start of the fight/phase
        .set    VAR_HPOBJ,  0x0C7E01D0      ! (combined, u32) object VAR_HPMAX belongs to
        .set    BAR_CHR,    0x400           ! first text char of the bar tiles (build.py bar_inc)
        .set    BAR_DIGC,   0x460           ! red middle cells with the countdown 1..15 (build.py)
        .set    VAR_HADOU,  0x0C7E01CB      ! (combined) HADOUGUN stock 0..4
        .set    VAR_HLIVES, 0x0C7E01CC      ! (combined) P1 lives + 1 last frame (0 = not known yet)
        .set    HADOU_MAX,  4
        .set    HADOU_CHR,  0x500           ! first text char of the stock icon strips (build.py)
        .set    VAR_HGS,    0x0C7E01D4      ! HADOUGUN state: 0 idle, 1 charging, 2 ready, 3 options going back
        .set    VAR_HGT,    0x0C7E01D5      ! charge frames 0..HG_CHARGE
        .set    VAR_HGO,    0x0C7E01D6      ! (2 x word) the options' own angles, kept while idle
        .set    VAR_BT,     0x0C7E01DA      ! (word) frames since the shot was fired, 0 = none
        .set    VAR_BX,     0x0C7E01DC      ! (u32) shot start, up axis (16.16, draw coordinates)
        .set    VAR_BY,     0x0C7E01E0      ! (u32) shot column, across axis (16.16)
        .set    VAR_HX,     0x0C7E01E4      ! (u32) shot head, up axis (16.16)
        .set    VAR_HY,     0x0C7E01E8      ! (u32) shot head, across axis (16.16)
        .set    VAR_HOBJ,   0x0C7E01EC      ! (u32) enemy the head is stuck to, 0 = flying
        .set    VAR_HSTK,   0x0C7E01F0      ! (word) frames stuck
        .set    VAR_HNSEG,  0x0C7E01F2      ! (word) trail segments dropped
        .set    HG_SND,     0x29            ! launch sound (coin-in sound)
        .set    HG_CHARGE,  60              ! frames (1 s) to bring the options to the front
        .set    VAR_HFRM,   0x0C7E01F4      ! (u32) frame counter for the aim line dots
        .set    VAR_SHOTS,  0x0C7E0400      ! HADOUGUN shots: 4 x 32 bytes (BX, BY, HX, HY, HOBJ, HSTK.w, HNSEG.w, BT.w)
        .set    HG_NSHOT,   4
        .set    VAR_HFC,    0x0C7E0590      ! (u32) logic frame counter
        .set    VAR_HDRAWN, 0x0C7E0594      ! (u32) frame the effects were last drawn
        .set    VAR_HUI,    0x0C7E01F8      ! HADOUGUN graphics upload: next region (HG_NREG = done)
        .set    VAR_HUR,    0x0C7E01FA      ! (word) ... next row of it
        .set    VAR_BHOLD,  0x0C7E01F9      ! frames B has been held (with HADOUGUN stock)
        .set    HG_TAP,     15              ! a B tap (cracker) is shorter than this; longer charges
        .set    VAR_PUFF,   0x0C7E0480      ! launch cloud: 32 puffs x 8 bytes (right after VAR_SHOTS) (up, across words; age byte, 0 = free)
        .set    HG_NPUFF,   32
        .set    HG_PLIFE,   90              ! frames a puff lasts
        .set    HG_PSPAWN,  60              ! puffs are made for this many frames after the launch
        .set    HG_CHUNK,   8192            ! pixels per upload chunk (hg_ubuf)
        .set    HG_FLIP,    0x80000000      ! sprite flip for the aim lines (point them up)
        .set    VAR_MODEAPP,0x0C7E01C8      ! (combined build) 1 = the Rosy Arrange code changes are in the program
        .set    RF_MENU,    0xA0100498      ! Rosy Future's 5-entry title menu (sets VAR_SEL / VAR_FLAG / MODE_SEL)
        .set    VAR_CRKHOLD,0x0C7E01BE      ! frames left of "the rose cracker is busy": an empty
                                            ! meter waits (no shield spawn) while this is > 0
        .set    VAR_KFIFO,  0x0C7E0190      ! kill multiplier of each chain-list line (u32 x 10, = VAR_FIFO + 0x40)
        .set    VAR_BOBJ,   0x0C7E0138      ! (standalone) boss object found by boss_scan, 0 = none
        .set    VAR_BENT,   0x0C7E013C      ! (standalone) its boss table entry
        .set    VAR_BOSS,   0x0C7E012C      ! (u32) type + 1 of the boss or midboss with a timer that is alive, 0 = none
        .ifndef STANDALONE
        .set    BOSSTAB,    0xA010028C      ! Rosy Future boss timer table: 22-byte entries, 0xFFFF ends
        .endif
        .set    FCMARK,     0xCC            ! item +104 marks the counter pop-up
        .set    BLITBUF,    0xAC7E0200      ! blitter list buffer (uncached)
        .set    FLOWERMARK, 0xC9            ! item +104 marks a cracker flower
        .set    SCOREKIND,  0x0C5C0162      ! game's current score item kind
        .set    INPUT_HELD, 0x0C4538A8      ! P1 held inputs (menu)
        .set    REALPLAY,   0x0C4535F7      ! 1 in a credit game, 0 in attract/How to Play demos
        .set    HTPFLAG,    0x0C3B298C      ! 1 while the How to Play screen runs
        .set    VAR_HTPOK,  0x0C7E0119      ! 1 from the PRESS START screen until play starts
        .set    TEXT,       0x0C3AF5FC      ! text layer, 32 cols x 4 bytes per row
        .set    DIRTY,      0x0C453604      ! row dirty flags

        .section .text
        .global _start
_start:

!==================================================================
! boot_patch: runs from the ROM copy (u4 0x101000) before anything else.
! Copies the whole patch (linked for RAM at 0x0C7C0000, unused by the game)
! into RAM through the uncached alias, so it runs from cached work RAM
! instead of the slow uncached ROM; then runs the original unpacker (r4/r5
! already set by reset code) and copies patch_table entries into the
! unpacked program. Everything here is PC-relative, so it works from ROM.
!==================================================================
boot_patch:
        sts.l   pr,@-r15
        mova    L_decomp,r0         ! ROM address of _start: a PC-relative
        mov.l   L_anch,r1           ! anchor minus its offset from _start
        sub     r1,r0
        mov     r0,r1
        mov.l   L_ramdst,r2
        mov.l   L_nwords,r3
.Lcopy:
        mov.l   @r1+,r0
        mov.l   r0,@r2
        dt      r3
        bf/s    .Lcopy
        add     #4,r2
        mov.l   L_decomp,r0
        jsr     @r0
        nop
        mov.l   L_vars,r1           ! clear our variables (RAM is random at power-on)
        mov     #0,r0
        mov.w   W_nvars,r2
.Lvclr:
        mov.l   r0,@r1
        dt      r2
        bf/s    .Lvclr
        add     #4,r1
        mova    patch_table,r0
        mov     r0,r1
.Lpent:
        mov.l   @r1+,r2             ! destination (0xAC... uncached)
        tst     r2,r2
        bt      .Lpdone
        mov.l   @r1+,r3             ! byte count
.Lpbyte:
        mov.b   @r1+,r0
        mov.b   r0,@r2
        dt      r3
        bf/s    .Lpbyte
        add     #1,r2
        add     #3,r1               ! realign to 4
        mov     #-4,r0
        and     r0,r1
        bra     .Lpent
        nop
.Lpdone:
        .ifdef  STANDALONE
        mov.l   L_flag0,r1          ! standalone ROM: Rosy Arrange is the only mode
        mov     #1,r0
        mov.b   r0,@r1
        .endif
        lds.l   @r15+,pr
        rts
        nop
        .align 2
L_decomp:   .long DECOMP
L_ramdst:   .long 0xAC7C0000        ! uncached alias of the RAM copy at 0x0C7C0000
L_nwords:   .long (_end - _start + 3) / 4
L_anch:     .long L_decomp - _start
L_flag0:    .long VAR_FLAG
L_vars:     .long 0xAC7E0000
        .align 1
W_nvars:    .word 0x200 / 4
        .align 2

        .include "patch_table.inc"

!==================================================================
! title_menu5: called every frame on the PRESS START screen.
!==================================================================
title_menu5:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   L_sel,r8
        .ifndef STANDALONE
        mov.l   L_rfmenu,r0         ! Rosy Future's menu: cursor, mode, VAR_FLAG, text
        jsr     @r0
        nop
        mov.l   L_chain,r3
        bra     .Lresets
        nop
        .align 2
L_rfmenu:   .long RF_MENU
        .endif
        .ifdef  STANDALONE
        mov     #4,r9               ! standalone: always ROSY ARRANGE, no menu
        ! difficulty1/difficulty2/extend/player counts are hidden from the DIP menu:
        ! keep them at NORMAL / MIDIUM / NO EXTRA / 3 whatever the saved settings say
        mov     #3,r0
        mov.l   L_dif1,r1
        mov.b   r0,@r1
        mov.l   L_dif2,r1
        mov.b   r0,@r1
        mov     #2,r0
        mov.l   L_dpl,r1
        mov.b   r0,@r1              ! player counts: 3
        mov     #0,r0
        mov.l   L_dext,r1
        bra     .Lnodn
        mov.b   r0,@r1
        .align  2
L_dpl:  .long   0x0C3B298B
L_dif1: .long   0x0C3B0AF8
L_dif2: .long   0x0C3B62A4
L_dext: .long   0x0C3B0A7C
        .endif
        mov.b   @r8,r9
        extu.b  r9,r9
        mov     #4,r0
        cmp/hi  r0,r9
        bf      .Lmok
        mov     #0,r9
.Lmok:
        mov.l   L_inheld,r1
        mov.b   @r1,r2
        extu.b  r2,r2
        mov.l   L_mprev,r3
        mov.b   @r3,r4
        extu.b  r4,r4
        mov.b   r2,@r3
        not     r4,r4
        and     r4,r2               ! newly pressed
        mov     r2,r0
        tst     #1,r0               ! up
        bt      .Lnoup
        tst     r9,r9
        bf      .Lupdec
        mov     #5,r9
.Lupdec:
        add     #-1,r9
.Lnoup:
        mov     r2,r0
        tst     #2,r0               ! down
        bt      .Lnodn
        add     #1,r9
        mov     #5,r1
        cmp/eq  r1,r9
        bf      .Lnodn
        mov     #0,r9
.Lnodn:
        mov.b   r9,@r8
        mov     #0,r1               ! arrange flag
        mov     r9,r2               ! game mode
        mov     #4,r3
        cmp/eq  r3,r9
        bf      .Lnotarr
        mov     #1,r1
        mov     #0,r2               ! Rosy Arrange runs on Arcade rules
.Lnotarr:
        mov.l   L_modesel,r3
        mov.b   r2,@r3
        mov.l   L_flag,r3
        mov.b   r1,@r3
        mov.l   L_chain,r3          ! chain off; labels drawn on the first frame of play
.Lresets:
        mov     #0,r0
        mov.l   r0,@r3              ! VAR_CHAIN, VAR_CTIME, VAR_CFRM, VAR_CPEND
        mov.l   r0,@(44,r3)         ! VAR_MULT
        mov.l   r0,@(56,r3)         ! VAR_CSHOWN (0x14C)
        mov.l   L_pend,r1
        mov.b   r0,@r1              ! VAR_PEND: no lipsticks left from the last game
        .ifndef STANDALONE
        mov.l   L_bup,r1            ! boss health bar tiles uploaded again
        mov     #1,r0
        mov.b   r0,@r1
        mov     #0,r0
        mov.l   L_hpobj,r1
        mov.l   r0,@r1
        mov.l   L_hui,r1            ! HADOUGUN graphics uploaded again (hg_upchunk)
        mov.w   r0,@r1
        mov.w   r0,@(2,r1)
        mov.l   L_hadou,r1          ! HADOUGUN: a new game starts with 1, no shot
        mov.b   r0,@(1,r1)          ! VAR_HLIVES = 0
        mov     #1,r0
        mov.b   r0,@r1              ! VAR_HADOU = 1
        mov     #0,r0
        mov.l   L_hgs,r1
        mov.w   r0,@r1              ! VAR_HGS, VAR_HGT
        mov.l   L_shots,r1          ! no shots, no puffs
        mov     #HG_NSHOT * 8 + HG_NPUFF * 2,r2
.Lclr_shot:
        mov.l   r0,@r1
        dt      r2
        bf/s    .Lclr_shot
        add     #4,r1
        .endif
        mov.l   L_kills,r1
        mov.l   r0,@r1              ! VAR_KILLS
        mov.l   r0,@(48,r1)         ! VAR_TICKS (0x1B8)
        add     #52,r1
        mov.b   r0,@r1              ! VAR_HIDE (0x1BC)
        mov     #1,r0
        mov.b   r0,@(1,r1)          ! VAR_START (0x1BD): a game starting from here gets a full meter
        mov.l   r0,@(12,r3)         ! VAR_FCNT
        mov.l   r0,@(16,r3)         ! VAR_FSHOW, VAR_FALPHA, VAR_NPEND
        mov.l   r0,@(24,r3)         ! VAR_BOSS
        mov.l   r0,@(28,r3)         ! VAR_PLIVES
        mov     #1,r0
        mov.b   r0,@(5,r3)          ! VAR_HTPOK: the next How to Play follows Start
        mov.l   L_mapply,r0         ! Rosy Arrange's code changes in or out of the program
        jsr     @r0
        mov     #1,r4
        .ifndef STANDALONE
        bra     .Lmdone
        nop
        .endif
        ! draw the five lines, rows 23..19
        mov.l   L_menutxt,r5
        mova    menu_strs,r0
        mov     r0,r6
        mov     #0,r7
.Lrow:
        mov.l   L_blank,r0
        .ifdef  STANDALONE
        bra     .Lnocur             ! standalone: no cursor; only the ROSY ARRANGE line
        nop
        .endif
        cmp/eq  r7,r9
        bf      .Lnocur
        mov.l   L_cursor,r0
.Lnocur:
        mov.l   r0,@r5
        mov.l   L_blank,r0
        mov.l   r0,@(4,r5)
        mov     r5,r1
        add     #8,r1
        mov     #12,r3
.Lch:
        mov.b   @r6+,r0
        extu.b  r0,r0
        mov.l   L_white,r2
        or      r2,r0
        mov.l   r0,@r1
        dt      r3
        bf/s    .Lch
        add     #4,r1
        mov.w   W_rowsz,r0
        sub     r0,r5
        add     #1,r7
        mov     #5,r0
        cmp/eq  r0,r7
        bf      .Lrow
        mov.l   L_dirty19,r1
        mov     #1,r0
        mov.b   r0,@r1
        mov.b   r0,@(1,r1)
        mov.b   r0,@(2,r1)
        mov.b   r0,@(3,r1)
        mov.b   r0,@(4,r1)
.Lmdone:
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 1
W_rowsz:    .word 0x80
        .align 2
L_sel:      .long VAR_SEL
L_inheld:   .long INPUT_HELD
L_mprev:    .long MENU_PREV
L_modesel:  .long MODE_SEL
L_flag:     .long VAR_FLAG
L_menutxt:  .long TEXT + 23*0x80 + 8*4
L_blank:    .long 0xC0404020         ! menu text: same red as the copyright footer
L_cursor:   .long 0xC040403E
L_white:    .long 0xC0404000
L_chain:    .long VAR_CHAIN
L_kills:    .long VAR_KILLS
L_dirty19:  .long DIRTY + 19
L_mapply:   .long mode_apply
L_pend:     .long VAR_PEND
L_bup:      .long VAR_BUP
L_hpobj:    .long VAR_HPOBJ
L_hadou:    .long VAR_HADOU
L_hgs:      .long VAR_HGS
L_hui:      .long VAR_HUI
L_shots:    .long VAR_SHOTS
menu_strs:
        .ifdef  STANDALONE
        .ascii  "            "
        .ascii  "            "
        .ascii  "            "
        .ascii  "            "
        .ascii  "            "
        .else
        .ascii  "ARCADE      "
        .ascii  "HARDER      "
        .ascii  "EXTENDED    "
        .ascii  "SCORE ATTACK"
        .ascii  "ROSY ARRANGE"
        .endif
        .align 2

!==================================================================
! arr_input: replaces 0x0C0610F8..0x0C061103 of the port-read routine.
! On entry: r0 = PORT_D & 0x7F, r7 = 0x7F, r2 = START1 bit (0x10),
! r5 = 0x20 (START2 mask), r12 = ~PORT_C, r8 -> raw P1 byte.
! Free here: r0 r1 r2(after use) r3 r6 r11 r13. PR is live: no jsr.
!==================================================================
arr_input:
        shll2   r2                  ! --- replayed original code ---
        xor     r0,r7
        add     r2,r2
        or      r2,r7               ! r7 = P1 active-high (bit6 = C)
        and     r12,r5              ! r5 = START2 (before shift)
        mov.l   L2_flag,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lstore
        mov     #0,r5               ! Rosy Arrange is 1P only: no 2P start
        mov.l   L2_real,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lstore             ! demo: leave the recorded play alone
        mov.l   L2_p1,r13
        mov.w   @r13,r0
        tst     r0,r0
        bt      .Lstore             ! P1 not playing: leave inputs alone
        mov.l   L2_p2stat,r1
        mov.w   @r1,r0
        tst     r0,r0
        bf      .Lstore
        ! physical A/B/C and new presses
        mov     r7,r3
        mov     #0x70,r0
        and     r0,r3               ! r3 = phys A(10) B(20) C(40)
        mov.l   L2_prev,r1
        mov.b   @r1,r6
        extu.b  r6,r6
        mov.b   r3,@r1
        not     r6,r6
        and     r3,r6               ! r6 = new presses
        .ifndef STANDALONE
        ! HADOUGUN in stock: B fires the rose cracker when let go before the
        ! HADOUGUN is ready (holding it charges); let go when ready: HADOUGUN
        mov.l   L2_stock,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lbt_done           ! no stock: B fires on the press as always
        mov.l   L2_bhold,r1
        mov.b   @r1,r0
        extu.b  r0,r2               ! frames B has been held
        mov     r3,r0
        tst     #0x20,r0
        bt      .Lbt_up
        mov     #~0x20,r0           ! held: no cracker yet
        and     r0,r6
        mov     r2,r0
        cmp/eq  #-1,r0
        bt      .Lbt_done
        mov     #127,r0
        cmp/hs  r0,r2
        bt      .Lbt_done
        add     #1,r2
        bra     .Lbt_done
        mov.b   r2,@r1
.Lbt_up:
        tst     r2,r2
        bt      .Lbt_done
        mov     #0,r0
        mov.b   r0,@r1
        mov.l   L2_hgs,r1           ! let go with the HADOUGUN ready: it fires,
        mov.b   @r1,r0              ! no cracker
        cmp/eq  #2,r0
        bt      .Lbt_done
        mov     #0x20,r0            ! let go before that: the B press happens now
        or      r0,r6
.Lbt_done:
        .endif
        mov     r3,r0               ! A (button 1) hold time, with or without other buttons
        tst     #0x10,r0
        mov.l   L2_ahold,r1
        bt/s    .Lah_st
        mov     #0,r0
        mov.b   @r1,r0
        extu.b  r0,r0
        cmp/eq  #127,r0
        bt      .Lah_st
        add     #1,r0
.Lah_st:
        mov.b   r0,@r1
        ! D (button 4, bit 7 of port D, which the game drops for START) or
        ! START: each press switches the shot type A -> B -> C -> D -> A
        mov.l   r4,@-r15
        mov.l   L2_portd,r1
        mov.b   @r1,r0
        not     r0,r0
        and     #0x80,r0            ! r0 = D held
        mov     r0,r4               ! ... or START (bit 7 of the game's input)
        mov     r7,r0
        and     #0x80,r0
        or      r4,r0
        mov.l   L2_prevd,r1
        mov.b   @r1,r4
        mov.b   r0,@r1
        not     r4,r4
        and     r4,r0
        tst     r0,r0
        bt      .Lnod
        mov.w   @r13,r0             ! only while the ship is in play (not the
        mov.w   W_alive,r4          ! Start that confirms the character select)
        cmp/eq  r4,r0
        bf      .Lnod
        mov.b   @(11,r13),r0        ! P1 +0x0B = type (low byte of character x 4 + type)
        mov     r0,r4
        add     #1,r0
        and     #3,r0
        mov     r0,r1
        mov     r4,r0
        and     #0xFC,r0
        or      r1,r0
        mov.b   r0,@(11,r13)
        mov.l   @(8,r13),r0         ! and the type's own ship speed, as the game sets
        shll2   r0                  ! it at the start (+0x20/+0x24 from 0x0C1084FC)
        mov.l   L2_spd,r1
        mov.l   @(r0,r1),r0
        mov.l   r0,@(32,r13)
        mov.l   r0,@(36,r13)
.Lnod:
        mov.l   @r15+,r4
        mov     #-0x71,r0
        and     r0,r7               ! game never sees A/B/C directly
        ! C hold-over so tapping C can't beat the #10 rate
        mov.l   L2_latch,r1
        mov.b   @r1,r11
        extu.b  r11,r11
        mov     r3,r0
        tst     #0x40,r0
        bt      .Lnoc
        mov     #7,r11
        bra     .Llst
        nop
.Lnoc:
        tst     r11,r11
        bt      .Llst
        add     #-1,r11
.Llst:
        mov.b   r11,@r1
        mov     r3,r0
        and     #0x40,r0            ! only C fires (A alone just slows the ship)
        or      r11,r0
        tst     r0,r0
        movt    r11                 ! r11 = 1 when not firing
        ! rate and speed: A held -> slowest (and #30 when C fires too), otherwise #10 + speed 2
        mov     r3,r0
        tst     #0x10,r0
        bt      .LnoA
        mov     #2,r2
        mov     #0,r1
        bra     .Lrate
        nop
.LnoA:
        mov     #6,r2
        mov     #2,r1
.Lrate:
        mov.w   W_283,r0
        mov.b   r2,@(r0,r13)        ! +0x283 rate
        mov.w   W_288,r0
        mov.b   r1,@(r0,r13)        ! +0x288 speed step
        mov     #0,r1
        mov.w   W_28A,r0
        mov.b   r1,@(r0,r13)        ! +0x28A speed direction
        ! A+C = rapid shot + FORWARD (0), C = wide shot + WIDE (1); otherwise keep the last
        mov     r3,r0
        tst     #0x40,r0
        bt      .LstDone
        tst     #0x10,r0
        movt    r1                  ! A held -> 0, else 1
.LstSet:
        mov.w   W_27C,r0
        mov.b   r1,@(r0,r13)        ! +0x27C shot type
        mov.w   W_28B,r0
        mov.b   r1,@(r0,r13)        ! +0x28B formation: 0 FORWARD (A), 1 WIDE (C)
.LstDone:
        ! alive (status 0xCE00): keep full power and two rose hips
        mov.w   @r13,r0
        mov.w   W_alive,r1
        cmp/eq  r1,r0
        bf      .Lnogrant
        mov.w   W_27D,r0
        mov.b   @(r0,r13),r1
        mov     #3,r2
        cmp/ge  r2,r1
        bt      .Lpowok
        mov.b   r2,@(r0,r13)        ! power level 3
.Lpowok:
        mov.w   W_290,r0
        mov.b   @(r0,r13),r1
        mov     #2,r2
        cmp/ge  r2,r1
        bt      .Lnogrant
        mov.b   r2,@(r0,r13)        ! rose hip count 2
        mov.l   @(4,r13),r1
        mov.l   L2_hipflag,r2
        or      r2,r1
        mov.l   r1,@(4,r13)
        mov.l   L2_hips,r5          ! P1 rose hip slot 0
        mov     #0,r2
.Lhip:
        mov.l   @r5,r0
        tst     r0,r0
        bf      .Lhipnext           ! slot already in use
        mov.l   L2_hipinit,r0
        mov.l   r0,@r5
        mov.l   @(8,r13),r0
        shlr2   r0
        mov.l   r0,@(4,r5)
        mov     #0,r0
        mov.l   r0,@(8,r5)
        mov.l   r0,@(12,r5)
        mov.l   r0,@(28,r5)
        mov.l   r0,@(32,r5)
        mov.l   r0,@(44,r5)
        mov.l   @(24,r13),r0        ! player Y
        mov.l   r0,@(20,r5)
        mov.l   @(28,r13),r0        ! player X
        mov.l   r0,@(24,r5)
        mov.l   L2_white,r0
        mov.l   r0,@(36,r5)
        mov     r5,r1
        add     #40,r1
        mov     #0,r0
        mov.w   r0,@r1
        mov.w   r0,@(2,r1)
        add     #14,r1              ! +54
        mov.b   r0,@r1
        mov.b   r0,@(2,r1)          ! +56
        mov     r2,r0
        mov.b   r0,@(3,r1)          ! +57 slot number
.Lhipnext:
        add     #60,r5
        add     #1,r2
        mov     #2,r0
        cmp/eq  r0,r2
        bf      .Lhip
.Lnogrant:
        mov     #0,r5               ! keep 2P start blocked
        ! shield / rose cracker
        mov.w   W_286,r1
        add     r13,r1              ! r1 -> +0x286 charge, +0x287 delay
        mov.b   @r1,r2
        extu.b  r2,r2
        mov.l   L2_cool,r3          ! cooldown: B is ignored
        mov.b   @r3,r0
        tst     r0,r0
        bt      .Lnocool
        mov     #~0x20,r0
        and     r0,r6
.Lnocool:
        mov     r6,r0               ! B below full: a weak rose cracker. The meter
        tst     #0x20,r0            ! is shown as full so the game fires it, and
        bt      .Lnoweak            ! meter_tick shortens it (or puts the meter back)
        mov.w   W_80,r0
        cmp/eq  r0,r2
        bt      .Lnoweak
        mov     #2,r0               ! below 2: B does nothing
        cmp/hs  r0,r2
        bf      .Lnoweak
        mov.l   L2_weak,r3
        mov     r2,r0
        mov.b   r0,@(1,r3)          ! VAR_WOLD
        sts.l   pr,@-r15
        mov.l   r1,@-r15
        mov.l   r2,@-r15
        mov.l   L2_cmask,r0
        jsr     @r0
        nop
        mov.l   @r15+,r2
        mov.l   @r15+,r1
        lds.l   @r15+,pr
        mov.l   L2_weak,r3
        mov.w   r0,@(2,r3)          ! VAR_WMASK
        mov     #12,r0
        mov.b   r0,@r3              ! VAR_WEAK
        mov.w   W_80,r2
        mov.b   r2,@r1
.Lnoweak:
        tst     r11,r11
        bt      .Lfiring
        mov.w   W_80,r0
        cmp/eq  r0,r2
        bf      .Laccel
        mov     r6,r0               ! full: B press fires the cracker
        tst     #0x20,r0
        bt      .Lstore
        mov     #0x10,r0
        or      r0,r7               ! one-frame A press
        bra     .Lstore
        nop
.Laccel:                            ! extra steps on ACC_ADD of every ACC_DIV frames (ACC_ADD 70: 148 -> 90 frames)
        mov.l   L2_acc,r3
        mov.b   @r3,r0
        extu.b  r0,r0
        add     #ACC_ADD,r0
        mov     #ACC_DIV,r3
        cmp/hs  r3,r0
        bf/s    .Lacc_no
        nop
        sub     r3,r0
        mov.l   L2_acc,r3
        bra     .Lacc_go
        mov.b   r0,@r3
.Lacc_no:
        mov.l   L2_acc,r3
        bra     .Lstore
        mov.b   r0,@r3
.Lacc_go:
        mov.b   @(1,r1),r0
        extu.b  r0,r0
        cmp/eq  #20,r0
        bt      .Lacc286
        tst     r0,r0
        bt      .Lstore
        add     #1,r0
        mov.b   r0,@(1,r1)
        bra     .Lstore
        nop
.Lacc286:
        tst     r2,r2
        bt      .Lstore
        mov     #127,r0             ! leave the last step to the game (it plays the "full" sound)
        cmp/hs  r0,r2
        bt      .Lstore
        add     #1,r2
        mov.b   r2,@r1
        bra     .Lstore
        nop
.Lfiring:
        mov     #0x10,r0
        or      r0,r7               ! A or C -> game's shot button
        mov.l   L2_acc,r3           ! charge timing starts the same way every time
        mov     #0,r0
        mov.b   r0,@r3
        mov.w   W_80,r0
        cmp/eq  r0,r2
        bf      .Lstore
        mov     r6,r0               ! full meter while shooting: B fires the cracker,
        tst     #0x20,r0            ! otherwise the shot sees 127 this frame (no
        bf      .Lstore             ! cracker) and meter_tick puts 128 back
        mov     #127,r0
        mov.b   r0,@r1
        mov.l   L2_hide,r3
        mov     #1,r0
        mov.b   r0,@r3
.Lstore:
        mov.b   r7,@r8              ! --- replayed original store ---
        mov.l   L2_ret,r1
        jmp     @r1
        nop
        .align 1
W_283:      .word 0x283
W_286:      .word 0x286
W_288:      .word 0x288
W_28A:      .word 0x28A
W_28B:      .word 0x28B
W_80:       .word 0x80
W_27C:      .word 0x27C
W_27D:      .word 0x27D
W_290:      .word 0x290
W_alive:    .word 0xCE00
        .align 2
L2_hipflag: .long 0x08000000
L2_hips:    .long 0x0C453630
L2_hipinit: .long 0xC4000004
L2_white:   .long 0x00808080
L2_flag:    .long VAR_FLAG
L2_p1:      .long P1
L2_p2stat:  .long P2STAT
L2_prev:    .long VAR_PREV
        .ifndef STANDALONE
L2_stock:   .long VAR_HADOU
L2_bhold:   .long VAR_BHOLD
L2_hgs:     .long VAR_HGS
        .endif
L2_latch:   .long VAR_LATCH
L2_acc:     .long VAR_ACC
L2_ret:     .long INPUT_RET
L2_real:    .long REALPLAY
L2_portd:   .long 0xA4000126
L2_prevd:   .long VAR_PREVD
L2_hide:    .long VAR_HIDE
L2_weak:    .long VAR_WEAK
L2_ahold:   .long VAR_AHOLD
L2_cool:    .long VAR_COOL
L2_cmask:   .long crk_mask
L2_spd:     .long 0x0C1084FC

!==================================================================
! arr_frame: per-frame gameplay hook. Runs the Rosy Future HUD routine, then
! in Rosy Arrange hides "#N" and the speed meter and shows the mode.
!==================================================================
arr_frame:
        sts.l   pr,@-r15
        mov.l   L3_zanhud,r1
        jsr     @r1
        nop
        mov.l   r0,@-r15
        mov.l   L3_mapply,r0        ! Rosy Arrange's code changes in or out (demos, other modes)
        jsr     @r0
        mov     #0,r4
        bsr     arr_icons           ! life icons one row lower in Rosy Arrange
        nop
        mov.l   L3_real,r1          ! in real play the How to Play is over
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lf_nok
        mov.l   L3_htpok,r1
        mov     #0,r0
        mov.b   r0,@r1
.Lf_nok:
        mov.l   L3_flag,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lfdone
        mov.l   L3_real,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lfdone
        mov.l   L3_ctime,r1         ! chain timer
        mov.b   @r1,r0
        extu.b  r0,r0
        mov     #100,r2
        cmp/hs  r2,r0
        bt      .Lct_cap
        add     #1,r0
        mov.b   r0,@r1
.Lct_cap:
        bsr     arr_death           ! death/respawn sequence twice as fast
        nop
        mov.l   L3_bscan,r0         ! boss or midboss alive? (the cracker leaves them alone)
        jsr     @r0
        nop
        mov.l   L3_p1,r1
        mov.w   @r1,r0
        tst     r0,r0
        bt      .Lfdone
        mov.l   L3_chtxt,r0         ! chain count on the text layer (no sprites/blitter)
        jsr     @r0
        nop
        mov.l   L3_row2,r1          ! row 2, cols 4..12
        mov     #0,r0
        mov     #9,r2
.Lblank:
        mov.l   r0,@r1
        dt      r2
        bf/s    .Lblank
        add     #4,r1
        mov.l   L3_row2,r1          ! "TYPE A".."TYPE D" from P1 +0x0B (0..3)
        mova    type_str,r0
        mov     r0,r3
        mov     #5,r2
        mov.l   L3_tattr,r4
.Ltyp:
        mov.b   @r3+,r0
        extu.b  r0,r0
        or      r4,r0
        mov.l   r0,@r1
        dt      r2
        bf/s    .Ltyp
        add     #4,r1
        mov.l   L3_p1,r3
        mov.b   @(11,r3),r0
        and     #3,r0
        add     #0x41,r0            ! 'A' + type
        or      r4,r0
        mov.l   r0,@r1
        mov.l   L3_dirty2,r1
        mov     #1,r0
        mov.b   r0,@r1
        bsr     rank_lbl            ! "RK" -> "RANK"
        nop
        ! ZAN off: hold both kill counters at 0 and hide the ZAN text
        mov     #0,r0
        mov.l   L3_kills,r1
        mov.w   r0,@r1
        mov.l   L3_bkills,r1
        mov.w   r0,@r1
        mov.l   L3_zantxt,r1        ! row 38, cols 19..29
        mov     #11,r2
.Lzb:
        mov.l   r0,@r1
        dt      r2
        bf/s    .Lzb
        add     #4,r1
        mov.l   L3_bhud,r0          ! boss timer and HP (standalone: Rosy Future's HUD isn't
        jsr     @r0                 ! here; combined: timer under RANK, health bar), after
        nop                         ! the ZAN text is cleared (same row)
        mov.l   L3_meter,r0         ! tick-points fill the rose cracker meter
        jsr     @r0
        nop
        mov.l   L3_magnet,r0        ! louder-pickup countdown (the A-hold flower pull is off)
        jsr     @r0
        nop
        mov.l   L3_scap,r0          ! score stops at 4,294,967,295
        jsr     @r0
        nop
        bsr     arr_oneup           ! lipstick 1UP every 10,000,000 points
        nop
        .ifdef  STANDALONE
        mov.l   L3_xrank,r0         ! an extra life raises RANK by 3 points
        jsr     @r0
        nop
        .endif
        bsr     arr_qspawn          ! 1,000-point items from rose cracker hits
        nop
        mov.l   L3_pops,r0          ! cracker-flower pop-ups: roll, then fade
        jsr     @r0
        nop
.Lfdone:
        mov.l   @r15+,r0
        lds.l   @r15+,pr
        rts
        nop
        .align 2
L3_zanhud:  .long ZANHUD
L3_flag:    .long VAR_FLAG
L3_mapply:  .long mode_apply
L3_p1:      .long P1
L3_row2:    .long TEXT + 2*0x80 + 4*4
L3_dirty2:  .long DIRTY + 2
L3_real:    .long REALPLAY
L3_kills:   .long 0x0C4A3AB6
L3_bkills:  .long 0x0C3AE102
L3_zantxt:  .long TEXT + 38*0x80 + 19*4
L3_tattr:   .long 0x80808000
L3_ctime:   .long VAR_CTIME
L3_cfrm:    .long VAR_CFRM
L3_pops:    .long arr_pops
L3_bscan:   .long boss_scan
L3_chtxt:   .long chain_txt
L3_bhud:    .long boss_hud
L3_xrank:   .long ext_rank
L3_scap:    .long score_cap
L3_meter:   .long meter_tick
L3_magnet:  .long magnet
L3_htpok:   .long VAR_HTPOK
type_str:   .ascii "TYPE "
        .align 2

!------------------------------------------------------------------
! arr_death: P1 +0x28E counts 0..180 while dying (status 0xE000) and
! +0x28F counts 0..60 while respawning (0xA000). Adding one extra step a
! frame (never past 179 / 59, so the game's own +1 still lands exactly on
! its end value) halves the whole sequence. Uses r0-r2.
!------------------------------------------------------------------
arr_death:
        mov.l   LD_p1,r1
        mov.w   @r1,r0
        mov.w   LD_dying,r2
        cmp/eq  r2,r0
        bf      .Ldt_resp
        mov.w   LD_o28e,r0
        mov     #179-256,r2
        bra     .Ldt_step
        extu.b  r2,r2
.Ldt_resp:
        mov.w   LD_resp,r2
        cmp/eq  r2,r0
        bf      .Ldt_out
        mov.w   LD_o28f,r0
        mov     #59,r2
.Ldt_step:
        add     r0,r1               ! r1 -> counter
        mov.b   @r1,r0
        extu.b  r0,r0
        cmp/hs  r2,r0
        bt      .Ldt_out
        add     #1,r0
        mov.b   r0,@r1
.Ldt_out:
        rts
        nop
        .align 1
LD_dying:   .word 0xE000
LD_resp:    .word 0xA000
LD_o28e:    .word 0x28E
LD_o28f:    .word 0x28F
        .align 2
LD_p1:      .long P1

!==================================================================
! arr_oneup: called every frame in Rosy Arrange play. Each time the
! score (P1+0x298) reaches the next multiple of 10,000,000 a lipstick 1UP
! (item type 3) is queued, and dropped from the top of the screen
! above the ship once the ship is alive. A new game resets the count.
!==================================================================
arr_oneup:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   L6_p1,r8
        .ifndef STANDALONE
        bra     .Lo_try             ! Pink Sweets Forever: the game's own (DIP) extends
        nop                         ! queue the lipsticks (ext_hook)
        .endif
        mov.w   W6_298,r0
        mov.l   @(r0,r8),r2         ! score
        mov.l   L6_next,r3
        mov.l   @r3,r1              ! next threshold
        mov.l   L6_step,r4
        mov     r1,r5
        sub     r4,r5
        cmp/hs  r5,r2               ! score >= next - 50000000 ?
        bt      .Lo_ok
        mov     r4,r1               ! new game: next = 50000000, nothing queued
        mov.l   r1,@r3
        mov.l   L6_pend,r5
        mov     #0,r0
        mov.b   r0,@r5
.Lo_ok:
        mov     r1,r0
        cmp/eq  #-1,r0              ! past the last step below the score cap: no more
        bt      .Lo_try
        cmp/hs  r1,r2               ! score >= next ?
        bf      .Lo_try
        clrt
        addc    r4,r1
        bf      .Lo_nx
        mov     #-1,r1              ! next would pass 4,294,967,295
.Lo_nx:
        mov.l   r1,@r3
        mov.l   L6_pend,r5
        mov.b   @r5,r0
        add     #1,r0
        mov.b   r0,@r5
.Lo_try:
        mov.l   L6_pend,r5
        mov.b   @r5,r0
        tst     r0,r0
        bt      .Lo_out
        mov.w   @r8,r0              ! ship alive?
        mov.w   W6_alive,r1
        cmp/eq  r1,r0
        bf      .Lo_out
        mov.l   L6_alloc,r0         ! grab one sky item slot
        jsr     @r0
        mov     #1,r4
        tst     r0,r0
        bt      .Lo_out
        mov.l   L6_pend,r5
        mov.b   @r5,r0
        add     #-1,r0
        mov.b   r0,@r5
        mov.l   L6_slots,r1
        mov.w   @r1,r10             ! slot index
        mov     #108,r0
        mul.l   r0,r10
        sts     macl,r9
        mov.l   L6_items,r0
        add     r0,r9               ! r9 -> item object
        mov.l   L6_flags,r0
        mov.l   r0,@r9
        mov     r10,r4
        mov     #3,r5               ! type 3: lipstick 1UP
        mov     #0,r6
        mov.l   L6_top,r7
        mov.l   L6_drop,r0
        jsr     @r0
        nop
        mov.l   L6_top,r0
        mov.l   r0,@(44,r9)         ! Y: top edge of the screen
        mov.l   @(28,r8),r0
        mov.l   r0,@(48,r9)         ! X: above the ship
        mov     #0,r0
        mov.l   r0,@(52,r9)
        mov.l   r0,@(56,r9)
        mov     r9,r1
        add     #84,r1
        mov.b   r0,@r1
        mov.l   L6_rank,r1          ! fall speed by rank, as the game does
        mov.l   @r1,r2
        mov.l   L6_one,r1
        sub     r2,r1
        shlr8   r1
        shlr2   r1
        shlr2   r1
        mov.l   L6_neg1,r2
        sub     r1,r2
        mov     r9,r1
        add     #68,r1
        mov.l   r2,@r1
        mov     #0,r0
        add     #22,r1              ! +90
        mov.w   r0,@r1
        mov     #-4,r2              ! +92 wave step: -4 right of centre, +4 left
        mov.l   @(48,r9),r3
        mov.l   L6_mid,r0
        cmp/gt  r0,r3
        bt      .Lo_wd
        mov     #4,r2
.Lo_wd:
        mov     r2,r0
        mov.w   r0,@(2,r1)
        mov     #0,r0
        add     #16,r1              ! +106
        mov.b   r0,@r1
.Lo_out:
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 1
W6_298:     .word 0x298
W6_alive:   .word 0xCE00
        .align 2
L6_p1:      .long P1
L6_next:    .long VAR_NEXT
L6_step:    .long   10000000
L6_pend:    .long VAR_PEND
L6_alloc:   .long 0x0C083620
L6_slots:   .long 0x0C42389E
L6_items:   .long 0x0C5B68EC
L6_flags:   .long 0xC0800004
L6_top:     .long 328 << 16
L6_drop:    .long 0x0C082AB0
L6_rank:    .long 0x0C453AB0
L6_one:     .long 0x01000000
L6_neg1:    .long 0xFFFF0000
L6_mid:     .long 512 << 16

!==================================================================
! arr_life: replaces 0x0C084716..0x0C084723 in the 1UP pickup. The game
! adds a life while lives <= 5 (6 icons max); Rosy Arrange stops at 5.
! Returns to 0x0C084724 with r2 = 0x2B8, r3 = cap, r8 = player, r0 = 0x27B.
!==================================================================
arr_life:
        mov.w   W7_2b8,r2
        mov     #5,r3
        mov.l   L7_flag,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Ll_cap
        mov.l   L7_real,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Ll_cap
        mov     #4,r3
        .ifndef STANDALONE
        mov.l   L7_rank,r1          ! Pink Sweets Forever: every lipstick (also at 5 lives)
        mov.l   @r1,r0              ! = RANK +5: the game's +3.125 already happened,
        mov.l   L7_more,r8          ! add the other 1.875 (not past the hardest)
        cmp/hi  r8,r0
        bt/s    .Ll_rk
        sub     r8,r0
        mov     #0,r0
.Ll_rk:
        mov.l   r0,@r1
        .endif
.Ll_cap:
        mul.l   r2,r9
        mov.l   L7_p1,r0
        sts     macl,r8
        add     r0,r8
        mov.w   W7_27b,r0
        mov.l   L7_ret,r1
        jmp     @r1
        nop
        .align 1
W7_2b8:     .word 0x2B8
W7_27b:     .word 0x27B
        .align 2
L7_flag:    .long VAR_FLAG
L7_real:    .long REALPLAY
L7_p1:      .long P1
L7_ret:     .long 0x0C084724
L7_rank:    .long 0x0C453AB0
L7_more:    .long 314573                ! 0.01875 x 2^24

!==================================================================
! Rose cracker hits -> 1,000-point items (score item kind 9)
!------------------------------------------------------------------
! arr_crkdmg: the cracker-vs-enemy loop calls the damage routine through
! the literal at 0x0C0767C8, which now points here. Sets VAR_CRK (only in
! Rosy Arrange play) around the real call so arr_hit knows it's the cracker;
! if a cracker hit landed (VAR_KPART) and destroyed the part (return >= 0),
! one flower is queued at the part.
!==================================================================
arr_crkdmg:                         ! (the boss/midboss no-damage rule is gone: the
                                    !  cracker damages everything again)
.Lc_dmg:
        sts.l   pr,@-r15
        mov.l   L8_flag,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lc_set
        mov.l   L8_real,r1
        mov.b   @r1,r0
.Lc_set:
        mov.l   L8_crk,r1
        mov.b   r0,@r1
        mov.l   L8_kpart,r1         ! no hit landed yet
        mov     #0,r2
        mov.l   r2,@r1
        mov.l   L8_dmg,r0
        jsr     @r0
        nop
        mov.l   L8_crk,r1
        mov     #0,r2
        mov.b   r2,@r1
        cmp/pz  r0                  ! >= 0: the part was destroyed
        bf      .Lc_out
        mov.l   L8_kpart,r1         ! by a cracker hit (Rosy Arrange play)
        mov.l   @r1,r1
        tst     r1,r1
        bt      .Lc_out
        mov.l   r0,@-r15
        mov.l   r6,@-r15
        mov.l   r7,@-r15
        mov.l   L8_kills,r6         ! one more enemy destroyed by the cracker:
        mov.l   @r6,r0              ! the chain's kill multiplier
        cmp/eq  #32,r0              ! max x32
        bt      .Lc_kmax
        add     #1,r0
        mov.l   r0,@r6
.Lc_kmax:
        mov.l   r1,@-r15
        bsr     tick_crk            ! a tick-point for the kill
        nop
        mov.l   @r15+,r1
        mov.l   @(44,r1),r6         ! part Y
        mov.l   @(48,r1),r7         ! part X
        bsr     q_push
        nop
        mov.l   @r15+,r7
        mov.l   @r15+,r6
        mov.l   @r15+,r0
.Lc_out:
        lds.l   @r15+,pr
        rts
        nop

!------------------------------------------------------------------
! arr_hit: replaces 0x0C085038..0x0C085043 in the damage routine, the
! point a hit actually lands (past the part's hit cooldown). Replays the
! original code, then records the part in VAR_KPART if the cracker hit it.
! Returns to 0x0C085044 with r2 = r5 = part. PR is saved by the routine.
!------------------------------------------------------------------
arr_hit:
        mov.w   W8_cc,r5            ! --- replayed original code ---
        mul.l   r5,r8
        mov.l   L8_parts,r11
        sts     macl,r5
        add     r11,r5
        mov     r5,r2
        mov.l   L8_crk,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lh_out
        mov.l   L8_kpart,r1         ! remember the part; arr_crkdmg queues a
        mov.l   r5,@r1              ! flower only if this hit destroys it
.Lh_out:
        mov.l   L8_hret,r0
        jmp     @r0
        nop

!------------------------------------------------------------------
! arr_bullet: the cracker/shield-vs-bullet loop cancels a bullet through the
! literal at 0x0C076ACC, which now points here (r4 = bullet, r7 = the
! cancelling entry; flag 0x08000000 = rose cracker, not shield). Queues the
! bullet's position in Rosy Arrange play, then tail-calls the real cancel.
!------------------------------------------------------------------
arr_bullet:
        mov.l   L8_flag,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lb_go
        mov.l   L8_real,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lb_go
        mov.l   @r7,r0              ! r7 = cancelling entry
        mov.l   L8_crkbit,r1
        tst     r1,r0
        bf      .Lb_crk
        mov.l   L8_ticks,r1         ! the shield cancelled it: one tick-point
        mov.l   @r1,r0
        add     #1,r0
        bra     .Lb_go
        mov.l   r0,@r1
.Lb_crk:
        sts.l   pr,@-r15            ! the rose cracker cancelled it: a tick-point,
        bsr     tick_crk            ! and a flower
        nop
        lds.l   @r15+,pr
        mov.l   r6,@-r15
        mov.l   r7,@-r15
        sts.l   pr,@-r15
        mov.l   @(48,r4),r6         ! bullet Y
        mov.l   @(52,r4),r7         ! bullet X
        bsr     q_push
        nop
        lds.l   @r15+,pr
        mov.l   @r15+,r7
        mov.l   @r15+,r6
.Lb_go:
        mov.l   L8_cancel,r0
        jmp     @r0
        nop

!------------------------------------------------------------------
! tick_crk: one tick-point from the rose cracker (a bullet cancelled or an
! enemy destroyed), and hold an empty meter for 30 frames so meter_tick
! doesn't spawn the shield while the cracker is still out. Uses r0 r1.
!------------------------------------------------------------------
tick_crk:
        mov.l   L8_ticks,r1
        mov.l   @r1,r0
        add     #1,r0
        mov.l   r0,@r1
        mov.l   L8_hold,r1
        mov     #30,r0
        rts
        mov.b   r0,@r1

!------------------------------------------------------------------
! q_push: add (r6 = Y, r7 = X) to the queue. Uses r0 r1 r3; keeps r2 r4 r5.
!------------------------------------------------------------------
q_push:
        mov.l   L8_qc,r1
        mov.b   @r1,r0
        extu.b  r0,r0
        mov     #32,r3
        cmp/hs  r3,r0
        bt      .Lq_full
        mov     r0,r3
        shll2   r3
        shll    r3
        mov.l   r0,@-r15
        mov.l   L8_qb,r0
        add     r0,r3
        mov.l   @r15+,r0
        mov.l   r6,@r3
        mov.l   r7,@(4,r3)
        add     #1,r0
        mov.b   r0,@r1
.Lq_full:
        rts
        nop

!------------------------------------------------------------------
! arr_qspawn: called from arr_frame. Turns up to 8 queued hits per frame
! into 1,000-point score items (kind 9): each bursts upward a random 2..100 px,
! then falls twice as fast as a normal item, waving left or right at random.
!------------------------------------------------------------------
arr_qspawn:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   L9_items,r1         ! leave SKY_SPARE sky item slots free for the
        mov.w   W9_nsky,r2          ! game's own items: count the used ones
        mov     #0,r3
.Ls_cnt:
        mov.l   @r1,r0
        tst     r0,r0
        bt      .Ls_cfree
        add     #1,r3
.Ls_cfree:
        mov     #108,r0
        dt      r2
        bf/s    .Ls_cnt
        add     r0,r1
        mov.w   W9_room,r11         ! r11 = 192 - SKY_SPARE - used, at most 8
        sub     r3,r11
        cmp/pl  r11
        bt      .Ls_lim
        bra     .Ls_clear           ! no room: drop what's queued
        nop
.Ls_lim:
        mov     #8,r0
        cmp/gt  r0,r11
        bf      .Ls_loop
        mov     #8,r11              ! per-frame limit
.Ls_loop:
        mov.l   L8_qc,r1
        mov.b   @r1,r0
        extu.b  r0,r0
        tst     r0,r0
        bt      .Ls_done
        tst     r11,r11
        bt      .Ls_done
        mov.l   L9_alloc,r0         ! grab one sky item slot
        jsr     @r0
        mov     #1,r4
        tst     r0,r0
        bt      .Ls_clear           ! pool full: drop the rest
        add     #-1,r11
        mov.l   L8_qc,r1            ! pop the newest entry
        mov.b   @r1,r0
        add     #-1,r0
        mov.b   r0,@r1
        extu.b  r0,r0
        shll2   r0
        shll    r0
        mov.l   L8_qb,r1
        add     r0,r1
        mov.l   @r1,r8              ! Y
        mov.l   @(4,r1),r10         ! X
        mov.l   L9_slots,r1
        mov.w   @r1,r4              ! slot index
        mov     #108,r0
        mul.l   r0,r4
        sts     macl,r9
        mov.l   L9_items,r0
        add     r0,r9               ! r9 -> item object
        mov.l   L9_flags,r0
        mov.l   r0,@r9
        mov.l   L9_kind,r1          ! score item kind 0 = 100 points ("100" pop-up)
        mov.b   @r1,r0
        mov.l   r0,@-r15
        mov     #0,r0
        mov.b   r0,@r1
        mov     #2,r5               ! type 2: score item
        mov     #0,r6
        mov     r8,r7
        mov.l   L9_drop,r0
        jsr     @r0
        nop
        mov.l   @r15+,r0
        mov.l   L9_kind,r1
        mov.b   r0,@r1
        mov.l   r8,@(44,r9)         ! Y
        mov.l   r10,@(48,r9)        ! X
        bsr     rng                 ! random launch height 2..100 px
        nop
        shlr16  r0
        and     #15,r0
        shll2   r0
        mov     r0,r3
        mova    vtab,r0
        add     r3,r0
        mov.l   @r0,r0
        mov.l   r0,@(52,r9)         ! upward speed sqrt(h/8), then gravity 1/16
        mov     #0,r0
        mov.l   r0,@(56,r9)
        mov     #0x74,r0            ! +84 phase: skip the intro, fall like a normal drop
        mov     r9,r1
        add     #84,r1
        mov.b   r0,@r1
        mov.l   L9_rank,r1          ! fall speed by rank, as the game does ...
        mov.l   @r1,r2
        mov.l   L9_one,r1
        sub     r2,r1
        shlr8   r1
        shlr2   r1
        shlr2   r1
        mov.l   L9_neg1,r2
        sub     r1,r2
        shll    r2                  ! ... times two
        mov     r9,r1
        add     #68,r1
        mov.l   r2,@r1
        bsr     rng                 ! random wave: step 3..6, left or right first
        nop
        shlr16  r0
        mov     r0,r3
        and     #3,r0
        add     #3,r0
        mov     r0,r2
        mov     r3,r0
        tst     #4,r0
        bt      .Ls_wr
        neg     r2,r2
.Ls_wr:
        mov     r9,r1
        add     #90,r1
        mov     #0,r0
        mov.w   r0,@r1              ! +90 wave phase
        mov     r2,r0
        mov.w   r0,@(2,r1)          ! +92 wave step
        add     #14,r1              ! +104: cracker flower (setup clears it)
        mov     #FLOWERMARK-256,r0
        mov.b   r0,@r1
        add     #2,r1               ! +106
        mov     #0,r0
        mov.b   r0,@r1
        bra     .Ls_loop
        nop
.Ls_clear:
        mov.l   L8_qc,r1
        mov     #0,r0
        mov.b   r0,@r1
.Ls_done:
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 1
W8_cc:      .word 0xCC
W9_nsky:    .word 192
W9_room:    .word 192 - 48             ! keep 48 sky item slots for the game
        .align 2
L8_flag:    .long VAR_FLAG
L8_real:    .long REALPLAY
L8_crk:     .long VAR_CRK
L8_dmg:     .long 0x0C084F10
L8_parts:   .long 0x0C416968
L8_hret:    .long 0x0C085044
L8_cancel:  .long 0x0C088940
L8_qc:      .long QCOUNT
L8_crkbit:  .long 0x08000000
L8_ticks:   .long VAR_TICKS
L8_hold:    .long VAR_CRKHOLD
L8_qb:      .long QBUF
L8_boss:    .long VAR_BOSS
L8_kpart:   .long VAR_KPART
L8_kills:   .long VAR_KILLS
L9_alloc:   .long 0x0C083620
L9_slots:   .long 0x0C42389E
L9_items:   .long 0x0C5B68EC
L9_flags:   .long 0xC0800004
L9_kind:    .long SCOREKIND
L9_drop:    .long 0x0C082AB0
L9_rank:    .long 0x0C453AB0
L9_one:     .long 0x01000000
L9_neg1:    .long 0xFFFF0000
vtab:       ! launch speed for heights 2, 8.5, 15.1 ... 100 px (sqrt(h/8), 16.16)
        .long 0x08000, 0x10865, 0x15f52, 0x1a4a7, 0x1e012, 0x214e8, 0x244f5, 0x27153
        .long 0x29abf, 0x2c1be, 0x2e6b2, 0x309e4, 0x32b90, 0x34be5, 0x36b08, 0x38919

!------------------------------------------------------------------
! rng: 32-bit LCG in VAR_SEED, stirred with the frame's P1 score.
! Returns r0. Uses r1 r2.
!------------------------------------------------------------------
rng:
        mov.l   LR_seed,r1
        mov.l   @r1,r0
        mov.l   LR_lcgm,r2
        mul.l   r2,r0
        sts     macl,r0
        mov.l   LR_lcga,r2
        add     r2,r0
        mov.l   L9_score,r2
        mov.l   @r2,r2
        add     r2,r0
        mov.l   r0,@r1
        rts
        nop
        .align 2
L9_score:   .long P1 + 0x298
LR_seed:    .long VAR_SEED
LR_lcgm:    .long 1103515245
LR_lcga:    .long 12345

!==================================================================
! arr_item: replaces 0x0C083320..0x0C08332B, the start of the common
! item setup routine (r4 = item slot; type at +4, kind at +8 already set).
! In Rosy Arrange, shot items (type 0: power-up / wide / rapid) and
! rose hips (type 1) become score items (type 2) of the last score kind.
! Leaf routine: PR is live, no calls. Free: r0 r1 r2 r3 r5 r6 r7.
!==================================================================
arr_item:
        mov.l   L4_flag,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Li_out
        mov.l   L4_real,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Li_out
        exts.w  r4,r5
        mov     #108,r2
        mul.l   r2,r5
        sts     macl,r6
        mov.l   L4_items,r7
        add     r7,r6               ! r6 -> item object
        mov.l   @(4,r6),r0
        mov     #1,r1
        cmp/hi  r1,r0
        bt      .Li_out             ! not a shot item or rose hip
        mov     #2,r0
        mov.l   r0,@(4,r6)          ! -> score item
        mov     #18,r0              ! rainbow rose, worth 10,000
        mov.l   r0,@(8,r6)
.Li_out:
        exts.w  r4,r5               ! --- replayed original code ---
        mov     #108,r2
        mul.l   r2,r5
        mov.l   L4_items,r7
        mov     #5,r0
        mov.l   r14,@-r15
        mov.l   L4_ret,r1
        jmp     @r1
        nop
        .align 2
L4_flag:    .long VAR_FLAG
L4_real:    .long REALPLAY
L4_items:   .long 0x0C5B68EC
L4_ret:     .long 0x0C08332C
!==================================================================
! arr_drop: replaces 0x0C082B22..0x0C082B2B in the enemy drop routine,
! right after the item type (r3) is chosen and before it is stored.
! In Rosy Arrange, shot items (0) and rose hips (1) become score items (2);
! the game then gives them the current score item kind itself.
! Entry: r0 = 108, r4 = slot, r3 = type. Exit to 0x0C082B2C with
! r2 = item object, r7 = item array, r0 = type. PR live, r1 free.
!==================================================================
arr_drop:
        mul.l   r0,r4               ! --- replayed original code ---
        mov.l   L5_items,r7
        sts     macl,r2
        add     r7,r2
        mov.l   L5_flag,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Ld_out
        mov.l   L5_real,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Ld_out
        mov     #1,r0
        cmp/hi  r0,r3
        bt      .Ld_out             ! keep score items, 1UP, others
        mov     #2,r3               ! shot item / rose hip -> rainbow rose
        mov.l   r3,@(4,r2)
        mov     #18,r1              ! score item kind 18, worth 10,000
        mov.l   L5_setkind,r0
        jmp     @r0                 ! game stores kind r1 and finishes setup
        nop
.Ld_out:
        mov     r3,r0
        mov.l   L5_ret,r1
        jmp     @r1
        nop
        .align 2
L5_items:   .long 0x0C5B68EC
L5_flag:    .long VAR_FLAG
L5_real:    .long REALPLAY
L5_ret:     .long 0x0C082B2C
L5_setkind: .long 0x0C082B4A

!==================================================================
! arr_print: the top HUD prints the 1P, 2P and TOP scores through the
! number printer 0x0C075AF0 (r4 value, r5 row, r6 column offset, r7
! attribute; 7 digits, units at column 6 + r6) via the literal at
! 0x0C072560, which now points here. In Rosy Arrange play the 1P score
! (r6 = 2) and TOP score (r6 = 13) are printed with 9 digits one row lower
! (row 38, units at columns 8 and 19) and their row-39 fields are blanked.
! The game prints TOP only at stage start, so the per-frame 1P call
! reprints TOP too. Everything else goes to the original printer.
!==================================================================
arr_print:
        mov.l   LP_flag,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lp_orig
        mov.l   LP_real,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lp_orig
        mov     r5,r0
        cmp/eq  #39,r0
        bf      .Lp_orig
        mov     r6,r0
        cmp/eq  #2,r0
        bt      .Lp_ours
        cmp/eq  #13,r0
        bt      .Lp_ours
.Lp_orig:
        mov.l   LP_print,r0
        jmp     @r0
        nop
.Lp_ours:
        sts.l   pr,@-r15
        mov     r6,r0
        cmp/eq  #2,r0
        bf/s    .Lp_one
        mov.l   r6,@-r15
        bsr     score_cap           ! (a score that went past 4,294,967,295 stays there)
        nop
        mov     r0,r4
        bsr     print9              ! 1P score
        nop
        mov.l   LP_top,r0           ! and TOP (only printed at stage start by the game)
        mov.l   @r0,r4
        mov.l   LP_tattr,r0
        mov.l   @r0,r7
        mov     #13,r6
.Lp_one:
        bsr     print9
        nop
        bsr     rank_lbl            ! "RANK" over the old TOP field's last column
        nop
        mov.l   @r15+,r6
        lds.l   @r15+,pr
        rts
        nop

! rank_lbl: Rosy Future prints "RK" at row 39 cols 21-22 with the value at
! cols 25-29. In Rosy Arrange "RANK" goes at cols 19-22 instead (the row-39
! TOP field is free since TOP moved down). Called from arr_print and
! arr_frame, whichever runs last each frame. Uses r0-r2.
rank_lbl:
        mov.l   LP_rank,r1
        mova    rank_str,r0
        mov     r0,r2
        mov.l   r3,@-r15
        mov     #4,r3
.Lrk:
        mov.b   @r2+,r0
        extu.b  r0,r0
        mov.l   r4,@-r15
        mov.l   LP_rattr,r4
        or      r4,r0
        mov.l   @r15+,r4
        mov.l   r0,@r1
        dt      r3
        bf/s    .Lrk
        add     #4,r1
        .ifdef  STANDALONE
        ! standalone (no Rosy Future HUD): the value "dd.dd" at cols 25-29
        ! (cols 23-24 blank), RANK % = (2^24 - rank) / 2^24
        mov.l   r4,@-r15
        mov.l   r5,@-r15
        mov.l   LP_rankv,r0
        mov.l   @r0,r0
        mov.l   LP_one24,r2
        sub     r0,r2
        shlr8   r2
        mov.w   WP_10k,r0
        mul.l   r0,r2
        sts     macl,r2
        shlr16  r2                  ! r2 = RANK x 100 (0..10000)
        mov.w   WP_9999,r0
        cmp/hi  r0,r2
        bf      .Lrv_ok
        mov     r0,r2
.Lrv_ok:
        mov.l   LP_rattrw,r4        ! white
        mov     #0x20,r0
        or      r4,r0
        mov.l   r0,@r1              ! col 23
        add     #4,r1
        mov.l   r0,@r1              ! col 24
        add     #4,r1
        mova    rv_pow,r0
        mov     r0,r5
        mov     #4,r3
.Lrv_dig:
        mov.w   @r5+,r0             ! power of ten
        mov     #0x30,r4            ! '0'
.Lrv_sub:
        cmp/hs  r0,r2
        bf      .Lrv_put
        sub     r0,r2
        bra     .Lrv_sub
        add     #1,r4
.Lrv_put:
        mov.l   LP_rattrw,r0
        or      r0,r4
        mov.l   r4,@r1
        add     #4,r1
        mov     r3,r0
        cmp/eq  #3,r0               ! after the second digit: '.'
        bf      .Lrv_next
        mov.l   LP_rattrw,r0
        add     #0x2E,r0
        mov.l   r0,@r1
        add     #4,r1
.Lrv_next:
        dt      r3
        bf      .Lrv_dig
        mov.l   @r15+,r5
        mov.l   @r15+,r4
        .endif
        mov.l   @r15+,r3
        mov.l   LP_dirty,r1
        mov     #1,r0
        rts
        mov.b   r0,@(1,r1)          ! row 39 dirty
        .align 2
        .ifdef  STANDALONE
rv_pow:     .word 1000, 100, 10, 1
WP_10k:     .word 10000
WP_9999:    .word 9999
        .endif
        .align 2
        .ifdef  STANDALONE
LP_rankv:   .long 0x0C453AB0
LP_one24:   .long 0x01000000
LP_rattrw:  .long 0x80808000
        .endif
rank_str:   .ascii "RANK"
        .align 2
LP_rank:    .long TEXT + 39*0x80 + 19*4
LP_rattr:   .long 0x4040C000        ! Rosy Future's blue "RK" colour

! score_cap: the game adds to the score with no limit, so past 4,294,967,295
! it would wrap to a small number. A drop from 0xF0000000 or more to a
! non-zero value under 0x10000000 is such a wrap (a new game resets it to 0):
! the score is set to 4,294,967,295. Returns the P1 score in r0. Uses r0-r3.
score_cap:
        mov.l   LS_score,r1
        mov.l   @r1,r0
        mov.l   LS_prev,r3
        mov.l   @r3,r2
        cmp/hs  r2,r0
        bt      .Lsc_save
        mov.l   LS_hi,r2            ! r2 = previous score: was it near the top?
        mov.l   @r3,r3
        cmp/hs  r2,r3
        mov.l   LS_prev,r3
        bf      .Lsc_save
        mov.l   LS_lo,r2
        cmp/hs  r2,r0
        bt      .Lsc_save
        tst     r0,r0
        bt      .Lsc_save
        mov     #-1,r0
        mov.l   r0,@r1
.Lsc_save:
        rts
        mov.l   r0,@r3
        .align 2
LS_score:   .long P1 + 0x298
LS_prev:    .long VAR_PSCORE
LS_hi:      .long 0xF0000000
LS_lo:      .long 0x10000000

! print9: r4 value, r6 column offset (field units at column 6 + r6), r7
! attribute. Blanks the 7-digit field on row 39 and prints the value with 9
! characters on row 38, same units column: 8 digits (leading zeros blank)
! and a top character for value / 100,000,000 from the game's own table
! (0-9, then A = 10 ... Z = 35, a = 36 ... g = 42), up to "g94967295".
print9:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov     r7,r10              ! attribute
        mov     r6,r8               ! units cell of the old field: TEXT + 0x18 + (39*32 + r6)*4
        shll2   r8
        mov.l   LP_row39,r0
        add     r0,r8
        mov     #0x20,r0            ! blank the old 7-digit field
        or      r10,r0
        mov     r8,r1
        mov     #7,r2
.Lp_blank:
        mov.l   r0,@r1
        dt      r2
        bf/s    .Lp_blank
        add     #-4,r1
        mov.w   WP_row,r0           ! same column, one row lower
        sub     r0,r8
        mov     r4,r9               ! r9 = value left
        mov.l   LP_1e8,r2           ! top = value / 100,000,000 by subtraction (the
        mov     #0,r3               ! game's divide is signed: no good past 2^31)
.Lp_top:
        cmp/hs  r2,r9
        bf      .Lp_tdone
        sub     r2,r9
        bra     .Lp_top
        add     #1,r3
.Lp_tdone:
        mov.l   r3,@-r15            ! keep top on the stack
        mov     #8,r11
.Lp_dig:
        mov     r9,r4
        mov.l   LP_div,r0           ! r0 = r4 / 10, r1 = r4 % 10
        jsr     @r0
        mov     #10,r5
        mov     #8,r2               ! units digit always; leading zeros blank
        cmp/eq  r2,r11
        bt      .Lp_num
        tst     r9,r9
        bf      .Lp_num
        mov.l   @r15,r2             ! (zeros below a top character are shown)
        tst     r2,r2
        bf      .Lp_num
        mov     #0x20,r1
        bra     .Lp_put
        nop
.Lp_num:
        add     #0x30,r1
.Lp_put:
        or      r10,r1
        mov.l   r1,@r8
        add     #-4,r8
        dt      r11
        bf/s    .Lp_dig
        mov     r0,r9
        mov.l   @r15+,r9
        mov.l   LP_ltab,r0          ! top character: value / 100,000,000 through the
        mov.b   @(r0,r9),r1         ! game's " 123456789ABC..." table (A = 10 .. g = 42)
        extu.b  r1,r1
        or      r10,r1
        mov.l   r1,@r8
        mov.l   LP_dirty,r1
        mov     #1,r0
        mov.b   r0,@r1              ! row 38
        mov.b   r0,@(1,r1)          ! row 39
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 1
WP_row:     .word 0x80
        .align 2
LP_flag:    .long VAR_FLAG
LP_real:    .long REALPLAY
LP_print:   .long 0x0C075AF0
LP_div:     .long 0x0C0F4540
LP_row39:   .long TEXT + 0x18 + 39*0x80
LP_ltab:    .long 0x0C0F68C6
LP_1e8:     .long 100000000
LP_dirty:   .long DIRTY + 38
LP_top:     .long 0x0C3D64A8
LP_tattr:   .long 0x0C4AEACC

!------------------------------------------------------------------
! arr_icons: the life icons are drawn by 0x0C0782F0 into rows 38 (top
! half) and 37 (bottom half), cols 0..9, using the row-38 address literal
! at 0x0C0783E8 and the dirty-flag literal at 0x0C0783F0. In Rosy Arrange
! play those literals are switched to rows 37/36 so the 9-digit score fits
! on row 38. On a switch the row left behind is cleared and a redraw is
! requested (P1 +4 bit 31). The 1P speech subtitle (part table at
! 0x0C1141EC) is moved 8 lower to match. Called from arr_frame every frame.
! Uses r0-r3.
!------------------------------------------------------------------
arr_icons:
        mov.l   LI_flag,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lic_set
        mov.l   LI_real,r1
        mov.b   @r1,r0
.Lic_set:
        tst     r0,r0
        mov.l   LI_rowA,r2          ! normal: row 38, dirty 38
        mov.l   LI_dirA,r3
        bt      .Lic_have
        mov.l   LI_rowB,r2          ! arrange: row 37, dirty 37
        mov.l   LI_dirB,r3
.Lic_have:
        mov.l   LI_sub,r0           ! 1P speech subtitle (top part) Y: 0x120, or
        mov.w   WI_sub,r1           ! 8 lower in Rosy Arrange (below the icons)
        bt      .Lic_sy
        add     #-8,r1
.Lic_sy:
        mov.w   r1,@r0
        mov.l   LI_lit,r0
        mov.l   @r0,r0
        cmp/eq  r0,r2
        bt      .Lic_out
        mov.l   LI_lit,r0
        mov.l   r2,@r0
        mov.l   LI_dlit,r0
        mov.l   r3,@r0
        mov.l   LI_rowA,r0          ! row left behind: 36 when moving to 37, else 38
        cmp/eq  r0,r2
        mov.l   LI_clrA,r1
        bt      .Lic_c
        mov.l   LI_clrB,r1
.Lic_c:
        mov     #10,r2              ! clear cols 0..9 of the row left behind
        mov     #0,r0
.Lic_clr:
        mov.l   r0,@r1
        dt      r2
        bf/s    .Lic_clr
        add     #4,r1
        mov.l   LI_p1,r1            ! ask the game to redraw the icons
        mov.l   @(4,r1),r0
        mov.l   LI_bit,r2
        or      r2,r0
        mov.l   r0,@(4,r1)
        mov.l   LI_dirty,r1         ! rows 36..38 dirty
        mov     #1,r0
        mov.b   r0,@r1
        mov.b   r0,@(1,r1)
        mov.b   r0,@(2,r1)
.Lic_out:
        rts
        nop
        .align 2
LI_flag:    .long VAR_FLAG
LI_real:    .long REALPLAY
LI_lit:     .long 0x0C0783E8
LI_dlit:    .long 0x0C0783F0
LI_rowA:    .long TEXT + 38*0x80
LI_dirA:    .long DIRTY + 38
LI_clrA:    .long TEXT + 36*0x80
LI_rowB:    .long TEXT + 37*0x80
LI_dirB:    .long DIRTY + 37
LI_clrB:    .long TEXT + 38*0x80
LI_p1:      .long P1
LI_bit:     .long 0x80000000
LI_dirty:   .long DIRTY + 36
LI_sub:     .long 0x0C1141FA        ! subtitle part table 0x0C1141EC, part 1 Y (word)
        .align 1
WI_sub:     .word 0x120
        .align 2

!------------------------------------------------------------------
! arr_rankdn: on respawn the game lowers the rank through 0x0C078EA0
! (r4 = amount, from a table by lives: 3.125..12.5 RK points), called via
! the literal at 0x0C07EB60, which now points here. In Rosy Arrange play
! the amount is a flat 10 RK points (0.1 x 2^24). The game's own floor
! (rank cap at 0x0C3B0B08) still applies.
!------------------------------------------------------------------
arr_rankdn:
        mov.l   LR_flag,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lrk_go
        mov.l   LR_real,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lrk_go
        mov.l   LR_ten,r4
.Lrk_go:
        mov.l   LR_down,r0
        jmp     @r0
        nop
        .align 2
LR_flag:    .long VAR_FLAG
LR_real:    .long REALPLAY
        .ifdef  STANDALONE
LR_ten:     .long 1677722               ! death: rank 10 RK points easier
        .else
LR_ten:     .long 503316                ! death: rank 3 RK points easier
        .endif
LR_down:    .long 0x0C078EA0

!==================================================================
! arr_collect: every caller of the pickup routine 0x0C0935C0 (r4 = player,
! r5 = item slot) now comes here. A cracker flower (item +104 marked by
! arr_qspawn) collected within 60 frames of the previous one doubles the
! bonus: 1000, x2, x4 ... x64 (max, kept while the chain lasts). The game
! scores the 1,000 and turns the item into its pop-up; this adds the rest
! and swaps the pop-up for the "1000xN" label.
!==================================================================
arr_collect:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov     r4,r8
        exts.w  r5,r0
        mov     #108,r1
        mul.l   r1,r0
        sts     macl,r9
        mov.l   LK_items,r0
        add     r0,r9               ! r9 -> item object
        mov     #-1,r10             ! r10 = multiplier - 1 (-1: not a cracker flower)
        mov     r9,r1
        add     #104,r1
        mov.b   @r1,r0
        cmp/eq  #FLOWERMARK-256,r0
        bf      .Lk_call
        mov.l   LK_mult,r1
        mov.l   @r1,r10             ! last multiplier (0 = no chain): the new one is +1
        mov.l   LK_chain,r2
        mov.b   @(1,r2),r0          ! VAR_CTIME
        extu.b  r0,r0
        mov     #60,r3
        cmp/hi  r3,r0
        bf      .Lk_live
        mov     #0,r10              ! more than a second: start again at 1000
.Lk_live:
        mov     r10,r0
        add     #1,r0
        mov.l   r0,@r1              ! VAR_MULT = multiplier
        mov     #0,r0
        mov.b   r0,@(1,r2)          ! VAR_CTIME = 0
.Lk_call:
        mov.l   LK_collect,r0
        jsr     @r0
        nop
        cmp/pz  r10
        bf      .Lk_out             ! not a cracker flower
        .ifndef STANDALONE
        mov.l   LK_fsnd,r1          ! its pickup sound plays 50% louder (snd_hook)
        mov     #3,r0
        mov.b   r0,@r1
        .endif
        mov.l   LK_rank,r1          ! the game raised rank 0x100 for it: keep only
        mov.l   @r1,r0              ! 168 (1000 flowers ~ RANK +1)
        mov.w   WK_back,r2
        add     r2,r0
        mov.l   r0,@r1
        bsr     pop_under           ! pop-up starts under the ship
        nop
        bsr     fifo_push           ! "+<points> x<kills>" line in the chain list
        nop
        bsr     kmul                ! r0 = kill multiplier 1..32
        nop
        mov     r10,r1              ! pays 100 x chain x kills; the game paid 100
        add     #1,r1
        mul.l   r0,r1
        sts     macl,r1
        add     #-1,r1
        tst     r1,r1
        bt      .Lk_out
        mov.w   WK_1000,r0          ! score += 100 x (chain x kills - 1)
        mul.l   r1,r0
        sts     macl,r1
        exts.w  r8,r0
        mov.w   WK_2b8,r2
        mul.l   r2,r0
        sts     macl,r2
        mov.l   LK_score,r0
        add     r0,r2
        mov.l   @r2,r0
        clrt
        addc    r1,r0               ! score += bonus, at most 4,294,967,295
        bf      .Lk_sc
        mov     #-1,r0
.Lk_sc:
        mov.l   r0,@r2
.Lk_out:
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 1
WK_1000:    .word 100
WK_back:    .word 0x100 - 168
WK_2b8:     .word 0x2B8
        .align 2
LK_fsnd:    .long VAR_FLWSND
LK_items:   .long 0x0C5B68EC
LK_chain:   .long VAR_CHAIN
LK_collect: .long 0x0C0935C0
LK_score:   .long P1 + 0x298
LK_mult:    .long VAR_MULT
LK_rank:    .long 0x0C453AB0

!------------------------------------------------------------------
! mk_label: r4 = multiplier (>= 2). Puts a "1000x<n>" label together in the
! next of 8 slots of the pop-up page in VRAM (16 x 112 each at page x 0/16/
! 32/48, y 0/112) by appending to a blitter list run at the next kick: clear
! the slot (2 opaque copies of the blank page column x 64..71), the game's
! "1000", the uploaded "x" and the game's pop-up digits (any number of
! digits). Returns in r0 the slot's frame record (sprite def in RAM). Uses
! r0-r7.
!------------------------------------------------------------------
mk_label:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   LM_slot,r1
        mov.b   @r1,r0
        extu.b  r0,r0
        mov     r0,r2
        add     #1,r2
        and     #7,r0
        mov.b   r2,@r1              ! next slot
        mov     r0,r10              ! r10 = slot 0..7
        and     #3,r0
        shll2   r0
        shll2   r0
        mov     r0,r11              ! r11 = page x (0, 16, 32, 48)
        mov     r10,r0
        shlr2   r0
        mov     #112,r1
        mulu.w  r1,r0
        sts     macl,r0
        shll8   r11
        or      r0,r11              ! r11 = (page x << 8) | page y
        ! blitter list: start a new one or append
        mov.l   LM_lptr,r1
        mov.l   @r1,r9
        tst     r9,r9
        bf      .Lm_app
        mov.l   LM_lbuf,r9
        mov.w   WM_clip,r0
        mov.w   r0,@r9
        mov     #0,r0
        mov.w   r0,@(2,r9)
        add     #4,r9
.Lm_app:
        mov.l   LM_lend,r0          ! full (more than ~14 labels in one frame): skip drawing
        cmp/hs  r0,r9
        bt      .Lm_def
        ! dest VRAM x = 0x1900 + page x, y = 0x300 + page y
        mov     r11,r6
        shlr8   r6
        mov.w   WM_vx,r0
        add     r0,r6               ! r6 = dest x
        extu.b  r11,r7
        mov.w   WM_vy,r0
        add     r0,r7               ! r7 = dest y (slot top)
        ! clear: 2 opaque copies of the blank 8-wide column (page x 64..71)
        mov.w   WM_opq,r0
        mov.w   r0,@r9
        mov.w   WM_blkx,r0
        mov.w   r0,@(4,r9)
        mov.w   WM_vy,r0
        mov.w   r0,@(6,r9)
        mov     r6,r0
        mov.w   r0,@(8,r9)
        mov     r7,r0
        mov.w   r0,@(10,r9)
        mov     #7,r0
        mov.w   r0,@(12,r9)
        mov     #111,r0
        mov.w   r0,@(14,r9)
        bsr     mk_cmdtail
        nop
        mov.w   WM_opq,r0
        mov.w   r0,@r9
        mov.w   WM_blkx,r0
        mov.w   r0,@(4,r9)
        mov.w   WM_vy,r0
        mov.w   r0,@(6,r9)
        mov     r6,r0
        add     #8,r0
        mov.w   r0,@(8,r9)
        mov     r7,r0
        mov.w   r0,@(10,r9)
        mov     #7,r0
        mov.w   r0,@(12,r9)
        mov     #111,r0
        mov.w   r0,@(14,r9)
        bsr     mk_cmdtail
        nop
        ! "1000" (45 rows) at +1, "x" (11 rows) at +46
        mov.w   WM_src1kx,r0
        mov     r0,r1
        mov.w   WM_src1ky,r0
        mov     r0,r2
        mov     #1,r3
        mov     #45,r5
        bsr     mk_draw
        nop
        mov.w   WM_xsx,r0
        mov     r0,r1
        mov.w   WM_xsy,r0
        mov     r0,r2
        mov     #46,r3
        mov     #11,r5
        bsr     mk_draw
        nop
        ! digits from row 57
        mov     #57,r8              ! r8 = next row
        mov     #0,r0
        mov.l   r0,@-r15            ! [r15] = height of the previous digit
        mova    mk_pow,r0
        mov.l   r0,@-r15            ! [r15] -> powers of ten
        mov     #0,r0
        mov.l   r0,@-r15            ! [r15] = 1 once a digit has been placed
.Lm_pow:
        mov.l   @(4,r15),r2
        mov.l   @r2+,r1
        mov.l   r2,@(4,r15)
        tst     r1,r1
        bt      .Lm_end
        mov     #0,r0
.Lm_sub:
        cmp/hs  r1,r4
        bf      .Lm_dig
        sub     r1,r4
        bra     .Lm_sub
        add     #1,r0
.Lm_dig:
        tst     r0,r0
        bf      .Lm_put
        mov.l   @r15,r1
        tst     r1,r1
        bf      .Lm_put
        mov.l   @r2,r1              ! leading zero (not the last digit): skip
        tst     r1,r1
        bf      .Lm_pow
.Lm_put:
        mov     #1,r1
        mov.l   r1,@r15
        mov     r0,r1
        add     r1,r1
        add     r0,r1               ! digit * 3
        mova    mk_dig,r0
        add     r0,r1
        mov.b   @(2,r1),r0
        extu.b  r0,r5               ! h
        mov     r5,r0
        cmp/eq  #13,r0
        bf      .Lm_noov
        mov.l   @(8,r15),r0
        cmp/eq  #13,r0
        bf      .Lm_noov
        add     #-1,r8              ! two full digits share an outline column
.Lm_noov:
        mov.l   r5,@(8,r15)
        mov.b   @r1,r0
        extu.b  r0,r0
        mov.w   WM_vx,r2
        add     r0,r2               ! (keep for r1 below)
        mov.b   @(1,r1),r0
        extu.b  r0,r0
        mov.w   WM_vy,r3
        add     r3,r0
        mov     r2,r1               ! src x
        mov     r0,r2               ! src y
        mov     r8,r3               ! row
        bsr     mk_draw
        nop
        bra     .Lm_pow
        add     r5,r8
.Lm_end:
        add     #12,r15
        mov.l   LM_lptr,r1
        mov.l   r9,@r1              ! list continues here
        bra     .Lm_def2
        nop
.Lm_def:
        mov     #110,r8             ! (not drawn this time) full-slot height
.Lm_def2:
        ! sprite def for this slot: page (x, y), 16 wide, rows 0..r8, centred
        mov     r10,r0
        shll2   r0
        shll2   r0
        shll    r0                  ! slot * 32
        mov.l   LM_ring,r1
        add     r0,r1               ! r1 = [def ptr, page] + def
        mov     r1,r2
        add     #8,r2
        mov.l   r2,@r1
        mov.l   LM_page,r0
        mov.l   r0,@(4,r1)
        mov.w   WM_def0,r0
        mov.w   r0,@r2
        mov     r11,r0
        mov.w   r0,@(2,r2)
        mov     r8,r0
        add     #1,r0
        shlr    r0
        neg     r0,r0
        extu.b  r0,r0
        mov.w   WM_xoff,r3
        or      r3,r0
        mov.w   r0,@(4,r2)
        mov     r8,r0
        mov.w   WM_w15,r3
        or      r3,r0
        mov.w   r0,@(6,r2)
        mov     #0,r0
        mov.w   r0,@(8,r2)
        mov.w   r0,@(10,r2)
        mov.w   r0,@(12,r2)
        mov.w   r0,@(14,r2)
        mov.w   r0,@(16,r2)
        mov.w   r0,@(18,r2)         ! end of the def list
        mov     r1,r0
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

! mk_draw: transparent copy (r1, r2) = source VRAM x/y, r5 = rows, to the
! slot (r6 = dest x, r7 = slot top) at row r3. Appends 20 bytes at r9.
mk_draw:
        mov.w   WM_trn,r0
        mov.w   r0,@r9
        mov     r1,r0
        mov.w   r0,@(4,r9)
        mov     r2,r0
        mov.w   r0,@(6,r9)
        mov     r6,r0
        mov.w   r0,@(8,r9)
        mov     r7,r0
        add     r3,r0
        mov.w   r0,@(10,r9)
        mov     #15,r0
        mov.w   r0,@(12,r9)
        mov     r5,r0
        add     #-1,r0
        mov.w   r0,@(14,r9)
! mk_cmdtail: the common end of a draw command at r9; r9 += 20.
mk_cmdtail:
        mov     #0,r0
        mov.w   r0,@(2,r9)
        mov     #0x80,r0
        mov.w   r0,@(16,r9)
        mov.w   WM_tint,r0
        mov.w   r0,@(18,r9)
        rts
        add     #20,r9
        .align 2
mk_pow:     .long 100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1, 0
mk_dig:     ! (page x, page y, height) of each pop-up digit
        .byte 0xE0, 0x82, 13        ! 0  (from "1000")
        .byte 0xE0, 0x7A, 8         ! 1  (from "1000")
        .byte 0xF0, 0x2A, 13        ! 2  (first digit of "200")
        .byte 0xF0, 0x52, 13        ! 3
        .byte 0xF0, 0x7A, 13        ! 4
        .byte 0xF0, 0xA2, 13        ! 5
        .byte 0xF0, 0xCA, 13        ! 6
        .byte 0xE0, 0x02, 13        ! 7  (first digit of "700")
        .byte 0xE0, 0x2A, 13        ! 8
        .byte 0xE0, 0x52, 13        ! 9
        .align 1
WM_clip:    .word 0xC000
WM_vx:      .word 0x1900
WM_vy:      .word 0x300
WM_opq:     .word 0x1000
WM_trn:     .word 0x1100
WM_tint:    .word 0x8080
WM_blkx:    .word 0x1940            ! blank column, page x 64
WM_src1kx:  .word 0x19E0            ! the game's "1000"
WM_src1ky:  .word 0x37A
WM_xsx:     .word 0x1930            ! the uploaded "x" (page 48, 240)
WM_xsy:     .word 0x3F0
WM_def0:    .word 0x1401
WM_w15:     .word 0x0F00
WM_xoff:    .word 0xF800
        .align 2
LM_slot:    .long VAR_LSLOT
LM_ring:    .long LBL_RING
LM_page:    .long 0x0C106310
LM_lptr:    .long VAR_LPTR
LM_lbuf:    .long LBLBUF
LM_lend:    .long LBLBUF + 0x1000 - 300

!------------------------------------------------------------------
! pop_under: r9 = a cracker flower just turned into its pop-up. Moves it
! under the ship (arr_pops rolls it down), and shortens the
! game's pop-up sequence: the reveal starts 6/16 open so it ends after 10
! frames, then the hold is 1 frame and the game's fade-out follows.
! arr_pops (from arr_frame) rolls it for 10 frames and speeds up the fade. Marks the pop-up +104 = POPMARK, +105 = age. Uses r0-r3.
!------------------------------------------------------------------
        .set    POPMARK,    0xCB
        .set    POP_SPEED,  3
        .set    POP_FRAMES, 10
pop_under:
        mov.l   LU_p1,r1
        mov.l   @(0x18,r1),r0       ! ship Y, X
        mov.l   LU_below,r2
        sub     r2,r0
        mov.l   r0,@(44,r9)
        mov.l   @(0x1C,r1),r0
        mov.l   r0,@(48,r9)
        mov     #0,r0               ! no item motion (pop-ups don't use it anyway)
        mov.l   r0,@(52,r9)
        mov.l   r0,@(56,r9)
        mov     r9,r1
        add     #68,r1
        mov.l   r0,@r1
        mov     r9,r1
        add     #84,r1
        mov     #0x74,r0            ! no intro hover
        mov.b   r0,@r1
        add     #6,r1               ! +90 wave phase, +92 wave step = 0
        mov     #0,r0
        mov.w   r0,@r1
        mov.w   r0,@(2,r1)
        add     #14,r1              ! +104 marker, +105 age
        mov     #POPMARK-256,r0
        mov.b   r0,@r1
        mov     #0,r0
        mov.b   r0,@(1,r1)
        add     #3,r1               ! +107 hold: 1 frame
        mov     #1,r0
        mov.b   r0,@r1
        mov     r9,r1               ! reveal: only if the game gave it a line buffer
        add     #100,r1             ! (+100 < count at 0x0C453798)
        mov.w   @r1,r0
        extu.w  r0,r0
        mov.l   LU_cnt,r2
        mov.w   @r2,r2
        extu.w  r2,r2
        cmp/hs  r2,r0
        bt      .Lu_out
        mov.l   @(40,r9),r1
        mov     #0x60,r0            ! 16 steps of 16 to 0x100 -> 10 steps
        mov.l   r0,@r1
        mov.w   WU_1a0,r0
        mov.l   r0,@(4,r1)
.Lu_out:
        rts
        nop

!------------------------------------------------------------------
! arr_pops: called every frame from arr_frame in Rosy Arrange play. For
! each pop-up marked by pop_under: count its age, move it down POP_SPEED
! px a frame for its first POP_FRAMES frames, and in the fade phase (+106 = 2) fade 4x faster. Uses r0-r7.
!------------------------------------------------------------------
arr_pops:
        mov.l   LU_items,r4
        mov.w   WU_nsky,r5          ! sky slots
.Lo_loop:
        mov.l   @r4,r0
        tst     r0,r0
        bt      .Lo_next
        mov     r4,r1
        add     #104,r1
        mov.b   @r1,r0
        cmp/eq  #POPMARK-256,r0
        bf      .Lo_next
        mov.l   @(4,r4),r0          ! still a pop-up (type 8/9)?
        mov     #-2,r2
        and     r2,r0
        cmp/eq  #8,r0
        bf      .Lo_next
        mov.b   @(1,r1),r0          ! age
        extu.b  r0,r0
        mov     #POP_FRAMES,r2
        cmp/hs  r2,r0
        bt      .Lo_fade
        add     #1,r0
        mov.b   r0,@(1,r1)
        mov.l   @(44,r4),r0         ! roll down POP_SPEED px this frame
        mov.l   LU_vy,r2
        add     r2,r0
        mov.l   r0,@(44,r4)
.Lo_fade:
        mov     r4,r3
        add     #106,r3
        mov.b   @r3,r0
        cmp/eq  #2,r0
        bf      .Lo_next
        mov     r4,r3               ! +62/+63 fade level: game takes 4 a frame,
        add     #62,r3              ! take 12 more while it stays above 15
        mov.b   @r3,r0
        extu.b  r0,r0
        mov     #15,r2
        cmp/hi  r2,r0
        bf      .Lo_next
        add     #-12,r0
        mov.b   r0,@r3
        mov.b   r0,@(1,r3)
.Lo_next:
        mov     #108,r0
        dt      r5
        bf/s    .Lo_loop
        add     r0,r4
        rts
        nop
        .align 1
WU_1a0:     .word 0x1A0
WU_nsky:    .word 192
        .align 2
LU_p1:      .long P1
LU_below:   .long 24 << 16
LU_vy:      .long -(POP_SPEED << 16)
LU_cnt:     .long 0x0C453798
LU_items:   .long 0x0C5B68EC

!------------------------------------------------------------------
! arr_kick: the main loop starts the blitter on each finished frame list
! at 0x0C062082, once the blitter is idle. That point now jumps here
! (0x0C062082..0x0C06208B replaced). When arr_frame asked for it,
! labels_blit first draws the "1000x2".."1000x64" labels into the pop-up
! page of VRAM. Then the replaced code is replayed. Keeps r3/r4/r7.
!------------------------------------------------------------------
arr_kick:
        sts.l   pr,@-r15
        mov.l   r3,@-r15
        bsr     labels_blit
        nop
        mov.l   @r15+,r3
        lds.l   @r15+,pr
        mov.l   LB_c00b4,r2         ! --- replayed original code ---
        mov.l   LB_b014,r6
        mov.l   @r2,r0
        mov.l   LB_ae108,r5
        mov.l   r0,@r6
        mov.l   LB_ret,r0
        jmp     @r0
        nop

! labels_blit: if VAR_CPEND is set, clear it and run blit_list (see build.py)
! on the blitter. Each run waits
! for the blitter to be idle first (skipped and retried next frame if it
! never is), and after starting waits for it to go busy and then idle again,
! so the game's own frame list never starts on top of ours (real hardware
! and MiSTer don't go busy the instant the blitter is started). Every wait
! has a limit. Uses r0-r3.
labels_blit:
        sts.l   pr,@-r15
        mov.l   LB_pend,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lr_out
        bsr     blt_idle
        nop
        tst     r0,r0
        bt      .Lr_out             ! never idle: try again at the next kick
        mov.l   LB_pend,r1
        mov     #0,r0
        mov.b   r0,@r1
        mov.l   LB_list,r3
        mov.l   LB_buf,r1
        mov.l   LB_n,r2
.Lr_copy:
        mov.l   @r3+,r0
        mov.l   r0,@r1
        dt      r2
        bf/s    .Lr_copy
        add     #4,r1
        mov.l   LB_buf,r0
        bsr     blt_run
        nop
.Lr_out:
        mov.l   LB_lptr,r1          ! "1000x<n>" labels built since the last kick
        mov.l   @r1,r0
        tst     r0,r0
        bt      .Lr_out2
        bsr     blt_idle
        nop
        tst     r0,r0
        bt      .Lr_out2
        mov.l   LB_lptr,r1
        mov.l   @r1,r2
        mov     #0,r0
        mov.l   r0,@r2              ! end of list
        mov.l   r0,@r1              ! none pending
        mov.l   LB_lbuf,r0
        bsr     blt_run
        nop
.Lr_out2:
        .ifndef STANDALONE
        mov.l   LB_bup,r1           ! boss health bar tiles into the text font
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lr_out3
        bsr     blt_idle
        nop
        tst     r0,r0
        bt      .Lr_out3
        mov.l   LB_bup,r1
        mov     #0,r0
        mov.b   r0,@r1
        mov.l   LB_blist,r0
        bsr     blt_run
        nop
        bra     .Lr_out4            ! one list per kick
        nop
.Lr_out3:
        mov.l   LB_hui,r1           ! HADOUGUN graphics, one chunk per kick
        mov.b   @r1,r0
        mov     #HG_NREG,r2
        cmp/hs  r2,r0
        bt      .Lr_out4
        bsr     blt_idle
        nop
        tst     r0,r0
        bt      .Lr_out4
        mov.l   LB_upchunk,r0
        jsr     @r0
        nop
.Lr_out4:
        .endif
        lds.l   @r15+,pr
        rts
        nop

! blt_idle: wait (with a limit) for the blitter ready bit. r0 = 1 if idle,
! 0 if it never was. Uses r0-r2.
blt_idle:
        mov.l   LB_stat,r1
        mov.l   LB_long,r2
.Lw_idle:
        mov.l   @r1,r0
        tst     #16,r0
        bf      .Lw_ok
        dt      r2
        bf      .Lw_idle
        rts
        mov     #0,r0
.Lw_ok:
        rts
        mov     #1,r0

! blt_run: start the blitter on the list at r0, wait (briefly) for it to
! go busy, then (with a limit) for it to finish. Uses r0-r2.
blt_run:
        mov.l   LB_addr,r1
        mov.l   r0,@r1
        mov.l   LB_exec,r1
        mov     #1,r0
        mov.l   r0,@r1
        mov.l   LB_stat,r1
        mov.w   WB_short,r2
.Lw_busy:
        mov.l   @r1,r0
        tst     #16,r0
        bt      .Lw_fin             ! busy now
        dt      r2
        bf      .Lw_busy
.Lw_fin:
        mov.l   LB_long,r2
.Lw_fin2:
        mov.l   @r1,r0
        tst     #16,r0
        bf      .Lw_done
        dt      r2
        bf      .Lw_fin2
.Lw_done:
        rts
        nop
        .align 1
WB_short:   .word 2000
        .align 2
LB_long:    .long 0x00400000
LB_lptr:    .long VAR_LPTR
LB_lbuf:    .long LBLBUF
LB_pend:    .long VAR_CPEND
        .ifndef STANDALONE
LB_bup:     .long VAR_BUP
LB_blist:   .long bar_list + 0xA0000000     ! uncached alias
LB_hui:     .long VAR_HUI
LB_upchunk: .long hg_upchunk
        .endif
LB_stat:    .long 0xB8000010
LB_addr:    .long 0xB8000008
LB_exec:    .long 0xB8000004
LB_buf:     .long BLITBUF
LB_list:    .long blit_list
LB_n:       .long (blit_end - blit_list) / 4
LB_c00b4:   .long 0x0C5C00B4
LB_b014:    .long 0xB8000014
LB_ae108:   .long 0x0C3AE108
LB_ret:     .long 0x0C06208C

!==================================================================
! arr_spr: replaces 0x0C07C210..0x0C07C21B, the start of the sprite routine
! (r4 = sprite def pointer, top 2 bits = flips; r7 = Y 16.16). On the How to
! Play screen shown after Start in Rosy Arrange, only the scrolling
! background, the "How to Play" banner and the blue caption panel are drawn
! (banner and panel moved HTP_DOWN px lower); everything else, including
! the Japanese captions, is skipped. arr_frame writes the button text.
!==================================================================
        .set    HTP_DOWN,   112
arr_spr:
        mov.l   LS_flag,r0          ! Rosy Arrange selected
        mov.b   @r0,r0
        tst     r0,r0
        bt      .Ls_go
        mov.l   LS_htp,r0           ! How to Play running
        mov.b   @r0,r0
        tst     r0,r0
        bt      .Ls_go
        mov.l   LS_ok,r0            ! reached from the PRESS START screen (not attract)
        mov.b   @r0,r0
        tst     r0,r0
        bt      .Ls_go
        mov.l   LS_mask,r0
        and     r4,r0
        mov.l   LS_bg0,r1
        cmp/eq  r1,r0
        bt      .Ls_go
        mov.l   LS_bg1,r1
        cmp/eq  r1,r0
        bt      .Ls_go
        mov.l   LS_ban,r1
        cmp/eq  r1,r0
        bt      .Ls_move
        mov.l   LS_pan,r1
        cmp/eq  r1,r0
        bt      .Ls_panel
        rts                         ! anything else: not drawn
        nop
.Ls_panel:                          ! the panel: also (re)write the button text
        mov.l   r2,@-r15
        mov.l   r3,@-r15
        mov.l   r5,@-r15
        mov.l   r6,@-r15
        mov.l   LS_txt,r1           ! text layer row 21, col 3
        mova    htp_text,r0
        mov     r0,r2
        mov     #9,r5               ! 9 rows
.Ls_row:
        mov     #24,r6              ! 24 columns
        mov     r1,r3
.Ls_col:
        mov.b   @r2+,r0
        extu.b  r0,r0
        mov.l   r7,@-r15
        mov.l   LS_white,r7
        or      r7,r0
        mov.l   @r15+,r7
        mov.l   r0,@r3
        dt      r6
        bf/s    .Ls_col
        add     #4,r3
        mov.w   WS_row,r0
        sub     r0,r1
        dt      r5
        bf      .Ls_row
        mov.l   LS_dirty,r1         ! rows 13..21 dirty
        mov     #1,r0
        mov     #9,r5
.Ls_dirty:
        mov.b   r0,@r1
        dt      r5
        bf/s    .Ls_dirty
        add     #1,r1
        mov.l   @r15+,r6
        mov.l   @r15+,r5
        mov.l   @r15+,r3
        mov.l   @r15+,r2
        ! the panel itself, HTP_EXT px taller: drawn as 3 slices (one-part defs
        ! cut from the panel's own VRAM image) through the sprite routine, which
        ! takes 3 more arguments from the caller's stack (copied for each call)
        mov.l   LS_down,r0
        sub     r0,r7
        sts.l   pr,@-r15
        mov.l   r5,@-r15
        mov.l   r6,@-r15
        mov.l   r7,@-r15
        mova    pan_defs,r0
        mov.l   r8,@-r15
        mov     r0,r8               ! r8 -> def, Y shift (16.16) pairs
        mov.l   r9,@-r15
        mov     #3,r9
.Ls_part:
        add     #-12,r15            ! the routine's stack arguments
        mov.l   @(36,r15),r0        ! (entry sp = r15 + 12 + 24)
        mov.l   r0,@r15
        mov.l   @(40,r15),r0
        mov.l   r0,@(4,r15)
        mov.l   @(44,r15),r0
        mov.l   r0,@(8,r15)
        mov.l   @(28,r15),r5        ! saved r5
        mov.l   @(24,r15),r6        ! saved r6
        mov.l   @(20,r15),r7        ! saved r7 (already moved down)
        mov     r8,r4               ! def
        mov.l   @(12,r8),r0
        add     r0,r7               ! Y shift for this slice
        bsr     .Ls_call
        nop
        add     #16,r8              ! next slice (r8 is kept by the routine)
        dt      r9
        bf/s    .Ls_part
        add     #12,r15
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        mov.l   @r15+,r7
        mov.l   @r15+,r6
        mov.l   @r15+,r5
        lds.l   @r15+,pr
        rts
        nop
.Ls_call:                           ! enter the sprite routine as a normal call
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   r12,@-r15
        mov.l   r13,@-r15
        mov.l   LS_ret,r0
        jmp     @r0
        nop
.Ls_move:
        mov.l   LS_down,r0
        sub     r0,r7
.Ls_go:
        .ifndef STANDALONE
        mov.l   LS_flag,r1          ! HADOUGUN (Rosy Arrange real play only):
        mov.b   @r1,r0              ! the ship and the options
        tst     r0,r0
        bt      .Ls_orig
        mov.l   LS_real,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Ls_orig
        sts     pr,r0
        mov.l   LS_pdraw,r1
        cmp/eq  r1,r0
        bt      .Ls_hg
        mova    LS_after,r0         ! drawn after the ship: if it wasn't drawn
        mov     r0,r1               ! this frame, the HADOUGUN effects go here
        sts     pr,r0
        mov     #4,r2
.Ls_af:
        mov.l   @r1+,r3
        cmp/eq  r3,r0
        bt      .Ls_fx
        dt      r2
        bf      .Ls_af
        mov.l   LS_odraw,r1
        cmp/eq  r1,r0
        bf      .Ls_orig
        mov.l   LS_hadou,r1         ! an option: not drawn with no HADOUGUN left
        mov.b   @r1,r0
        tst     r0,r0
        bf      .Ls_orig
        rts
        nop
.Ls_hg:
        mov.l   LS_hgdraw,r0
        jmp     @r0
        nop
.Ls_fx:
        sts.l   pr,@-r15
        mov.l   r4,@-r15
        mov.l   r5,@-r15
        mov.l   r6,@-r15
        mov.l   r7,@-r15
        mov.l   LS_hgfx,r0
        jsr     @r0
        nop
        mov.l   @r15+,r7
        mov.l   @r15+,r6
        mov.l   @r15+,r5
        mov.l   @r15+,r4
        bra     .Ls_orig
        lds.l   @r15+,pr
        .align 2
LS_after:   .long 0x0C08833C, 0x0C0890B6, 0x0C089744, 0x0C0838DC
LS_hgfx:    .long hg_fx
LS_pdraw:   .long 0x0C07E7E2        ! return address of the ship's sprite call
LS_odraw:   .long 0x0C0813CC        ! ... and of the options' sprite call
LS_hadou:   .long VAR_HADOU
LS_real:    .long REALPLAY
LS_hgdraw:  .long hg_pdraw
.Ls_orig:
        .endif
        mov.l   r8,@-r15            ! --- replayed original code ---
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   r12,@-r15
        mov.l   r13,@-r15
        mov.l   LS_ret,r0
        jmp     @r0
        nop
        .align 2
LS_flag:    .long VAR_FLAG
LS_htp:     .long HTPFLAG
LS_ok:      .long VAR_HTPOK
LS_txt:     .long TEXT + 21*0x80 + 3*4
LS_white:   .long 0x80808000
LS_dirty:   .long DIRTY + 13
LS_mask:    .long 0x3FFFFFFF
LS_bg0:     .long 0x0C176520        ! How to Play sprite defs: background tiles
LS_bg1:     .long 0x0C17652A
LS_ban:     .long 0x0C176534        ! "How to Play" banner
LS_pan:     .long 0x0C17653E        ! blue caption panel
LS_down:    .long HTP_DOWN << 16
LS_ret:     .long 0x0C07C21C
        .align 1
WS_row:     .word 0x80
        .align 2
        .set    HTP_EXT,    16      ! extra panel height (px)
        .set    PAN_S,      40      ! split point in the 80-px panel (from its bottom)
! slices: def (count 1; src x, src y, y offset, x offset, h-1, w-1, 0, 0),
! 2 pad bytes, Y shift (16.16). Panel image: VRAM page (0x1300,0x500) +
! (0x98,0), 80 x 224, offsets (-40,-112); y grows upward.
pan_defs:
        .word   1                   ! bottom part, moved down HTP_EXT
        .byte   0x98, 0, -40, -112, PAN_S-1, 0xDF, 0, 0
        .word   0
        .long   -(HTP_EXT << 16)
        .word   1                   ! filler: the HTP_EXT rows under the split, again
        .byte   0x98+PAN_S-HTP_EXT, 0, -40+PAN_S-HTP_EXT, -112, HTP_EXT-1, 0xDF, 0, 0
        .word   0
        .long   0
        .word   1                   ! top part, in place
        .byte   0x98+PAN_S, 0, -40+PAN_S, -112, 80-PAN_S-1, 0xDF, 0, 0
        .word   0
        .long   0
htp_text:   ! 9 rows x 24 columns, top to bottom
        .ascii "A         SLOW (NO SHOT)"
        .ascii "                        "
        .ascii "B         ROSE CRACKER  "
        .ascii "                        "
        .ascii "C         WIDE SHOT     "
        .ascii "                        "
        .ascii "A + C     FOCUS SHOT    "
        .ascii "                        "
        .ascii "D / START TYPE CHANGE   "
        .align 2

        .ifdef  STANDALONE
!==================================================================
! cred_gate (standalone; replaces 0x0C0754A0..AB of the per-player HUD loop,
! r11 = player): the idle 2P side prints no credit messages; otherwise the
! replaced code is replayed. Same as Rosy Future's gate.
!==================================================================
cred_gate:
        mov     r11,r0
        cmp/eq  #1,r0
        bf      .Lcg_go
        mov.l   LG_p2,r1
        mov.l   @r1,r0
        tst     r0,r0
        bf      .Lcg_go
        mov.l   LG_skip,r1
        jmp     @r1
        nop
.Lcg_go:
        mov.l   LG_tab,r5           ! --- replayed original code ---
        mov.w   WG_2b8,r9
        mov     r5,r0
        mov.b   @(r0,r11),r4
        mul.l   r9,r11
        mov.l   LG_p1,r0
        mov.l   LG_ret,r1
        jmp     @r1
        nop
        .align 1
WG_2b8:     .word 0x2B8
        .align 2
LG_p2:      .long P2STAT
LG_skip:    .long 0x0C07556C
LG_tab:     .long 0x0C4A2188
LG_p1:      .long P1
LG_ret:     .long 0x0C0754AC
        .endif

!------------------------------------------------------------------
! arr_rankup: replaces the game's rank-up routine 0x0C0781A0 (r4 = amount;
! rank -= r4 when rank > r4; lower rank = harder). In a real game only the
! item pickup code raises rank: the calls from 0x0C082C00..0x0C0832FF
! (score items, flowers, power-ups) and 0x0C084700..0x0C0847FF (1UP). The
! per-frame rise, kills, the cracker, speed changes etc. are ignored.
! Attract demos keep every call. Uses r0-r2 (the original used r1, r2).
!------------------------------------------------------------------
arr_rankup:
        sts     pr,r0
        mov.l   LR2_lo1,r1
        cmp/hs  r1,r0
        bf      .Lru_2
        mov.l   LR2_hi1,r1
        cmp/hs  r1,r0
        bf      .Lru_do
.Lru_2:
        mov.l   LR2_lo2,r1
        cmp/hs  r1,r0
        bf      .Lru_real
        mov.l   LR2_hi2,r1
        cmp/hs  r1,r0
        bf      .Lru_do
.Lru_real:
        mov.l   LR2_flag,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lru_do             ! not Rosy Arrange: as the game does
        mov.l   LR2_real,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lru_do             ! demo: as the game does
        rts                         ! not an item pickup: no rank change
        nop
.Lru_do:
        mov.l   LR2_rank,r2
        mov.l   @r2,r1
        cmp/hi  r4,r1
        bf      .Lru_out
        sub     r4,r1
        mov.l   r1,@r2
.Lru_out:
        rts
        nop
        .align 2
LR2_lo1:    .long 0x0C082C00
LR2_hi1:    .long 0x0C083300
LR2_lo2:    .long 0x0C084700
LR2_hi2:    .long 0x0C084800
LR2_real:   .long REALPLAY
LR2_flag:   .long VAR_FLAG
LR2_rank:   .long 0x0C453AB0

!------------------------------------------------------------------
! mode_apply: puts Rosy Arrange's direct code changes (toggle_table: the
! meter, pause, select type ...) into the program in a Rosy Arrange credit
! game and takes them out otherwise (other modes, attract demos). Writes go
! through the cached addresses (the SH7709S cache is unified, so the CPU sees
! them as code at once). Only acts when the wanted state changes.
! Called from title_menu5 (r4 = 1: on as soon as ROSY'S ARRANGE is picked)
! and arr_frame (r4 = 0: only in a credit game, so attract demos run unchanged). Uses r0-r7.
!------------------------------------------------------------------
mode_apply:
        mov     #0,r2
        mov.l   LMA_flag,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lma_want
        tst     r4,r4               ! r4 = 1: PRESS START screen (a credit game is starting)
        bf      .Lma_on
        mov.l   LMA_real,r1
        mov.b   @r1,r0
        tst     r0,r0
        bf      .Lma_on
        mov.l   LMA_htpok,r1        ! How to Play / character select of a credit game
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lma_want
.Lma_on:
        mov     #1,r2
.Lma_want:
        mov.l   LMA_cur,r1
        mov.b   @r1,r0
        cmp/eq  r2,r0
        bt      .Lma_out
        mov.b   r2,@r1
        mova    toggle_table,r0
        mov     r0,r3
.Lma_ent:
        mov.l   @r3+,r4             ! address (0 ends)
        tst     r4,r4
        bt      .Lma_out
        mov.l   @r3+,r5             ! length
        mov     r5,r1
        mov     r3,r6               ! original bytes
        mov     r3,r7
        add     r5,r7               ! Rosy Arrange bytes
        tst     r2,r2
        bt      .Lma_copy
        mov     r7,r6
.Lma_copy:
        mov.b   @r6+,r0
        mov.b   r0,@r4
        dt      r5
        bf/s    .Lma_copy
        add     #1,r4
        mov     r7,r3
        add     r1,r3               ! past the Rosy Arrange bytes, realigned
        add     #3,r3
        mov     #-4,r0
        bra     .Lma_ent
        and     r0,r3
.Lma_out:
        rts
        nop
        .align 2
LMA_flag:   .long VAR_FLAG
LMA_real:   .long REALPLAY
LMA_cur:    .long VAR_MODEAPP
LMA_htpok:  .long VAR_HTPOK

        .include "toggle_table.inc"

!------------------------------------------------------------------
! tick_hook: the game's graze routine adds a 10-point tick-point at
! 0x0C076CC4 (score += 10). That spot now branches (via a jump in dead
! padding at 0x0C076694) here: replay the score store and the next load,
! count the tick, return to 0x0C076CCA. Keeps every register but r10/pr
! (r10 is reloaded here, the routine saves pr).
!------------------------------------------------------------------
tick_hook:
        mov.l   r5,@(28,r13)        ! --- replayed: score store ---
        mov.l   r0,@-r15
        mov.l   r1,@-r15
        mov.l   LT_ticks,r1
        mov.l   @r1,r0
        add     #1,r0
        mov.l   r0,@r1
        mov.l   LT_ret,r0
        lds     r0,pr
        mov.l   @r15+,r1
        mov.l   @r15+,r0
        rts
        mov.b   @r8,r10             ! --- replayed: next load ---
        .align 2
LT_ticks:   .long VAR_TICKS
LT_ret:     .long 0x0C076CCA

!------------------------------------------------------------------
! tick_hook2: bullet grazes (the shield or ship brushing an enemy bullet,
! routine 0x0C076E60) add their own 10-point tick-point at 0x0C07701E.
! That spot now branches (bra + jump in dead padding at 0x0C076F68, with
! the add #10 kept in the delay slot) here: replay the score store and
! the next load, count the tick, jump back to 0x0C077024. Uses r6 only,
! which the game reloads at 0x0C077028 before reading it.
!------------------------------------------------------------------
tick_hook2:
        mov.l   r11,@(28,r8)        ! --- replayed: score store ---
        mov.l   LT_ticks2,r6
        mov.l   @r6,r7
        add     #1,r7
        mov.l   r7,@r6
        mov.l   @(40,r14),r7        ! --- replayed: next load ---
        mov.l   LT_ret2,r6
        jmp     @r6
        nop
        .align 2
LT_ticks2:  .long VAR_TICKS
LT_ret2:    .long 0x0C077024

!------------------------------------------------------------------
! meter_tick (arr_frame): the rose cracker meter (P1 +0x286, 0..128) no
! longer fills by itself (patched in the game's charge routine) and shots
! no longer empty it; each tick-point adds 2 instead. A full meter shown
! as 127 to a shot (arr_input) is put back to 128. If the meter is empty
! the shield is spawned first (the game's own 0 -> 1 step). Reaching 128
! plays the game's "full" voice. Real play only.
!------------------------------------------------------------------
        .set    TICK_STEP,  2
meter_tick:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   LM_p1,r8
        mov.w   WM_286,r0
        add     r8,r0
        mov     r0,r9               ! r9 -> charge
        mov.l   LM_hide,r1          ! restore a full meter hidden from a shot
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lmt_nohide
        mov     #0,r0
        mov.b   r0,@r1
        mov.b   @r9,r0
        cmp/eq  #127,r0
        bf      .Lmt_nohide
        mov.w   WM_80,r0
        mov.b   r0,@r9
.Lmt_nohide:
        mov.l   LM_cool,r10         ! cooldown: held at full while any cracker
        bsr     crk_mask            ! piece is out, then counts down, so B works
        nop                         ! again 2 s after the cracker has finished
        tst     r0,r0
        bt      .Lmt_c0
        mov.w   LM_cooln,r0
        bra     .Lmt_c1
        mov.b   r0,@r10
.Lmt_c0:
        mov.b   @r10,r0
        tst     r0,r0
        bt      .Lmt_c1
        add     #-1,r0
        mov.b   r0,@r10
.Lmt_c1:
        mov.l   LM_weak,r10         ! weak rose cracker: shorten every new cracker
        mov.b   @r10,r0             ! piece for a few frames
        tst     r0,r0
        bt      .Lmt_noweak
        bsr     crk_mask
        nop
        mov.w   @(2,r10),r0
        extu.w  r0,r0
        not     r0,r3
        and     r2,r3               ! r3 = new pieces
        mov     r2,r0
        mov.w   r0,@(2,r10)
        mov.b   @r10,r0
        cmp/eq  #12,r0
        bf      .Lmt_wcut
        tst     r3,r3               ! first frame and nothing fired: put the meter back
        bf      .Lmt_wcut
        mov.b   @(1,r10),r0
        mov.b   r0,@r9
        bra     .Lmt_wend
        mov     #0,r0
.Lmt_wcut:
        mov.l   LM_crk,r1
        mov     #91,r2
        add     r2,r1               ! r1 -> slot 0 +91 (loops left)
        mov     #1,r2
.Lmt_wloop:
        tst     r3,r3
        bt      .Lmt_wdone
        shlr    r3
        bf      .Lmt_wnext
        mov.b   r2,@r1              ! one loop: the shortest cracker
.Lmt_wnext:
        bra     .Lmt_wloop
        add     #96,r1
.Lmt_wdone:
        mov.b   @r10,r0
        add     #-1,r0
.Lmt_wend:
        mov.b   r0,@r10
.Lmt_noweak:
        mov.l   LM_hold,r1          ! rose cracker hold: count down
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lmt_nohold
        add     #-1,r0
        mov.b   r0,@r1
.Lmt_nohold:
        mov.l   LM_start,r1         ! first live frame of a new game: full meter
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lmt_nostart
        mov.l   LM_real,r0
        mov.b   @r0,r0
        tst     r0,r0
        bt      .Lmt_nostart
        mov.w   @r8,r0
        mov.w   WM_alive,r2
        cmp/eq  r2,r0
        bf      .Lmt_nostart
        mov.b   @r9,r0
        tst     r0,r0
        bf      .Lmt_full
        mov.l   LM_shield,r0        ! the shield first (the game's 0 -> 1 step)
        jsr     @r0
        mov     #0,r4
        tst     r0,r0
        bt      .Lmt_nostart        ! not possible yet: next frame
.Lmt_full:
        mov.l   LM_start,r1
        mov     #0,r0
        mov.b   r0,@r1
        mov.w   WM_80,r0
        mov.b   r0,@r9
        mov.l   @(4,r8),r0
        mov.l   LM_redraw,r3
        or      r3,r0
        mov.l   r0,@(4,r8)
.Lmt_nostart:
        mov.l   LM_ticks,r1
        mov.l   @r1,r10             ! r10 = ticks
        tst     r10,r10
        bt      .Lmt_out
        mov.l   LM_real,r0
        mov.b   @r0,r0
        tst     r0,r0
        bt      .Lmt_drop           ! demo: ignore
        mov.w   @r8,r0              ! ship alive?
        mov.w   WM_alive,r2
        cmp/eq  r2,r0
        bf      .Lmt_out            ! keep them for later
        mov.b   @r9,r0
        tst     r0,r0
        bf      .Lmt_add
        mov.l   LM_hold,r1          ! empty and the cracker still out: keep them
        mov.b   @r1,r0
        tst     r0,r0
        bf      .Lmt_out
        mov.l   LM_shield,r0        ! empty: spawn the shield first
        jsr     @r0
        mov     #0,r4
        tst     r0,r0
        bt      .Lmt_out            ! not possible now: try next frame
.Lmt_add:
        mov.b   @r9,r0
        extu.b  r0,r1               ! r1 = old charge
        mov     r10,r2
        shll    r2                  ! TICK_STEP = 2
        add     r1,r2
        mov.w   WM_80,r0
        cmp/hi  r0,r2
        bf      .Lmt_cap
        mov     r0,r2
.Lmt_cap:
        mov.b   r2,@r9
        mov.l   @(4,r8),r0          ! the gauge redraws
        mov.l   LM_redraw,r3
        or      r3,r0
        mov.l   r0,@(4,r8)
        mov.w   WM_80,r0
        cmp/eq  r0,r2
        bf      .Lmt_drop
        cmp/eq  r0,r1
        bt      .Lmt_drop
        mov.l   @(8,r8),r0          ! just filled: the game's "full" voice
        shlr2   r0                  ! (as 0x0C07AB30: id = 0x0C10877B[char x 30])
        mov     #30,r1
        mul.l   r1,r0
        sts     macl,r0
        mov.l   LM_vtab,r1
        mov.b   @(r0,r1),r10
        extu.b  r10,r10
        mov     #0,r4
        mov.l   LM_voice,r0
        jsr     @r0
        mov     r10,r5
        mov.l   LM_se,r0
        jsr     @r0
        mov     r10,r4
.Lmt_drop:
        mov.l   LM_ticks,r1
        mov     #0,r0
        mov.l   r0,@r1
.Lmt_out:
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 1
WM_286:     .word 0x286
WM_80:      .word 0x80
WM_alive:   .word 0xCE00
LM_cooln:   .word COOLDOWN
        .align 2
LM_p1:      .long P1
LM_hide:    .long VAR_HIDE
LM_start:   .long VAR_START
LM_hold:    .long VAR_CRKHOLD
LM_weak:    .long VAR_WEAK
LM_cool:    .long VAR_COOL
LM_crk:     .long 0x0C3AD500
LM_ticks:   .long VAR_TICKS
LM_real:    .long REALPLAY
LM_shield:  .long 0x0C0981F0
LM_redraw:  .long 0x40000000
LM_vtab:    .long 0x0C10877B
LM_voice:   .long 0x0C08AFE0
LM_se:      .long 0x0C08B050

!------------------------------------------------------------------
! crk_mask: r0 = r2 = bitmask of P1's 16 rose cracker slots (0x0C3AD500,
! stride 96) holding a cracker piece (word 0 = 0xCC10xxxx). Uses r0-r3.
!------------------------------------------------------------------
crk_mask:
        mov.l   LK_crk,r1
        mov     #0,r2
        mov     #1,r3
.Lk_loop:
        mov.b   @r1,r0
        cmp/eq  #-52,r0             ! 0xCC
        bf      .Lk_next
        mov.b   @(1,r1),r0
        cmp/eq  #16,r0              ! 0x10
        bf      .Lk_next
        or      r3,r2
.Lk_next:
        shll    r3
        mov     #96,r0
        extu.b  r0,r0
        add     r0,r1
        mov.l   LK_end,r0
        cmp/eq  r0,r3
        bf      .Lk_loop
        rts
        mov     r2,r0
        .align 2
LK_crk:     .long 0x0C3AD500
LK_end:     .long 0x00010000

!------------------------------------------------------------------
! magnet (arr_frame, Rosy Arrange play): once button A has been held for
! MAGNET_AT frames (with or without other buttons), every cracker flower
! (item +104 = FLOWERMARK, active, state 2) moves up to MAGNET_STEP a frame
! on each axis toward the ship, which then collects it as usual. Uses r0-r7.
!------------------------------------------------------------------
magnet:
        .ifndef STANDALONE
        sts.l   pr,@-r15
        mov.l   LGM_hud,r0
        jsr     @r0
        nop
        mov.l   LGM_hg,r0
        jsr     @r0
        nop
        lds.l   @r15+,pr
        .endif
        mov.l   LGM_fsnd,r1         ! the louder-pickup window counts down
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lg_nf
        add     #-1,r0
        mov.b   r0,@r1
.Lg_nf:
        rts                         ! flower pull switched off (2026-10-29)
        nop
        mov.l   LGM_hold,r1
        mov.b   @r1,r0
        extu.b  r0,r0
        mov     #MAGNET_AT,r1
        cmp/hs  r1,r0
        bf      .Lg_out
        mov.l   LGM_p1,r1
        mov.w   @r1,r0
        mov.w   WGM_alive,r2
        cmp/eq  r2,r0
        bf      .Lg_out
        mov.l   @(24,r1),r6         ! ship Y
        mov.l   @(28,r1),r7         ! ship X
        mov.l   LGM_items,r2
        mov.w   WGM_n,r3
        mov.l   LGM_step,r5
        sts.l   pr,@-r15
.Lg_item:
        mov     #104,r0
        mov.b   @(r0,r2),r0
        cmp/eq  #FLOWERMARK-256,r0
        bf      .Lg_next
        mov.l   @(4,r2),r0
        cmp/eq  #2,r0
        bf      .Lg_next
        mov.l   @r2,r0
        cmp/pz  r0
        bt      .Lg_next            ! not active
        mov.l   @(44,r2),r0         ! Y
        mov     r6,r4
        bsr     .Lg_step1
        sub     r0,r4
        mov.l   r0,@(44,r2)
        mov.l   @(48,r2),r0         ! X
        mov     r7,r4
        bsr     .Lg_step1
        sub     r0,r4
        mov.l   r0,@(48,r2)
.Lg_next:
        add     #108,r2
        dt      r3
        bf      .Lg_item
        lds.l   @r15+,pr
.Lg_out:
        rts
        nop
.Lg_step1:                          ! r0 += clamp(r4, -r5, r5); uses r1
        cmp/gt  r5,r4
        bf      .Lg_s1
        mov     r5,r4
.Lg_s1:
        neg     r5,r1
        cmp/ge  r1,r4
        bt      .Lg_s2
        mov     r1,r4
.Lg_s2:
        rts
        add     r4,r0
        .align 1
WGM_alive:   .word 0xCE00
WGM_n:       .word 356
        .align 2
LGM_hold:    .long VAR_AHOLD
LGM_p1:      .long P1
LGM_items:   .long 0x0C5B68EC
LGM_step:    .long MAGNET_STEP
LGM_fsnd:    .long VAR_FLWSND
        .ifndef STANDALONE
LGM_hud:     .long hadou_hud
LGM_hg:      .long hg_logic
        .endif

!------------------------------------------------------------------
! snd_hook (Pink Sweets Forever): the sound driver starts a channel through
! the literal at 0x0C05FB24 (0x0C0602F8: r4 channel, r5 phrase, r6 volume),
! which now points here. While a cracker flower's pickup is pending
! (VAR_FLWSND), the score-item pickup phrase plays at 1.5 x its volume.
! Uses r0, r1.
!------------------------------------------------------------------
snd_hook:
        mov     r5,r0
        cmp/eq  #FLW_PHRASE,r0
        bf      .Lsh_go
        mov.l   LSH_fsnd,r1
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lsh_go
        mov     r6,r0
        shlr    r0
        add     r0,r6               ! volume x 1.5
.Lsh_go:
        mov.l   LSH_play,r0
        jmp     @r0
        nop
        .align 2
LSH_fsnd:   .long VAR_FLWSND
LSH_play:   .long 0x0C0602F8

!------------------------------------------------------------------
! ext_hook (Pink Sweets Forever): the game's score extend (0x0C07AF1E: the
! score reached P1 +0x29C, the next one is already set from the DIP) would
! add a life at 0x0C07AF50 when lives < 5. 0x0C07AF30 now branches (through
! padding at 0x0C07AF42) here with r0 = 0x27B, r3 = P1, r6 = 4. In Rosy
! Arrange play a lipstick 1UP is queued instead (arr_oneup drops it from the
! top of the screen; picked up at 5 lives it gives its score bonus); other
! modes keep the game's behaviour. Uses r1, r2, r5.
!------------------------------------------------------------------
ext_hook:
        mov.b   @(r0,r3),r2         ! --- replayed: lives ---
        mov.l   LE_flag,r1
        mov.b   @r1,r1
        tst     r1,r1
        bt      .Le_game
        mov.l   LE_real,r1
        mov.b   @r1,r1
        tst     r1,r1
        bt      .Le_game
        mov.l   LE_pend,r1          ! Rosy Arrange: one more lipstick to drop
        mov.b   @r1,r5
        add     #1,r5
        mov.b   r5,@r1
        bra     .Le_skip
        nop
.Le_game:
        cmp/hi  r6,r2               ! --- replayed: 5 lives already? ---
        bf      .Le_life
.Le_skip:
        mov.l   LE_skip,r1
        jmp     @r1
        nop
.Le_life:
        mov.l   LE_life,r1
        jmp     @r1
        nop
        .align 2
LE_flag:    .long VAR_FLAG
LE_real:    .long REALPLAY
LE_pend:    .long VAR_PEND
LE_skip:    .long 0x0C07AF38
LE_life:    .long 0x0C07AF50

!------------------------------------------------------------------
! kmul: r0 = the chain's kill multiplier, VAR_KILLS but at least 1. Uses r0, r1.
!------------------------------------------------------------------
kmul:
        mov.l   LF_kills,r1
        mov.l   @r1,r0
        tst     r0,r0
        bf      .Lkm_out
        mov     #1,r0
.Lkm_out:
        rts
        nop
        .align 2
LF_kills:   .long VAR_KILLS

!------------------------------------------------------------------
! fifo_push (arr_collect, r10 = multiplier - 1): adds the pickup to the
! chain list (10 lines; the oldest drops off): chain in VAR_FIFO, kill
! multiplier in VAR_KFIFO. Uses r0-r3.
!------------------------------------------------------------------
fifo_push:
        sts.l   pr,@-r15
        mov.l   r4,@-r15
        mov.l   r5,@-r15
        bsr     kmul
        nop
        mov     r0,r5               ! r5 = kill multiplier
        mov     r10,r3
        add     #1,r3               ! r3 = chain
        mov.l   LF_fifo,r1
        mov.l   LF_cnt,r2
        mov.b   @r2,r0
        extu.b  r0,r0
        cmp/eq  #10,r0
        bf      .Lff_room
        mov     #9,r4               ! full: shift the 9 newest up (both lists)
.Lff_shift:
        mov.l   @(4,r1),r2
        mov.l   r2,@r1
        mov     #0x44,r0
        mov.l   @(r0,r1),r2
        mov     #0x40,r0
        mov.l   r2,@(r0,r1)
        dt      r4
        bf/s    .Lff_shift
        add     #4,r1
        bra     .Lff_put            ! newest in slot 9
        nop
.Lff_room:
        mov     r0,r2
        shll2   r2
        add     r2,r1
        add     #1,r0
        mov.l   LF_cnt,r2
        mov.b   r0,@r2
.Lff_put:
        mov.l   r3,@r1
        mov     #0x40,r0
        mov.l   r5,@(r0,r1)
        mov.l   LF_cnt,r2
        mov     #1,r0
        mov.b   r0,@(1,r2)          ! VAR_FDIRTY
        mov.l   @r15+,r5
        mov.l   @r15+,r4
        lds.l   @r15+,pr
        rts
        nop
        .align 2
LF_fifo:    .long VAR_FIFO
LF_cnt:     .long VAR_FCOUNT

!==================================================================
! chain_txt (arr_frame, Rosy Arrange play, P1 playing): the chain list as
! plain gold text on the text layer, rows CHAIN_ROW down to CHAIN_ROW-9,
! cols 0..10: one "+<points>" line per pickup, oldest at the top, newest at
! the bottom. Cleared 1 second after the last pickup (VAR_CTIME > 60).
! Only rewritten when it changes. Uses r0-r7.
!==================================================================
chain_txt:
        mov.l   LC_cnt,r6
        mov.l   LC_ctime,r1
        mov.b   @r1,r0
        extu.b  r0,r0
        mov     #60,r3
        cmp/hi  r3,r0
        bf      .Lt_live
        mov.b   @r6,r0              ! chain over: empty the list
        tst     r0,r0
        bt      .Lt_live
        mov     #0,r0
        mov.b   r0,@r6
        mov.l   LC_kills,r1         ! and the kill multiplier starts again
        mov.l   r0,@r1
        mov     #1,r0
        mov.b   r0,@(1,r6)
.Lt_live:
        mov.b   @(1,r6),r0
        tst     r0,r0
        bt      .Lt_out             ! unchanged
        mov     #0,r0
        mov.b   r0,@(1,r6)
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   LC_cell,r8          ! r8 -> row CHAIN_ROW, col 0
        mov.l   LC_fifo,r9
        mov     #0,r7               ! r7 = line
.Lt_line:
        mov     r8,r1               ! clear cols 0..13
        mov.l   LC_blank,r0
        mov     #14,r3
.Lt_clr:
        mov.l   r0,@r1
        dt      r3
        bf/s    .Lt_clr
        add     #4,r1
        mov.b   @r6,r0
        extu.b  r0,r0
        cmp/hi  r7,r0
        bf      .Lt_next            ! no entry for this line
        mov     r8,r1
        mov.l   LC_attr,r0
        add     #0x2B,r0            ! '+'
        mov.l   r0,@r1
        add     #4,r1
        mov.l   @r9,r2              ! chain
        mov.w   WC_1000,r0
        mul.l   r0,r2
        sts     macl,r2             ! points
        bsr     txt_num
        nop
        mov     #0x40,r0
        mov.l   @(r0,r9),r2         ! kill multiplier (VAR_KFIFO)
        mov     r2,r0
        cmp/eq  #1,r0
        bt      .Lt_next            ! x1: no tag
        mov.l   LC_attr,r0          ! "x<kills>" right after the points
        add     #0x78,r0
        mov.l   r0,@r1
        add     #4,r1
        bsr     txt_num
        nop
.Lt_next:
        add     #4,r9
        mov.w   WC_row,r0
        sub     r0,r8               ! next row down the screen
        add     #1,r7
        mov     r7,r0
        cmp/eq  #10,r0
        bf      .Lt_line
        mov.l   LC_dirty,r1         ! rows CHAIN_ROW-9 .. CHAIN_ROW
        mov     #1,r0
        mov     #10,r3
.Lt_d:
        mov.b   r0,@r1
        dt      r3
        bf/s    .Lt_d
        add     #1,r1
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
.Lt_out:
        rts
        nop

! txt_num: r2 value (> 0), r1 -> first cell; left aligned gold digits.
! Uses r0 r2 r3 r4 r5; keeps r6-r9.
txt_num:
        mova    lc_pow,r0
        mov     r0,r5
        mov     #0,r4               ! 1 once a digit is out
.Lnm_pow:
        mov.l   @r5+,r3
        tst     r3,r3
        bt      .Lnm_out
        mov     #0x30,r0
.Lnm_sub:
        cmp/hs  r3,r2
        bf      .Lnm_dig
        sub     r3,r2
        bra     .Lnm_sub
        add     #1,r0
.Lnm_dig:
        cmp/eq  #0x30,r0
        bf      .Lnm_put
        tst     r4,r4
        bf      .Lnm_put
        mov.l   @r5,r3              ! leading zero, not the last digit
        tst     r3,r3
        bf      .Lnm_pow
.Lnm_put:
        mov     #1,r4
        mov.l   LC_attr,r3
        or      r3,r0
        mov.l   r0,@r1
        bra     .Lnm_pow
        add     #4,r1
.Lnm_out:
        rts
        nop
        .align 1
WC_row:     .word 0x80
WC_1000:    .word 100
        .align 2
lc_pow:     .long 1000000000, 100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1, 0
LC_cnt:     .long VAR_FCOUNT
LC_fifo:    .long VAR_FIFO
LC_ctime:   .long VAR_CTIME
LC_cell:    .long TEXT + CHAIN_ROW*0x80
LC_blank:   .long 0x80808020
LC_attr:    .long 0xC0B04000        ! gold
LC_kills:   .long VAR_KILLS
LC_dirty:   .long DIRTY + CHAIN_ROW - 9

!==================================================================
! ext_rank (arr_frame, Rosy Arrange play): when P1's lives go up (a lipstick
! 1UP picked up), rank = last frame's rank - 0.1 x 2^24 (RANK +10 points in
! total, including the game's own small rise), not below 0. Uses r0-r3.
!==================================================================
ext_rank:
        mov.l   LX_p1,r1
        mov.w   WX_lives,r0
        mov.b   @(r0,r1),r2
        extu.b  r2,r2
        add     #1,r2               ! r2 = lives + 1
        mov.l   LX_plives,r3
        mov.b   @r3,r0
        extu.b  r0,r0
        mov.b   r2,@r3
        tst     r0,r0
        bt      .Lx_save            ! first frame: nothing to compare
        add     #1,r0
        cmp/eq  r0,r2               ! exactly one more life (a continue gives more)
        bf      .Lx_save
        mov.l   LX_prank,r3         ! extra life: RANK +3 from last frame
        mov.l   @r3,r0
        mov.l   LX_ten,r2
        cmp/hs  r2,r0
        bt/s    .Lx_set
        sub     r2,r0
        mov     #0,r0
.Lx_set:
        mov.l   LX_rank,r1
        mov.l   r0,@r1
.Lx_save:
        mov.l   LX_rank,r1
        mov.l   @r1,r0
        mov.l   LX_prank,r3
        rts
        mov.l   r0,@r3
        .align 1
WX_lives:   .word 0x27B
        .align 2
LX_p1:      .long P1
LX_plives:  .long VAR_PLIVES
LX_prank:   .long VAR_PRANK
LX_rank:    .long 0x0C453AB0
        .ifdef  STANDALONE
LX_ten:     .long 503316            ! 0.03 x 2^24 = RANK +3
        .else
LX_ten:     .long 838861            ! 0.05 x 2^24 = RANK +5 per extra life
        .endif

!==================================================================
! boss_scan (arr_frame, Rosy Arrange play): VAR_BOSS = 1 while any enemy
! object (0x0C416968, 192 x 0xCC) with HP left matches an entry of the
! Rosy Future boss timer table (type +4, sub-id +8 in the entry's mask),
! i.e. a boss or midboss that has a timer. Uses r0-r7.
!==================================================================
boss_scan:
        mov     #0,r6
        mov.l   LB_bobj,r0
        mov.l   r6,@r0
        mov.l   LB_objs,r1
        mov.w   WB_count,r2
.Lb_obj:
        mov.l   @r1,r0
        tst     r0,r0
        bt      .Lb_next
        mov.w   WB_hp,r0
        mov.w   @(r0,r1),r0
        extu.w  r0,r0
        tst     r0,r0
        bt      .Lb_next
        mov.l   @(4,r1),r4          ! type
        mov.l   @(8,r1),r5          ! sub-id
        mov.l   LB_tab,r3
.Lb_ent:
        mov.w   @r3,r0
        extu.w  r0,r0
        mov.w   WB_end,r7
        extu.w  r7,r7
        cmp/eq  r7,r0
        bt      .Lb_next
        cmp/eq  r4,r0
        bf      .Lb_ent2
        mov     #15,r0
        cmp/hi  r0,r5
        bt      .Lb_ent2
        mov     #1,r7
        shld    r5,r7
        mov.w   @(2,r3),r0
        tst     r7,r0
        bf      .Lb_found
.Lb_ent2:
        bra     .Lb_ent
        add     #22,r3
.Lb_found:
        mov.l   LB_bobj,r0
        mov.l   r1,@r0
        mov.l   r3,@(4,r0)          ! VAR_BENT
        mov     r4,r6
        bra     .Lb_out
        add     #1,r6               ! type + 1
.Lb_next:
        mov.w   WB_size,r0
        dt      r2
        bf/s    .Lb_obj
        add     r0,r1
.Lb_out:
        mov.l   LB_boss,r1
        rts
        mov.l   r6,@r1
        .align 1
WB_count:   .word 192
WB_hp:      .word 0x44
WB_end:     .word 0xFFFF
WB_size:    .word 0xCC
        .align 2
LB_objs:    .long 0x0C416968
        .ifdef  STANDALONE
LB_tab:     .long boss_tab
boss_tab:   ! Rosy Future's boss/midboss timer table (type, sub-id mask, ...), 22-byte entries
        .word 61, 1, 0, 36368, 3600, 0, 0, 0, 0, 0, 0
        .word 57, 2, 0, 36368, 3600, 38168, 5400, 0, 0, 0, 0
        .word 64, 1, 0, 36368, 3600, 0, 0, 0, 0, 0, 0
        .word 69, 1, 0, 36368, 3600, 0, 0, 0, 0, 0, 0
        .word 44, 1, 0, 39968, 7200, 43568, 10800, 0, 0, 0, 0
        .word 63, 1, 0, 39968, 7200, 7200, 0, 0, 0, 0, 0
        .word 39, 1, 0, 36368, 3600, 39968, 7200, 43568, 10800, 0, 0
        .word 62, 1, 0, 36368, 3600, 0, 0, 0, 0, 0, 0
        .word 37, 1, 0, 39968, 7200, 0, 0, 0, 0, 0, 0
        .word 42, 1, 0, 38168, 5400, 39968, 7200, 0, 0, 0, 0
        .word 65, 1, 0, 36368, 3600, 0, 0, 0, 0, 0, 0
        .word 84, 1, 1, 40868, 8100, 39968, 7200, 0, 0, 0, 0
        .word 41, 2, 0, 36368, 3600, 0, 0, 0, 0, 0, 0
        .word 72, 1, 0, 39968, 7200, 0, 0, 0, 0, 0, 0
        .word 66, 1, 0, 43568, 10800, 0, 0, 0, 0, 0, 0
        .word 2, 1, 0, 36368, 3600, 39968, 7200, 43568, 10800, 0, 0
        .word 67, 1, 0, 43568, 10800, 0, 0, 0, 0, 0, 0
        .word 36, 7, 0, 39968, 7200, 43568, 10800, 0, 0, 0, 0
        .word 36, 16, 0, 0, 10800, 0, 0, 0, 0, 0, 0
        .word 0xFFFF
        .align 2
        .else
LB_tab:     .long BOSSTAB
        .endif
LB_boss:    .long VAR_BOSS
LB_bobj:    .long VAR_BOBJ

!==================================================================
! boss_hud (standalone; arr_frame after boss_scan): the boss/midboss timer
! "sss.t" on row 37 (cols 25-29) and its HP on row 36 (cols 26-29), right
! side, as Rosy Future's HUD shows them; blank when there is no timed boss.
! Timer = entry limit for the phase (+0xB8) minus the phase frames (+0xA0
! u32, or +0x58 u16 when the entry's flag word is set); a limit with bit 15
! set is shown as is. Uses r0-r7.
!==================================================================
boss_hud:
        sts.l   pr,@-r15
        mov.l   LH_bobj,r1
        mov.l   @r1,r2              ! r2 = object
        tst     r2,r2
        bt      .Lh_blank
        mov.l   @(4,r1),r3          ! r3 = entry
        mov.w   WH_b8,r0
        mov.b   @(r0,r2),r4
        extu.b  r4,r4               ! phase
        mov     #7,r0
        cmp/hi  r0,r4
        bt      .Lh_blank
        mov.w   @(4,r3),r0
        tst     r0,r0
        bf      .Lh_w58
        mov.w   WH_a0,r0
        bra     .Lh_el
        mov.l   @(r0,r2),r5
.Lh_w58:
        mov.w   WH_58,r0
        mov.w   @(r0,r2),r5
        extu.w  r5,r5
.Lh_el:
        add     r4,r4
        add     r3,r4
        mov.w   @(6,r4),r0
        extu.w  r0,r6               ! limit
        tst     r6,r6
        bt      .Lh_blank
        mov.w   WH_8000,r0
        extu.w  r0,r0
        tst     r0,r6
        bt      .Lh_sub
        bra     .Lh_pos
        xor     r0,r6               ! continuous: shown as is
.Lh_sub:
        sub     r5,r6
.Lh_pos:
        cmp/pz  r6
        bt      .Lh_t
        mov     #0,r6
.Lh_t:
        mov.w   WH_2aab,r0          ! frames / 6 = tenths of a second
        extu.w  r0,r0
        mul.l   r0,r6
        sts     macl,r6
        shlr16  r6
        .ifndef STANDALONE
        mov.l   LH_draw2,r0
        jmp     @r0
        nop
        .endif
        mov.l   LH_row37,r1         ! row 37, cols 19..24 blank
        mov.l   LH_blank,r0
        mov     #6,r7
.Lh_b1:
        mov.l   r0,@r1
        dt      r7
        bf/s    .Lh_b1
        add     #4,r1
        mov     r6,r4
        mova    hpow3,r0
        bsr     h_digits            ! seconds: 3 digits
        mov     #3,r7
        mov.l   LH_white,r0
        add     #0x2E,r0
        mov.l   r0,@r1              ! '.'
        add     #4,r1
        mov.l   LH_white,r0
        add     #0x30,r0
        add     r4,r0               ! tenths
        mov.l   r0,@r1
        mov.l   LH_row36,r1         ! row 36, cols 19..25 blank, HP at 26..29
        mov.l   LH_blank,r0
        mov     #7,r7
.Lh_b2:
        mov.l   r0,@r1
        dt      r7
        bf/s    .Lh_b2
        add     #4,r1
        mov.w   WH_44,r0
        mov.w   @(r0,r2),r4
        extu.w  r4,r4
        mova    hpow4,r0
        bsr     h_digits
        mov     #4,r7
        bra     .Lh_dirty
        nop
.Lh_blank:
        .ifndef STANDALONE
        mov.l   LH_blank2,r0
        jmp     @r0
        nop
        .endif
        mov.l   LH_row37,r1
        mov.l   LH_row36,r2
        mov.l   LH_blank,r0
        mov     #11,r7
.Lh_b3:
        mov.l   r0,@r1
        mov.l   r0,@r2
        add     #4,r1
        dt      r7
        bf/s    .Lh_b3
        add     #4,r2
.Lh_dirty:
        mov.l   LH_dirty,r1
        mov     #1,r0
        mov.b   r0,@r1
        mov.b   r0,@(1,r1)
        lds.l   @r15+,pr
        rts
        nop

! h_digits: r4 value, r0 -> powers of ten (words), r7 count, r1 -> cells.
! Leading zeros blank, the last digit always shown. Leaves r4 = remainder,
! r1 past the field. Uses r0 r3 r5 r6 (r6 saved).
h_digits:
        mov.l   r6,@-r15
        mov     r0,r5
        mov     #0,r6               ! 1 once a digit has been shown
.Lhd_dig:
        mov.w   @r5+,r0
        extu.w  r0,r0
        mov     #0,r3
.Lhd_sub:
        cmp/hs  r0,r4
        bf      .Lhd_put
        sub     r0,r4
        bra     .Lhd_sub
        add     #1,r3
.Lhd_put:
        tst     r3,r3
        bf      .Lhd_show
        tst     r6,r6
        bf      .Lhd_show
        mov     r7,r0
        cmp/eq  #1,r0
        bt      .Lhd_show
        mov.l   LH_blank,r0
        bra     .Lhd_store
        nop
.Lhd_show:
        mov     #1,r6
        mov.l   LH_white,r0
        add     #0x30,r0
        add     r3,r0
.Lhd_store:
        mov.l   r0,@r1
        dt      r7
        bf/s    .Lhd_dig
        add     #4,r1
        rts
        mov.l   @r15+,r6
        .align 2
hpow4:      .word 1000, 100, 10, 1
hpow3:      .word 1000, 100, 10
WH_b8:      .word 0xB8
WH_a0:      .word 0xA0
WH_58:      .word 0x58
WH_44:      .word 0x44
WH_8000:    .word 0x8000
WH_2aab:    .word 0x2AAB
        .align 2
LH_bobj:    .long VAR_BOBJ
LH_row37:   .long TEXT + 37*0x80 + 19*4
LH_row36:   .long TEXT + 36*0x80 + 19*4
LH_blank:   .long 0x80808020
LH_white:   .long 0x80808000
LH_dirty:   .long DIRTY + 36
        .ifndef STANDALONE
LH_draw2:   .long bhud2_draw
LH_blank2:  .long bhud2_blank
        .endif

        .ifndef STANDALONE
!==================================================================
! bhud2 (combined, Rosy's Arrange; boss_hud jumps here with pr saved on the
! stack): Rosy Future's timer and HP on the right (rows 37/36, cols 19..29)
! are blanked; the timer "sss.t" goes under the RANK value (row 38, cols
! 25..29) and the health is a bar under it (row 37, cols 21..29: 9 cells,
! 70 px of fill between a white outline, see build.py bar_inc). The bar is
! the health against the highest health seen for this object (start of the
! fight or of a phase): green above 30, yellow 16..30, red 15 and below.
! r2 = object, r6 = tenths of a second. Uses r0-r7.
!==================================================================
bhud2_draw:
        bsr     bhud2_clear
        nop
        mov.l   LH2_row36,r1        ! timer
        mov     r6,r4
        mov.l   LH2_pow3,r0
        bsr     h_digits
        mov     #3,r7
        mov.l   LH2_white,r0
        add     #0x2E,r0
        mov.l   r0,@r1              ! '.'
        add     #4,r1
        mov.l   LH2_white,r0
        add     #0x30,r0
        add     r4,r0               ! tenths
        mov.l   r0,@r1
        mov.w   WH2_44,r0           ! health
        mov.w   @(r0,r2),r4
        extu.w  r4,r4
        mov.l   LH2_hpobj,r3
        mov.l   LH2_hpmax,r1
        mov.l   @r3,r0              ! VAR_HPOBJ
        cmp/eq  r2,r0
        bf      .Lb2_new
        mov.w   @r1,r0
        extu.w  r0,r5
        cmp/hi  r5,r4
        bf      .Lb2_max
.Lb2_new:
        mov.l   r2,@r3
        mov.w   r4,@r1
.Lb2_max:
        mov.w   @r1,r0
        extu.w  r0,r5               ! r5 = max (>= 1 while the boss is alive)
        tst     r5,r5
        bf      .Lb2_m1
        mov     #1,r5
.Lb2_m1:
        mov     #70,r0              ! fill = ceil(health * 70 / max)
        mul.l   r0,r4
        sts     macl,r3
        mov     #0,r6               ! fill
        mov     #0,r7               ! fill * max
.Lb2_div:
        cmp/hs  r3,r7
        bt      .Lb2_col
        add     #1,r6
        bra     .Lb2_div
        add     r5,r7
.Lb2_col:
        mov     r4,r2               ! r2 = health (the object isn't needed now)
        mov.w   WH2_chr,r7          ! colour: char base
        mov     #30,r0
        cmp/hi  r0,r4
        bt      .Lb2_cells          ! green
        add     #32,r7
        mov     #15,r0
        cmp/hi  r0,r4
        bt      .Lb2_cells          ! yellow
        add     #32,r7              ! red
.Lb2_cells:
        mov.l   LH2_row35,r1
        mov     #0,r3               ! cell
.Lb2_cell:
        ! cell 0: left end (7 px, type 0), 1..7: 8 px (type 1), 8: right end (7 px, type 2)
        mov     r6,r0
        tst     r3,r3
        bt      .Lb2_left
        mov     #8,r4
        cmp/eq  r4,r3
        bt      .Lb2_right
        mov     r3,r4               ! middle: n = fill - 7 - 8 (cell - 1), 0..8
        add     #-1,r4
        shll2   r4
        add     r4,r4
        add     #7,r4
        sub     r4,r0
        mov     #8,r4
        mov     #9,r5               ! type 1 at +9
        bra     .Lb2_clamp
        nop
.Lb2_left:
        mov     #7,r4
        bra     .Lb2_clamp
        mov     #0,r5
.Lb2_right:
        mov     #63,r4
        sub     r4,r0
        mov     #7,r4
        mov     #18,r5              ! type 2 at +18
.Lb2_clamp:
        cmp/pz  r0
        bt      .Lb2_c1
        mov     #0,r0
.Lb2_c1:
        cmp/gt  r4,r0
        bf      .Lb2_c2
        mov     r4,r0
.Lb2_c2:
        mov     r3,r4               ! countdown: the middle cell when red (health 1..15)
        add     #-4,r4
        tst     r4,r4
        bf      .Lb2_plain
        mov     #15,r4
        cmp/hi  r4,r2
        bt      .Lb2_plain
        tst     r2,r2
        bt      .Lb2_plain
        mov     r2,r4               ! BAR_DIGC + (health - 1) * 9 + n
        add     #-1,r4
        mov     r4,r5
        shll2   r5
        shll    r5
        add     r4,r5
        add     r5,r0
        mov.w   WH2_digc,r4
        bra     .Lb2_put
        add     r4,r0
.Lb2_plain:
        add     r5,r0
        add     r7,r0
.Lb2_put:
        mov.l   LH2_white,r4
        or      r4,r0
        mov.l   r0,@r1
        add     #4,r1
        add     #1,r3
        mov     r3,r0
        cmp/eq  #9,r0
        bf      .Lb2_cell
        bra     .Lb2_dirty
        nop
bhud2_blank:
        bsr     bhud2_clear
        nop
        mov.l   LH2_hpobj,r1
        mov     #0,r0
        mov.l   r0,@r1              ! VAR_HPOBJ: the next boss starts a new bar
.Lb2_dirty:
        mov.l   LH2_dirty,r1        ! rows 35..37
        mov     #1,r0
        mov.b   r0,@r1
        mov.b   r0,@(1,r1)
        mov.b   r0,@(2,r1)
        lds.l   @r15+,pr
        rts
        nop
! bhud2_clear: rows 37/36 cols 19..29, row 36 cols 13..17 and row 35 cols
! 11..19 blank. Leaves r2, r6. Uses r0, r1, r3, r7.
bhud2_clear:
        mov.l   LH2_row37,r1
        mov.l   LH2_row36r,r3
        mov.l   LH2_blank,r0
        mov     #11,r7
.Lb2_cl1:
        mov.l   r0,@r1
        mov.l   r0,@r3
        add     #4,r1
        dt      r7
        bf/s    .Lb2_cl1
        add     #4,r3
        mov.l   LH2_row36,r1        ! timer field (row 38, cols 25..29)
        mov     #5,r7
.Lb2_cl2:
        mov.l   r0,@r1
        dt      r7
        bf/s    .Lb2_cl2
        add     #4,r1
        rts
        nop
        .align 1
WH2_chr:    .word BAR_CHR
WH2_digc:   .word BAR_DIGC
WH2_44:     .word 0x44
        .align 2
LH2_row36:  .long TEXT + 38*0x80 + 25*4    ! timer: under the RANK value
LH2_row35:  .long TEXT + 37*0x80 + 21*4    ! bar: right-aligned under the timer
LH2_hpmax:  .long VAR_HPMAX
LH2_hpobj:  .long VAR_HPOBJ
LH2_pow3:   .long hpow3
LH2_row37:  .long TEXT + 37*0x80 + 19*4
LH2_row36r: .long TEXT + 36*0x80 + 19*4
LH2_blank:  .long 0x80808020
LH2_white:  .long 0x80808000
LH2_dirty:  .long DIRTY + 36
        .endif

        .ifndef STANDALONE
! title footer, second line ("SALE BY AMI" in the game): printed from here
! through the literal at 0x0C06E77C (row 2, column 9)
nfs_str:    .asciz  "NOT FOR SALE"
        .align 2
        .endif

        .ifndef STANDALONE
!------------------------------------------------------------------
! hadou_hud (combined, Rosy's Arrange play, every frame): HADOUGUN stock. A
! lost life adds one, up to HADOU_MAX. Shown as 1..4 icons in the lower right
! of the text layer (rows 2..0, cols 21..29: chars HADOU_CHR + (n-1) x 32 +
! row x 9 + col). Cells are only rewritten (rows marked dirty) on a change.
!------------------------------------------------------------------
hadou_hud:
        mov.l   r8,@-r15
        mov.l   LHH_p1,r1
        mov.w   WHH_27b,r0
        mov.b   @(r0,r1),r2
        extu.b  r2,r2
        add     #1,r2               ! lives + 1
        mov.l   LHH_var,r3
        mov.b   @(1,r3),r0          ! VAR_HLIVES
        extu.b  r0,r4
        mov     r2,r0
        mov.b   r0,@(1,r3)
        tst     r4,r4
        bt      .Lhh_show           ! first frame
        cmp/hs  r4,r2
        bt      .Lhh_show           ! not fewer lives
        mov.b   @r3,r0              ! a life was lost: one more HADOUGUN
        extu.b  r0,r0
        cmp/eq  #HADOU_MAX,r0
        bt      .Lhh_show
        add     #1,r0
        mov.b   r0,@r3
.Lhh_show:
        mov.b   @r3,r0
        extu.b  r0,r5               ! r5 = count
        mov.l   LHH_cell,r1         ! row 2, col 21
        mov.l   LHH_dirty,r6        ! DIRTY + 7
        mov.w   WHH_chr,r7
        mov     r5,r0
        add     #-1,r0
        shll2   r0
        shll2   r0
        shll    r0                  ! (count - 1) x 32
        add     r0,r7               ! r7 = first char of this strip
        mov     #3,r3               ! rows
.Lhh_row:
        mov     #9,r2               ! cols
        mov     #0,r4               ! row changed?
.Lhh_col:
        mov     #0,r0
        tst     r5,r5
        bt      .Lhh_c              ! no stock: empty cells
        mov.l   LHH_tint,r0
        or      r7,r0
.Lhh_c:
        mov.l   @r1,r8
        cmp/eq  r0,r8
        bt      .Lhh_same
        mov.l   r0,@r1
        mov     #1,r4
.Lhh_same:
        add     #1,r7
        dt      r2
        bf/s    .Lhh_col
        add     #4,r1
        tst     r4,r4
        bt      .Lhh_nd
        mov     #1,r0
        mov.b   r0,@r6
.Lhh_nd:
        add     #-1,r6
        mov.w   WHH_back,r0         ! next row down: -0x80 - 9 cells
        add     r0,r1
        dt      r3
        bf      .Lhh_row
        rts
        mov.l   @r15+,r8
        .align 1
WHH_27b:    .word 0x27B
WHH_chr:    .word HADOU_CHR
WHH_back:   .word -0x80 - 9 * 4
        .align 2
LHH_p1:     .long P1
LHH_var:    .long VAR_HADOU
LHH_cell:   .long TEXT + 2 * 0x80 + 21 * 4
LHH_dirty:  .long DIRTY + 2
LHH_tint:   .long 0x80808000
        .endif

        .ifndef STANDALONE
!------------------------------------------------------------------
! HADOUGUN (combined build, Rosy's Arrange real play), with the HADO-GUN
! graphics from the player's Ibara (build.py HG_REGIONS, uploaded with the
! bar tiles into free VRAM: page 0x0B00,0x0E00 = trail segments + shot head,
! page 0x0C00,0x0E00 = aim line + glow; our banks HG_BANK / HG_BANK + 1).
!  Hold B with stock: the options swing from the sides to the front over
!  HG_CHARGE frames while the aim lines grow from them. Let go after that:
!  the shot flies up from between the options at 4 px a frame, dropping a
!  trail segment every 12 px; the trail column damages enemies and cancels
!  bullets. The shot sticks to the first enemy it touches and stays on it
!  (damaging it) until it dies or HG_STICK frames pass. One stock used.
!  Let go earlier: the options go back (no new charge until they are back).
! Options: 0x0C453630 (2 x 60 bytes), +48 angle (512 = turn, 0 = up).
!------------------------------------------------------------------
        .set    HG_SIDE,    16              ! option angle at the front
        .set    HG_TOP,     352             ! the shot leaves the screen above this (up axis, px)
        .set    HG_LIFE,    900             ! frames (15 s) a trail segment stays (and damages)
        .set    HG_NSEG,    32              ! most trail segments
        .set    HG_STICK,   900             ! most frames (15 s) the ball stays on an enemy
        .set    HG_BFADE,   60              ! ... the last of them fading out
        .set    HG_DMG,     2               ! trail damage per frame
        .set    HG_HDMG,    2               ! stuck ball damage per frame
        .set    HG_HALFW,   20              ! half width of the trail for hits (px)
        .set    HG_HIT,     16              ! head hit distance (px)
        .set    HG_BANK,    0xFF0           ! bank ids for our two VRAM pages

! hg_logic (from magnet, every Rosy Arrange real-play frame)
hg_logic:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   LG2_hgs,r8          ! r8 -> VAR_HGS
        mov.l   LG2_p1,r1
        mov.w   @r1,r0
        mov.l   WG2_alive,r2
        cmp/eq  r2,r0
        bt      .Lhq_alive
        mov.b   @r8,r0              ! not alive: drop the charge; the options swing
        cmp/eq  #1,r0               ! back once alive again (they aren't touched
        bt      .Lhq_dch            ! while the ship is dead)
        cmp/eq  #2,r0
        bf      .Lhq_beam
.Lhq_dch:
        mov     #3,r0
        bra     .Lhq_beam
        mov.b   r0,@r8
.Lhq_alive:
        mov.l   LG2_prev,r1
        mov.b   @r1,r4
        mov     #0x20,r0
        and     r0,r4               ! r4 = B held
        mov.b   @r8,r0
        extu.b  r0,r0
        cmp/eq  #1,r0
        bt      .Lhq_charge
        cmp/eq  #2,r0
        bt      .Lhq_ready
        cmp/eq  #3,r0
        bt      .Lhq_back
        mov.l   LG2_opt,r1          ! idle: remember the options' angles
        mov     r8,r2
        add     #2,r2               ! VAR_HGO
        mov     #48,r0
        mov.w   @(r0,r1),r3
        mov.w   r3,@r2
        add     #60,r1
        mov.w   @(r0,r1),r0
        mov.w   r0,@(2,r2)
        tst     r4,r4
        bt      .Lhq_beam
        mov.l   LG2_stock,r1        ! B held past a tap with stock: charge
        mov.b   @r1,r0
        tst     r0,r0
        bt      .Lhq_beam
        mov.l   LG2_bhold,r1
        mov.b   @r1,r0
        extu.b  r0,r0
        mov     #HG_TAP,r1
        cmp/hs  r1,r0
        bf      .Lhq_beam
        mov     #1,r0
        mov.b   r0,@r8
        mov     #HG_TAP,r0          ! the tap time counts
        bra     .Lhq_ang
        mov.b   r0,@(1,r8)
.Lhq_charge:
        tst     r4,r4
        bt      .Lhq_toback         ! let go too early
        mov.b   @(1,r8),r0
        extu.b  r0,r0
        add     #1,r0
        mov.b   r0,@(1,r8)
        cmp/eq  #HG_CHARGE,r0
        bf      .Lhq_ang
        mov     #2,r0
        bra     .Lhq_ang
        mov.b   r0,@r8
.Lhq_ready:
        tst     r4,r4
        bf      .Lhq_ang
        mov.l   LG2_stock,r1        ! fire: one HADOUGUN used
        mov.b   @r1,r0
        add     #-1,r0
        mov.b   r0,@r1
        mov.l   LG2_p1,r1
        mov.l   @(24,r1),r2         ! ship, up axis
        mov.l   LG2_ahead,r3
        add     r3,r2
        mov.l   @(28,r1),r3         ! ship, across
        mov.l   LG2_shots,r1        ! a free shot slot, else the oldest
        mov     r1,r5
        mov     #0,r6               ! oldest BT
        mov     #HG_NSHOT,r7
.Lhq_fs:
        mov.w   @(24,r1),r0
        extu.w  r0,r0
        tst     r0,r0
        bt      .Lhq_fsok
        cmp/hi  r6,r0
        bf      .Lhq_fsn
        mov     r0,r6
        mov     r1,r5
.Lhq_fsn:
        dt      r7
        bf/s    .Lhq_fs
        add     #32,r1
        mov     r5,r1
.Lhq_fsok:
        mov.l   r2,@r1              ! BX
        mov.l   r3,@(4,r1)          ! VAR_BY
        mov.l   r2,@(8,r1)          ! VAR_HX
        mov.l   r3,@(12,r1)         ! VAR_HY
        mov     #0,r0
        mov.l   r0,@(16,r1)         ! VAR_HOBJ: flying
        mov.l   r0,@(20,r1)         ! HSTK, HNSEG
        mov     #1,r0
        mov.w   r0,@(24,r1)         ! BT = 1
        mov.l   LG2_sndfn,r0        ! launch sound: the game's sound 0x29
        jsr     @r0                 ! (the one a coin makes), through its own
        mov     #HG_SND,r4          ! "play sound" routine
.Lhq_toback:
        mov     #3,r0
        bra     .Lhq_ang
        mov.b   r0,@r8
.Lhq_back:
        mov.b   @(1,r8),r0
        extu.b  r0,r0
        add     #-2,r0
        cmp/pl  r0
        bt      .Lhq_bk
        mov     #0,r0
        mov.b   r0,@r8              ! back at the sides: idle
.Lhq_bk:
        mov.b   r0,@(1,r8)
.Lhq_ang:
        bsr     hg_setang
        nop
.Lhq_beam:
        mov.l   LG2_hfc,r1          ! logic frame counter (hg_fx draws once per frame)
        mov.l   @r1,r0
        add     #1,r0
        mov.l   r0,@r1
        bsr     hg_puffage
        nop
        mov.l   LG2_shots,r10
        mov     #HG_NSHOT,r8
.Lhq_sl:
        mov.l   r8,@-r15
        mov.l   r10,@-r15
        bsr     hg_shot
        nop
        mov.l   @r15+,r10
        mov.l   @r15+,r8
        dt      r8
        bf/s    .Lhq_sl
        add     #32,r10
        bra     .Lhq_out
        nop

! hg_shot (hg_logic): one HADOUGUN shot, r10 -> its slot. Uses r0-r11.
hg_shot:
        sts.l   pr,@-r15
        mov.w   @(24,r10),r0        ! BT
        extu.w  r0,r9
        tst     r9,r9
        bf      .Lhq_bt0
        bra     .Lhs_out
        nop
.Lhq_bt0:
        add     #1,r9
        mov.l   WG2_end,r0
        cmp/hi  r0,r9
        bf      .Lhq_bt
        mov     #0,r9
.Lhq_bt:
        mov     r9,r0
        mov.w   r0,@(24,r10)
        tst     r9,r9
        bf      .Lhq_live
        bra     .Lhs_out
        nop
.Lhq_live:
        ! --- the head: flying, stuck or gone ---
        mov.l   @(16,r10),r1        ! VAR_HOBJ
        tst     r1,r1
        bt      .Lhq_fly
        mov     r1,r0
        cmp/eq  #-1,r0              ! -1: the head is gone (never read through it:
        bt      .Lhq_trail          ! a misaligned read crashes the real SH-3)
        mov.w   @(20,r10),r0        ! VAR_HSTK
        add     #1,r0
        mov.w   r0,@(20,r10)
        mov.l   WG2_stick,r2
        cmp/hs  r2,r0
        bt      .Lhq_unstick        ! 15 s: gone
        mov.l   WG2_fade,r2
        cmp/hs  r2,r0
        bt      .Lhq_trail          ! fading: stays where it is
        mov.w   @r1,r0              ! stuck: follow it while it lives
        tst     r0,r0
        bt      .Lhq_dead
        mov.l   WG2_44,r0
        mov.w   @(r0,r1),r0
        tst     r0,r0
        bt      .Lhq_dead
        mov.l   @(44,r1),r0
        mov.l   r0,@(8,r10)         ! head on the enemy
        mov.l   @(48,r1),r0
        mov.l   r0,@(12,r10)
        mov     r1,r0               ! damage it: slot = (obj - table) / 0xCC
        mov.l   LG2_enemy,r2
        sub     r2,r0
        mov     #0,r5
        mov.l   WG2_cc,r2
.Lhq_slot:
        cmp/hs  r2,r0
        bf      .Lhq_sl2
        sub     r2,r0
        bra     .Lhq_slot
        add     #1,r5
.Lhq_sl2:
        mov     #0,r4
        mov.l   LG2_crkflag,r6
        mov.l   LG2_dmgfn,r0
        jsr     @r0
        mov     #HG_HDMG,r7
        bra     .Lhq_trail
        nop
.Lhq_dead:
        mov.l   WG2_fade,r0         ! the enemy died: the ball fades out where it is
        mov.w   r0,@(20,r10)
        bra     .Lhq_trail
        nop
.Lhq_unstick:
        mov     #-1,r0              ! done: the head is gone (HOBJ = -1)
        bra     .Lhq_trail
        mov.l   r0,@(16,r10)
.Lhq_fly:
        mov.l   @(8,r10),r2         ! up 4 px
        mov.l   LG2_4,r0
        add     r0,r2
        mov.l   r2,@(8,r10)
        mov.l   LG2_top,r0
        cmp/gt  r0,r2
        bt      .Lhq_unstick        ! off the top
        mov.l   @(12,r10),r3
        ! touching an enemy?
        mov.l   LG2_enemy,r11
        mov     #0,r9
.Lhq_hit:
        mov.l   @r11,r0             ! alive, can be hit, HP left
        tst     r0,r0
        bt      .Lhq_hnext
        mov.l   LG2_nohit,r1
        tst     r1,r0
        bf      .Lhq_hnext
        mov.l   WG2_44,r0
        mov.w   @(r0,r11),r0
        tst     r0,r0
        bt      .Lhq_hnext
        mov.l   @(44,r11),r0
        sub     r2,r0
        cmp/pz  r0
        bt      .Lhq_h1
        neg     r0,r0
.Lhq_h1:
        mov.l   LG2_hit,r1
        cmp/hi  r1,r0
        bt      .Lhq_hnext
        mov.l   @(48,r11),r0
        sub     r3,r0
        cmp/pz  r0
        bt      .Lhq_h2
        neg     r0,r0
.Lhq_h2:
        cmp/hi  r1,r0
        bt      .Lhq_hnext
        mov.l   r11,@(16,r10)       ! stuck
        bra     .Lhq_trail
        nop
.Lhq_hnext:
        mov.l   WG2_cc,r0
        add     r0,r11
        add     #1,r9
        mov.l   WG2_192,r0
        cmp/eq  r0,r9
        bf      .Lhq_hit
.Lhq_trail:
        bsr     hg_puffs
        nop
        ! trail segments follow the head up the column (one every 12 px)
        mov.l   @(8,r10),r0         ! while flying: n = (head - BX) / 12
        mov.l   @(16,r10),r1
        tst     r1,r1
        bf      .Lhq_tdone
        mov.l   @r10,r1
        sub     r1,r0
        shlr16  r0
        mov.l   WG2_twelfth,r1
        mulu.w  r1,r0
        sts     macl,r0
        shlr16  r0
        mov     #HG_NSEG,r1
        cmp/hi  r1,r0
        bf      .Lhq_tn
        mov     r1,r0
.Lhq_tn:
        mov.w   r0,@(22,r10)        ! VAR_HNSEG
.Lhq_tdone:
        mov.w   @(22,r10),r0
        extu.w  r0,r7
        tst     r7,r7
        bt      .Lhs_out
        ! trail hit range on the up axis: BX - 8 .. BX + 12 n + 8
        mov.l   @r10,r6
        mov.l   LG2_8,r0
        sub     r0,r6
        mov     r7,r0
        shll2   r0
        mov     r0,r1
        add     r0,r0
        add     r1,r0               ! 12 n
        shll16  r0
        mov.l   @r10,r7
        add     r0,r7
        mov.l   LG2_8,r0
        add     r0,r7
        mov.l   @(4,r10),r11        ! BY
        mov.l   LG2_enemy,r10
        mov     #0,r9
.Lhq_en:
        mov.l   @r10,r0             ! alive with HP left
        tst     r0,r0
        bt      .Lhq_ennext
        mov.l   WG2_44,r0
        mov.w   @(r0,r10),r0
        tst     r0,r0
        bt      .Lhq_ennext
        mov.l   @(44,r10),r0
        cmp/ge  r6,r0
        bf      .Lhq_ennext
        cmp/gt  r7,r0
        bt      .Lhq_ennext
        mov.l   @(48,r10),r0
        sub     r11,r0
        cmp/pz  r0
        bt      .Lhq_enabs
        neg     r0,r0
.Lhq_enabs:
        mov.l   LG2_halfw,r1
        cmp/hi  r1,r0
        bt      .Lhq_ennext
        mov.l   r6,@-r15
        mov.l   r7,@-r15
        mov     #0,r4
        mov     r9,r5
        mov.l   LG2_crkflag,r6
        mov.l   LG2_dmgfn,r0
        jsr     @r0
        mov     #HG_DMG,r7
        mov.l   @r15+,r7
        mov.l   @r15+,r6
.Lhq_ennext:
        mov.l   WG2_cc,r0
        add     r0,r10
        add     #1,r9
        mov.l   WG2_192,r0
        cmp/eq  r0,r9
        bf      .Lhq_en
        ! bullets in the column: the game's live-bullet list is a stack of
        ! pointers from @0x0C106BF8 up to @0x0C5C178C (walked top down, as
        ! the game does, so removals during the walk are safe)
        mov.l   LG2_btop,r9
        mov.l   @r9,r9
.Lhq_bl:
        mov.l   LG2_bbase,r0
        mov.l   @r0,r0
        cmp/hi  r0,r9
        bf      .Lhs_out
        add     #-4,r9
        mov.l   @r9,r10
        mov.l   @r10,r0             ! a live bullet (bit 31) that can be
        cmp/pz  r0                  ! cancelled (0x00100000, as the game's
        bt      .Lhq_blnext         ! own cracker loop tests: other bullet
        mov.l   LG2_bcan,r1         ! types make a bad item when cancelled,
        tst     r1,r0               ! which crashes the real SH-3)
        bt      .Lhq_blnext
        mov.l   @(32,r10),r1        ! and has a hitbox (the game skips
        tst     r1,r1               ! bullets whose hit-shape list is empty)
        bt      .Lhq_blnext
        mov.l   @r1,r1
        tst     r1,r1
        bt      .Lhq_blnext
        mov.l   @(48,r10),r0
        cmp/ge  r6,r0
        bf      .Lhq_blnext
        cmp/gt  r7,r0
        bt      .Lhq_blnext
        mov.l   @(52,r10),r0
        sub     r11,r0
        cmp/pz  r0
        bt      .Lhq_blabs
        neg     r0,r0
.Lhq_blabs:
        mov.l   LG2_halfw,r1
        cmp/hi  r1,r0
        bt      .Lhq_blnext
        mov.l   r9,@-r15
        mov.l   r6,@-r15
        mov.l   r7,@-r15
        mov.l   @(48,r10),r6        ! where it was (for the medal)
        mov.l   @(52,r10),r7
        mov.l   r6,@-r15
        mov.l   r7,@-r15
        mov.l   LG2_cancel,r0
        jsr     @r0
        mov     r10,r4
        mov.l   @r15+,r7            ! as the rose cracker: a 1,000-point
        mov.l   @r15+,r6            ! medal pops out (arr_qspawn) and a
        mov.l   LG2_qpush,r0        ! tick-point for the meter
        jsr     @r0
        nop
        mov.l   LG2_tick,r0
        jsr     @r0
        nop
        mov.l   @r15+,r7
        mov.l   @r15+,r6
        mov.l   @r15+,r9
.Lhq_blnext:
        bra     .Lhq_bl
        nop
.Lhs_out:
        lds.l   @r15+,pr
        rts
        nop
.Lhq_out:
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop


! hg_setang: option angles from VAR_HGT (0 = own angle, HG_CHARGE = front).
! r8 -> VAR_HGS. Uses r0..r3, r5, r6.
hg_setang:
        mov.b   @(1,r8),r0
        extu.b  r0,r5               ! t
        mov.l   WG2_inv,r0          ! 65536 / HG_CHARGE
        mulu.w  r0,r5
        sts     macl,r5             ! t * 65536 / HG_CHARGE
        mov.l   LG2_opt,r1
        mov     r8,r2
        add     #2,r2               ! VAR_HGO
        mov     #2,r6
.Lsa_one:
        mov.w   @r2+,r3             ! own angle
        mov     #HG_SIDE,r0
        cmp/pz  r3
        bt      .Lsa_pos
        neg     r0,r0
.Lsa_pos:
        sub     r3,r0               ! target - own
        mul.l   r0,r5
        sts     macl,r0
        shlr16  r0                  ! >> 16, sign kept below
        exts.w  r0,r0
        add     r3,r0
        mov.l   r0,@-r15
        mov     #48,r0
        mov.l   @r15+,r3
        mov.w   r3,@(r0,r1)
        dt      r6
        bf/s    .Lsa_one
        add     #60,r1
        rts
        nop
        .align 2
WG2_alive:  .long 0xFFFFCE00
WG2_end:    .long HG_NSEG * 3 + HG_LIFE + 60
WG2_4000:   .long 0x4000
WG2_44:     .long 0x44
WG2_cc:     .long 0xCC
WG2_192:    .long 192
WG2_1024:   .long 1024
WG2_90:     .long 0x90
WG2_inv:    .long 65536 / HG_CHARGE
WG2_stick:  .long HG_STICK
WG2_fade:   .long HG_STICK - HG_BFADE
WG2_twelfth:.long 0x1556
        .align 2
LG2_p1:     .long P1
LG2_hgs:    .long VAR_HGS
LG2_prev:   .long VAR_PREV
LG2_opt:    .long 0x0C453630
LG2_stock:  .long VAR_HADOU
LG2_ahead:  .long 32 << 16
LG2_bx:     .long VAR_BX
LG2_4:      .long 4 << 16
LG2_8:      .long 8 << 16
LG2_top:    .long HG_TOP << 16
LG2_hit:    .long HG_HIT << 16
LG2_enemy:  .long 0x0C416968
LG2_halfw:  .long HG_HALFW << 16
LG2_crkflag:.long 0xCC100000
LG2_dmgfn:  .long 0x0C084F10
LG2_bul:    .long 0x0C4541B4
LG2_cancel: .long 0x0C088940
LG2_puff:   .long VAR_PUFF
LG2_shots:  .long VAR_SHOTS
LG2_hfc:    .long VAR_HFC
LG2_sndfn:  .long 0x0C08B050
LG2_nohit:  .long 0x20000000
LG2_bhold:  .long VAR_BHOLD
LG2_qpush:  .long q_push
LG2_btop:   .long 0x0C5C178C
LG2_bbase:  .long 0x0C106BF8
LG2_bcan:   .long 0x00100000
LG2_tick:   .long tick_crk

! hg_pdraw (arr_spr, Rosy Arrange real play): the ship's sprite call (r4..r7
! and 3 stack arguments), then the aim lines, trail and shot head on top.
hg_pdraw:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        add     #-12,r15
        mov.l   @(32,r15),r0        ! the caller's stack arguments
        mov.l   r0,@r15
        mov.l   @(36,r15),r0
        mov.l   r0,@(4,r15)
        mov.l   @(40,r15),r0
        mov.l   r0,@(8,r15)
        bsr     hg_spr              ! the ship
        nop
        bsr     hg_fx               ! then the HADOUGUN effects (once a frame)
        nop
        add     #12,r15
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

! hg_fx: the HADOUGUN effects (aim lines, smoke, trails, heads/balls), at
! most once a frame: from the ship's sprite call, or, when the ship isn't
! drawn (dead, respawning), from the first sprite call after its place.
hg_fx:
        mov.l   LP_hfc,r1
        mov.l   @r1,r0
        mov.l   @(4,r1),r2          ! VAR_HDRAWN
        cmp/eq  r0,r2
        bf      .Lfx_go
        rts
        nop
.Lfx_go:
        mov.l   r0,@(4,r1)
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        add     #-12,r15            ! sprite routine stack arguments (hg_one)
        mov.l   LP_btab,r1          ! our VRAM pages in the bank table
        mov.l   LP_page0,r0
        mov.l   r0,@r1
        mov.l   LP_page1,r0
        mov.l   r0,@(4,r1)
        mov.l   LP_page2,r0
        mov.l   r0,@(8,r1)
        mov.l   LP_page3,r0
        mov.l   r0,@(12,r1)
        mov.l   LP_hgs,r8
        mov.b   @r8,r0
        extu.b  r0,r0
        cmp/eq  #1,r0
        bt      .Lpd_lines
        cmp/eq  #2,r0
        bf      .Lpd_beam
        mov     #128,r9             ! ready: full length, dots moving
        extu.b  r9,r9
        bra     .Lpd_l2
        nop
.Lpd_lines:
        mov.b   @(1,r8),r0          ! charging: grow with the charge (2 t + 8)
        extu.b  r0,r9
        add     r9,r9
        add     #8,r9
.Lpd_l2:
        mov.l   LP_frame,r1         ! frame counter for the dot animation
        mov.l   @r1,r0
        add     #1,r0
        mov.l   r0,@r1
        shlr2   r0
        shlr    r0
        mov     #0,r0
        mov     r0,r11              ! line frame (one frame kept)
        mov.l   LP_opt,r10
        mov     #2,r8               ! two options (r8 is reloaded below)
.Lpd_lone:
        ! aim line: our def with length r9 (in the r15 scratch def)
        mov.l   LP_ldef,r4
        mov     r11,r0
        mov     #24,r1
        mulu.w  r1,r0
        sts     macl,r0
        mov.b   r0,@(3,r4)          ! src y = frame x 24
        mov     r9,r0
        add     #-1,r0
        mov.b   r0,@(6,r4)          ! x size - 1 = length - 1
        mov.l   LP_flip,r0
        or      r0,r4
        mov.w   WP_8000,r6
        extu.w  r6,r6
        mov.l   @(20,r10),r7
        bsr     hg_one
        mov.l   @(24,r10),r3
        mov.l   LP_gdef,r4          ! glow, same length
        mov     r11,r0
        mov     #24,r1
        mulu.w  r1,r0
        sts     macl,r0
        mov.b   r0,@(3,r4)
        mov     r9,r0
        add     #-1,r0
        mov.b   r0,@(6,r4)
        mov.l   LP_flip,r0
        or      r0,r4
        mov.l   LP_blend,r6
        mov.l   @(20,r10),r7
        bsr     hg_one
        mov.l   @(24,r10),r3
        dt      r8
        bf/s    .Lpd_lone
        add     #60,r10
.Lpd_beam:
        mov.l   LP_puff,r11         ! launch cloud
        mov     #HG_NPUFF,r8
.Lpd_puff:
        mov.b   @(4,r11),r0
        extu.b  r0,r2               ! age
        tst     r2,r2
        bt      .Lpd_pn
        mov     r2,r0               ! frame = min(age / 8, 7)
        shlr2   r0
        shlr    r0
        mov     #7,r1
        cmp/hi  r1,r0
        bf      .Lpd_pf
        mov     r1,r0
.Lpd_pf:
        mov     r0,r1               ! def = hg_pdefs + frame x 12
        shll2   r1
        mov     r1,r0
        add     r1,r1
        add     r0,r1
        mov.l   LP_pdefs,r0
        add     r0,r1
        mov     r1,r4
        mov     r2,r0               ! additive, alpha 0xC0 - age x 2
        add     r2,r0
        mov.w   WP_c0,r6
        sub     r0,r6
        mov     r6,r0
        shll8   r0
        or      r0,r6
        mov.l   LP_add,r0
        or      r0,r6
        mov.w   @r11,r7             ! up
        extu.w  r7,r7
        shll16  r7
        mov.w   @(2,r11),r0         ! across
        extu.w  r0,r3
        bsr     hg_one
        shll16  r3
.Lpd_pn:
        dt      r8
        bf/s    .Lpd_puff
        add     #8,r11
        mov.l   LP_shots,r10        ! the shots
        mov     #HG_NSHOT,r8
.Lpd_sl:
        mov.l   r8,@-r15
        mov.l   r10,@-r15
        bsr     hg_fxshot
        nop
        mov.l   @r15+,r10
        mov.l   @r15+,r8
        dt      r8
        bf/s    .Lpd_sl
        add     #32,r10
        add     #12,r15
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

hg_fxshot:                          ! one shot's trail and head/ball, r10 -> slot
        sts.l   pr,@-r15
        add     #-12,r15
        mov.w   @(24,r10),r0        ! BT
        extu.w  r0,r9
        tst     r9,r9
        bt      .Lpd_out
        mov.w   @(22,r10),r0
        extu.w  r0,r11              ! segments dropped
        ! trail: segment i at BX + 12 i, dropped at BT ~ 3 i
        mov     #0,r8
.Lpd_seg:
        cmp/hs  r11,r8
        bt      .Lpd_head
        mov     r8,r0
        add     r8,r0
        add     r8,r0               ! 3 i
        mov     r9,r2
        sub     r0,r2               ! age
        cmp/pz  r2
        bf      .Lpd_next
        mov.w   WP_life,r0
        cmp/hs  r0,r2
        bt      .Lpd_next
        mov     r8,r7               ! 12 i
        shll2   r7
        mov     r7,r0
        add     r7,r7
        add     r0,r7
        shll16  r7
        mov.l   @r10,r0
        add     r0,r7
        mov.w   WP_third,r0         ! frame = (age / 3) & 15
        mulu.w  r0,r2
        sts     macl,r2
        shlr16  r2
        mov     r2,r0
        and     #15,r0
        mov     r0,r1               ! def = hg_sdefs + frame x 12
        shll2   r1
        mov     r1,r0
        add     r1,r1
        add     r0,r1
        mov.l   LP_sdefs,r0
        add     r0,r1
        mov     r1,r4
        mov     r8,r0               ! age = BT - 3 i
        add     r8,r0
        add     r8,r0
        mov     r9,r5
        sub     r0,r5
        mov.w   WP_life,r0          ! frames left
        sub     r5,r0
        mov     #120,r6
        cmp/hs  r6,r0
        bf/s    .Lpd_al             ! the last 120 frames: alpha = frames left
        mov     r0,r6
        mov.w   WP_sixth,r0         ! else alpha = 0xFF - age / 6
        mulu.w  r0,r5
        sts     macl,r5
        shlr16  r5
        mov.w   WP_ff,r6
        sub     r5,r6
.Lpd_al:
        mov     r6,r0
        shll8   r0
        or      r0,r6
        mov.l   LP_seg,r0
        or      r0,r6
        bsr     hg_one
        mov.l   @(4,r10),r3
.Lpd_next:
        bra     .Lpd_seg
        add     #1,r8
.Lpd_head:
        mov.l   @(16,r10),r0        ! VAR_HOBJ = -1: gone
        cmp/eq  #-1,r0
        bt      .Lpd_out
        tst     r0,r0
        bt      .Lpd_fly
        mov     r9,r0               ! stuck: the red ball, frame (BT / 3) mod 9
        mov.w   WP_third,r1
        mulu.w  r1,r0
        sts     macl,r0
        shlr16  r0
.Lpd_m9:
        mov     #9,r1
        cmp/hs  r1,r0
        bf      .Lpd_b9
        bra     .Lpd_m9
        add     #-9,r0
.Lpd_b9:
        mov     r0,r1               ! def = hg_bdefs + frame x 12
        shll2   r1
        mov     r1,r0
        add     r1,r1
        add     r0,r1
        mov.l   LP_bdefs,r0
        add     r0,r1
        mov     r1,r4
        mov.w   WP_8000,r6
        extu.w  r6,r6
        mov.w   @(20,r10),r0        ! fading out: alpha = frames left x 4
        extu.w  r0,r1
        mov.w   WP_bfade,r0
        cmp/hs  r0,r1
        bf      .Lpd_bd
        mov.w   WP_stick,r6
        sub     r1,r6
        shll2   r6
        mov     r6,r0
        shll8   r0
        or      r0,r6
        mov.l   LP_seg,r0
        or      r0,r6
.Lpd_bd:
        mov.l   @(8,r10),r7
        bsr     hg_one
        mov.l   @(12,r10),r3
        bra     .Lpd_out
        nop
.Lpd_fly:
        mov     r9,r0               ! frame BT & 7
        and     #7,r0
        mov     r0,r1
        shll2   r1
        mov     r1,r0
        add     r1,r1
        add     r0,r1               ! x 12
        mov.l   LP_hdefs,r0
        add     r0,r1
        mov     r1,r4
        mov.w   WP_8000,r6
        extu.w  r6,r6
        mov.l   @(8,r10),r7
        bsr     hg_one
        mov.l   @(12,r10),r3
.Lpd_out:
        add     #12,r15
        lds.l   @r15+,pr
        rts
        nop
hg_one:                             ! r4 def, r6 flags, r7 up, r3 across
        mov.l   r3,@r15
        mov.l   LP_tint,r0
        mov.l   r0,@(4,r15)
        mov     #0,r0
        mov.l   r0,@(8,r15)
        mov.l   LP_banks,r5
hg_spr:                             ! enter the sprite routine as a normal call
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   r12,@-r15
        mov.l   r13,@-r15
        mov.l   LP_ret,r0
        jmp     @r0
        nop
        .align 1
WP_third:   .word 0x5556
WP_8000:    .word 0x8000
WP_life:    .word HG_LIFE
WP_ff:      .word 0xFF
WP_f0:      .word 0xF0
WP_c0:      .word 0xC0
WP_sixth:   .word 0x2AAB
WP_stick:   .word HG_STICK
WP_bfade:   .word HG_STICK - HG_BFADE
        .align 2
LP_btab:    .long 0x0C49CD60 + HG_BANK * 4
LP_page0:   .long 0x0B000E00
LP_page1:   .long 0x0C000E00
LP_page2:   .long 0x0D000E00
LP_page3:   .long 0x0E000E00
LP_puff:    .long VAR_PUFF
LP_add:     .long 0x02070000
LP_pdefs:   .long hg_pdefs
LP_bdefs:   .long hg_bdefs
LP_hgs:     .long VAR_HGS
LP_frame:   .long VAR_HFRM
LP_opt:     .long 0x0C453630
LP_flip:    .long HG_FLIP
LP_blend:   .long 0x02078000
LP_seg:     .long 0x02040000
LP_shots:   .long VAR_SHOTS
LP_hfc:     .long VAR_HFC
LP_tint:    .long 0x00808080
LP_ret:     .long 0x0C07C21C
LP_ldef:    .long hg_ldef
LP_gdef:    .long hg_gdef
LP_sdefs:   .long hg_sdefs
LP_hdefs:   .long hg_hdefs
LP_banks:   .long hg_banks
hg_banks:   .word HG_BANK, HG_BANK + 1, HG_BANK + 2, HG_BANK + 3
        .align 2
! defs (5 words + end): w0 = flags | bank list index + 1, w1 = src x << 8 | y
! in the page, w2 = offsets, w3 = (x size - 1) << 8 | (y size - 1), w4 = 0
hg_sdefs:                           ! trail segment frames 0..15 (page 0, x 0x00..0x1F)
        .irp    f, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
        .word   0x9001, ((0x10 - (\f / 8) * 0x10) << 8) | ((\f % 8) * 0x20), 0xF8F0, 0x0F1F, 0, 0
        .endr
hg_hdefs:                           ! shot head frames 0..7 (page 0, x 0x40..0x67)
        .irp    f, 0,1,2,3,4,5,6,7
        .word   0x9801, (0x40 << 8) | (\f * 0x18), 0xE8F4, 0x2717, 0, 0
        .endr
hg_bdefs:                           ! red ball frames 0..8 (page 2: 84 x 84 cells)
        .irp    f, 0,1,2,3,4,5,6,7,8
        .word   0x8003, ((4 + (\f % 3) * 84) << 8) | ((\f / 3) * 84), 0xD6D6, 0x5353, 0, 0
        .endr
hg_pdefs:                           ! smoke puff frames 0..7 (page 3: 32 x 32)
        .irp    f, 0,1,2,3,4,5,6,7
        .word   0x8004, \f * 32, 0xF0F0, 0x1F1F, 0, 0
        .endr
hg_ldef:                            ! aim line (page 1, x 0x00; y and length set when drawn)
        .word   0x8002, 0x0000, 0x00F4, 0x7F17, 0, 0
hg_gdef:                            ! glow (page 1, x 0x80)
        .word   0x8002, 0x8000, 0x00F4, 0x7F17, 0, 0
        .align 2

! hg_upchunk (labels_blit, blitter idle): upload the next chunk (up to
! HG_CHUNK pixels) of the next HADOUGUN graphics region: copy its rows from
! the u4 (hg_regions) into hg_ubuf behind an upload command and run it.
hg_upchunk:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   LU_hui,r11          ! r11 -> VAR_HUI
        mov.b   @r11,r0
        extu.b  r0,r0
        mov     r0,r1               ! region entry = hg_regions + idx * 12
        shll2   r1
        mov     r1,r0
        add     r1,r1
        add     r0,r1
        mov.l   LU_regs,r0
        add     r0,r1
        mov.l   @r1,r8              ! ROM address
        mov.w   @(8,r1),r0
        extu.w  r0,r9               ! w
        mov.w   @(10,r1),r0
        extu.w  r0,r10              ! h
        mov.w   @(2,r11),r0
        extu.w  r0,r2               ! row
        mov     #0,r3               ! rows this chunk: as many as fit
        mov     #0,r4
        mov.w   WU_chunk,r5
.Lu_fit:
        add     r9,r4
        cmp/hi  r5,r4
        bt      .Lu_fitd
        bra     .Lu_fit
        add     #1,r3
.Lu_fitd:
        mov     r10,r0
        sub     r2,r0               ! rows left
        cmp/hi  r0,r3
        bf      .Lu_n
        mov     r0,r3
.Lu_n:
        mov.l   LU_buf,r6           ! header (uncached)
        mov.w   WU_c000,r0
        mov.w   r0,@r6
        mov     #0,r0
        mov.w   r0,@(2,r6)
        mov.w   WU_2000,r0
        mov.w   r0,@(4,r6)
        mov     #0,r0
        mov.w   r0,@(6,r6)
        mov.w   WU_9999,r0
        mov.w   r0,@(8,r6)
        mov.w   r0,@(10,r6)
        mov.w   @(4,r1),r0          ! dest x
        mov.w   r0,@(12,r6)
        mov.w   @(6,r1),r0          ! dest y + row
        add     r2,r0
        mov.w   r0,@(14,r6)
        mov     r9,r0
        add     #-1,r0
        mov.w   r0,@(16,r6)
        mov     r3,r0
        add     #-1,r0
        mov.w   r0,@(18,r6)
        mov     r6,r7               ! pixels: copy w * rows words (as longs)
        add     #20,r7
        mov     r2,r0               ! source = ROM + row * w * 2
        mulu.w  r9,r0
        sts     macl,r0
        add     r0,r0
        add     r0,r8
        mov     r9,r0
        mulu.w  r3,r0
        sts     macl,r4
        shlr    r4                  ! longs
.Lu_cp:
        mov.l   @r8+,r0
        mov.l   r0,@r7
        dt      r4
        bf/s    .Lu_cp
        add     #4,r7
        mov     #0,r0
        mov.l   r0,@r7              ! end of list
        add     r3,r2               ! next row / region
        cmp/hs  r10,r2
        bf      .Lu_st
        mov.b   @r11,r0
        add     #1,r0
        mov.b   r0,@r11
        mov     #0,r2
.Lu_st:
        mov     r2,r0
        mov.w   r0,@(2,r11)
        mov.l   LU_run,r1
        jsr     @r1
        mov     r6,r0
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 1
WU_chunk:   .word HG_CHUNK
WU_c000:    .word 0xC000
WU_2000:    .word 0x2000
WU_9999:    .word 0x9999
        .align 2
LU_hui:     .long VAR_HUI
LU_regs:    .long hg_regions
LU_buf:     .long hg_ubuf + 0xA0000000
LU_run:     .long blt_run


! hg_puffs (hg_logic, shot alive; r10 -> VAR_BX..): the launch cloud. Puffs
! age and vanish after HG_PLIFE frames; while the shot flies (first
! HG_PSPAWN frames) a new one is made every other frame at the head, up to
! 12 px either side. Uses r0-r7.
hg_puffage:                         ! (once a frame) puffs age, vanish after HG_PLIFE
        mov.l   LF_puff,r1
        mov     #HG_NPUFF,r2
.Lpf_age:
        mov.b   @(4,r1),r0
        extu.b  r0,r0
        tst     r0,r0
        bt      .Lpf_an
        add     #1,r0
        mov     #HG_PLIFE,r3
        cmp/hs  r3,r0
        bf      .Lpf_as
        mov     #0,r0
.Lpf_as:
        mov.b   r0,@(4,r1)
.Lpf_an:
        dt      r2
        bf/s    .Lpf_age
        add     #8,r1
        rts
        nop
hg_puffs:                           ! (per shot, r10 -> slot) new puffs at the head
        mov.l   @(16,r10),r0        ! only while flying
        tst     r0,r0
        bf      .Lpf_out
        mov.w   @(24,r10),r0
        extu.w  r0,r0
        mov     #HG_PSPAWN,r3
        cmp/hs  r3,r0
        bt      .Lpf_out
        mov.l   LF_puff,r1          ! a free puff
        mov     #HG_NPUFF,r2
.Lpf_free:
        mov.b   @(4,r1),r0
        tst     r0,r0
        bt      .Lpf_new
        dt      r2
        bf/s    .Lpf_free
        add     #8,r1
        bra     .Lpf_out
        nop
.Lpf_new:
        mov.l   @(8,r10),r0         ! head up
        shlr16  r0
        mov.w   r0,@r1
        mov.l   LF_rnd,r3           ! across: head + (random 0..24) - 12
        mov.l   @r3,r0
        mov.l   LF_mul,r4
        mul.l   r4,r0
        sts     macl,r0
        add     #57,r0
        mov.l   r0,@r3
        shlr16  r0
        mov     r0,r4
        mov     #33,r5
        mulu.w  r5,r4
        sts     macl,r4
        shlr16  r4                  ! 0..32
        add     #-16,r4
        mov.l   @(12,r10),r0
        shlr16  r0
        add     r4,r0
        mov.w   r0,@(2,r1)
        mov     #1,r0
        mov.b   r0,@(4,r1)
.Lpf_out:
        rts
        nop
        .align 2
LF_puff:    .long VAR_PUFF
LF_rnd:     .long VAR_PUFF + HG_NPUFF * 8
LF_mul:     .long 1103515245

        .endif

        .ifndef STANDALONE
        .align 2
hg_ubuf:    .space  24 + HG_CHUNK * 2 + 8
        .endif
        .include "bar.inc"
        .include "labels.inc"
_end:

