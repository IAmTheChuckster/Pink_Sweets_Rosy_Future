---
name: pink-sweets-rosy-future-build
description: Build the whole Pink Sweets Rosy Future project from scratch (new project, nothing assumed): Rosy Future HUD and menu, ROSY'S ARRANGE mode, DIP menu item, Python and web patchers, MiSTer MRA, README, MAME 0.289 tests and GitHub release, from the user's own pinkswts and ibara dumps.
---

# Pink Sweets Rosy Future: build the project from scratch

Target repo: https://github.com/IAmTheChuckster/Pink_Sweets_Rosy_Future (private; moved from older names, GitHub redirects). Assume a clean machine and an empty or new repo: nothing from earlier sessions exists. Companion skills: `cv1000-patch-dev` (SH-3 patch method, house rules), `cv1000-learn-game` or `cv1k-learn-game-github` (MAME 0.289 setup, learn the game headlessly first), `pink-sweets-rosy-arrange-build` and `rosy-arrange-dev` (standalone Rosy Arrange: same code base, memory map). Load them before writing code. This skill is the end-to-end order of work, the file layout, the rules and every trap met so far.

## 1. Inputs from the user (never store, commit or share ROM data)
- `pinkswts.zip`: original Pink Sweets (Ibara Sorekara, Japan, 2006/04/06 MASTER VER.), CV1000-B. u4 must be 2 MB with CRC32 `5d812c9e`. Reject a zip whose u4 CRC differs. u2 `a2fa5363`, u23 `4b82d250`, u24 `e93f0627` stay unchanged.
- `ibara.zip`: MAME set `ibarao`. Its u2 is 138412032 bytes, CRC32 `55840976`. ROSY'S ARRANGE's HADOUGUN sprites are copied from it at patch time (only a few frames; nothing from Ibara is stored in the repo).
- GitHub push access to the repo (use the `add_repo` tool with push access; do not pre-check with curl or gh). Repo contains only source, tools and notes.

## 2. Standing rules (the user's house rules)
- No ROM data in the repo, README, patchers or MRA. Patchers embed only our own code as byte runs plus verification CRCs.
- MAME 0.289 only. Patchers: a Python stdlib-only script and a single-file web page. No xdelta.
- Update the README with every change. Do not edit the user's "To Do" list. `git pull --rebase` before committing, push to `main`, commit messages end with the attribution trailers from the session's system reminder.
- Work in small steps, say in plain words what you are doing, show screenshots or results, offer rollback, and stop immediately when the user interrupts. Never push a half-finished state: build, both patchers, README, MRA and CRCs must all match the same u4.
- Naming: MRA `mister/Pink Sweets Rosy Future.mra` (spaces, not underscores), setname `pinkswtsrf`, zip `pinkswtsrf.zip`, program file `pinkswtsrf_u4`, MRA footer `2026/11/7 ROSY FUTURE`, MRA lists the u4 twice (undecoded-A21 mirror) and DDR3 before index 0.
- Use `git checkout`-style rollback only on your own uncommitted work, and save a `git diff` patch first.

## 3. What the project contains
Layers, all SH-3 (big-endian in MAME memory, little-endian byte-swapped inside the u4 file):
1. **Rosy Future base** (u4 CRC `2b1d0fb1`): code at u4 `0x100000` (reference copy `arrange/data/rosy_future_hud.bin`) plus patches applied to the unpacked game program. The game program is LZ-compressed in u4 at `0x51000`; the patcher unpacks, patches (`PROGRAM` list: address, new bytes, expected old bytes), repacks (takes about a minute; `pack()` is a greedy/DP LZ with window 2047, length 3..34). Features: ZAN counter (starts 2500, kills lower, bomb kills raise, READY at 0, back to 2500 after the extend item), boss/midboss timer with one decimal and boss health (stages 1 to 7), RK rank meter in place of 2P score (starts 18.75, 100.00 hardest), title menu ARCADE / HARDER / EXTENDED / SCORE ATTACK / ROSY'S ARRANGE after a coin (menu two rows higher, blank row before PRESS START, Harder/Extended/Score Attack unlocked), 9-digit high-score table, warning screen (unofficial, not affiliated with CAVE, then HAVE FUN!!!), title footer NOT FOR SALE, HUD layout per mode (ZAN under RK for Arcade/Harder/Extended; none for Score Attack; ZAN/timer/rank removed and 2P score restored for 2 players).
2. **ROSY'S ARRANGE** (`arrange/src/arrange.s`): linked at RAM `0x0C7C0000`, stored at u4 `0x101000`, copied to RAM at boot by `boot_patch` through the boot hook (literal at u4 `0x18C` redirected, `DECOMP` = `0x0C002AC4`). 1-player Pink Sweets Rosy Arrange rules and HUD (TYPE, RANK, rose cracker meter filled by tick points and shield cancels, weak/full cracker with a 2-second cooldown, flower chain, D or Start changes shot type), own How to Play page, HADOUGUN stock (start 1, +1 per death, max 4, icons lower right; B tap fires cracker, hold B for 1/4 s swings the options and grows aim lines, full after 1 s). Mode-specific code swaps in and out at run time (`TOGGLES`, `mode_apply`; `COMBO_PATCHES` are the swapped-in patches).
3. **DIP SWITCH SETTING item "rosy's arrange extends"** (item 19): same options as "extend" (0 NO EXTRA, 1..9 = 1000000p..9000000p each, 10..18 = "... only"), default 1 (1000000p each), used only by ROSY'S ARRANGE; the other four modes keep the original extend. See section 6.
4. **Tooling**: `arrange/build.py`, `arrange/tools/mame/` (`harness.lua`, `dip.lua`, schedules), `pinkswts_patch.py`, `index.html`, `mister/*.mra`, READMEs, this skill.

## 4. Repo layout
```
README.md  index.html  pinkswts_patch.py  .nojekyll
mister/Pink Sweets Rosy Future.mra
arrange/{README.md, build.py, src/arrange.s, data/{hadougun.gif, popup_x.bin, rosy_future_hud.bin}, tools/mame/}
skills/pink-sweets-rosy-future-build/SKILL.md
```
Add a `.gitignore` for `__pycache__/` (compiled `.pyc` files were committed by accident once).

## 5. Order of work for a new project
1. **Set up**: unzip the user's sets to a work dir; verify every CRC above; install `binutils-sh-elf` (`sh-elf-as`, `sh-elf-ld`, `sh-elf-objdump -D -b binary -m sh3 -EB --adjust-vma=ADDR` for disassembly), Pillow, and a MAME 0.289 build for cv1k (`pinkswts` driver; roms dir with u2, u23, u24 plus the u4 under test). Clone/init the repo.
2. **Learn the game** headlessly (cv1000-learn-game): boot, menus, how the unpacked program sits at `0x0C000000`, where score, lives, rank (`0x0C453AB0`), real-play flag (`0x0C4535F7`), enemy table (`0x0C416968` x192, stride `0xCC`, HP +0x44), P1 struct (`0x0C49C5DC`) live.
3. **Rosy Future base**: build the HUD code and title menu, write the `PROGRAM` patch table and `HOOK_CODE` at u4 `0x100000`, repack, confirm CRC `2b1d0fb1`. Patch size must stay <= `0x20000`; variables live at `0x0C7E0000..0x0C7E01FF` (zeroed at boot); symbol patches need a 4-aligned address.
4. **ROSY'S ARRANGE**: write `arrange.s`, then build with the HADOUGUN graphics:  
   `IBARA_U2=<path to ibara u2> python3 arrange/build.py <rf_u4> <out_u4>`  
   Without `IBARA_U2` the build leaves those regions unfilled and its CRC will NOT match the patchers' output (this cost a debugging round). The build prints the CRC, code range, symbols and `IBARA_FILL` rows (u4 offset, u2 offset, bytes per row, rows).
5. **DIP item** (section 6).
6. **Test in MAME** (section 7).
7. **Patchers**: regenerate whenever the u4 changes (section 8).
8. **README, MRA, CRCs**, then commit and push (section 9). Send the user the new `pinkswtsrf_u4` and MRA with a short summary.

## 6. DIP menu internals (for adding or changing items)
- Menu rows and tables in the unpacked program: row table `0x0C105A9C + item`, fixed labels `0x0C105CE4 + 8*n`, option-count table `0x0C105AB0 + item` (max value; extend is 18), cursor-order table `0x0C105AEC + 0x28*t` (up at +item, down at +20+item, one block per screen state t = 0..8), variable pointer table `dip_varptr` at `0x0C066778` (20 entries), the player-counts line call at `0x0C0667B0` (wrapped by `arr_dip_wrap` to draw the extra item), game print routine `0x0C062980`, number print `0x0C075AF0`.
- Layout used: the label "rosy's arrange extends" on its own row and the value on the row below (label too long for one row); rows below move down (player counts 9, ranking save 7, load default 5, save 3, exit 1).
- The value is stored in the game's EEPROM buffer byte `0x0C3AE487` directly. Storing it in the settings variable block (`0x0C3B0A8A` or `0x0C3B0A97`) does NOT persist: the game's save does not copy those into the EEPROM buffer. A blank/invalid value (>18) is read as 1.
- ROSY'S ARRANGE reads it each title frame in `arr_effext` and writes the extend score into `[0x0C5C009C]` and `[0x0C4AFAF0]` (the game's extend init is not run at game start). 1000000p each = `0x000F4240`; 3 gave `0x002DC6C0`. Other modes use the DIP "extend" at `0x0C3B0A7C`.
- "load default setting" does NOT reset the new item (decided with the user: change it by hand). Callers of the game's default routine `0x0C069C20` are `0x0C066C36` (copy buffer to live), `0x0C0670A0` (boot EEPROM load) and `0x0C06A4EA` (power-on init: default, copy to buffer); none of the first two hooks fired from the menu in headless tests. An unconditional hook resets the saved value at power-on because the game calls defaults at boot.
- Assembler traps: `bsr` to far routines overflows 12 bits (use `mov.l label,r0 / jsr @r0`); keep literal pools per routine within pc-relative range ("negative offset, pcrel too far" otherwise); never rename a label globally when two routines share it (use unique prefixes such as `LZ_`, `LT_`, `LD_`); watch for `MISALIGN` lines in the build output.

## 7. MAME testing
- Run headless: `mame pinkswts -rompath <dir> -cfg_directory <fresh dir> -nvram_directory <dir> -video none -sound none -nothrottle -seconds_to_run N -autoboot_script script.lua`. Only one `-autoboot_script` is honored: concatenate Lua files if you need two.
- MAME persists DSW state in `cfg/pinkswts.cfg`; a stale file boots straight into the test menu. Always use a fresh `-cfg_directory`.
- `arrange/tools/mame/dip.lua` takes `SCHED=<file>` lines `<frame> <tokens>` (U D L R A B S K = joystick, buttons, Start, Coin; `X` = hold the service/test switch; set `USEX=1` to use X), `SNAPS="frame frame ..."` for screenshots, and logs key memory every 40 frames to `/tmp/memlog.txt`. Hold a coin about 6 frames (longer gives COIN ERROR). Schedules in `arrange/tools/mame/schedules/` start each mode (`bootarr.txt` = ROSY'S ARRANGE, `boot_m0..3` = other modes).
- The DIP test menu: with X held, D steps down the rows, L/R change a value; A, B, Start and K on "load default setting" did nothing in tests.
- MAME is not frame-deterministic (RTC): retry flaky runs, compare trends not exact frames. Memory reads from Lua are big-endian when you unpack dumps (`'>I'`).
- Regression checklist: all five title modes start; non-Arrange modes unchanged; ZAN/timer/health/RK appear; HADOUGUN works; fresh EEPROM gives item 19 = 1 and extend 1,000,000 in ROSY'S ARRANGE; saved value (for example 3) survives a reboot; no crash over several minutes (one rare crash about 40 s into stage 1 was seen and not reproduced).

## 8. Regenerating the patchers (every time the u4 changes)
1. Build with `IBARA_U2` set (section 5.4) and note the CRC.
2. Diff the Rosy Future base against the new u4 outside the `IBARA_FILL` regions, merging runs with gaps of 8 bytes or less. Each run becomes `[offset, base64]`: that list is `EXTRA` in `pinkswts_patch.py` and `extra` in the `const PATCH = {...}` JSON in `index.html` (keys: program, hook, extra). Unchanged: `PROGRAM`, `HOOK_CODE`, `IBARA_FILL`.
3. Replace the old CRC everywhere: `PATCHED_CRC` in both patchers, docstring, the MRA string (JSON-escaped in both patchers, two `u4` part lines), README table, `arrange/README.md`, `mister/*.mra`.
4. Verify: run `python3 pinkswts_patch.py pinkswts.zip ibara.zip -o out` and `cmp` against the build (must be identical); open `index.html` with Playwright (Chromium is installed) and check "Matches" with the new CRC and the four download links; confirm the Python-embedded MRA equals the file in `mister/`.
5. Never use a `pinkswts.zip` whose u4 has the wrong CRC for these checks.

## 9. Publish
`git status` (no `.pyc`), `git pull --rebase origin main`, commit, `git push origin main`, `git fetch` and confirm `origin/main` equals HEAD. Then send the user `pinkswtsrf_u4` and the MRA. Remind them: MAME warns about the u4 checksum (rename to `pinkswts_u4` in a `pinkswts` set), keep a backup of the original u4 before flashing a real board, GitHub Support must be asked to purge old commits if anything was ever committed that should not have been.

## 10. Open items and decisions to carry over
- HADOUGUN needs more investigation (the user will resume after getting credits).
- The sound replacement (Ibara 5a) is on hold: do not change audio unasked.
- Rare crash about 40 s into stage 1 (crash #3) not reproduced.
- Possible double music on MiSTer at stage 5 after weak crackers: suspected core timing, the user chose no change.
- The README's "To Do" list and "## Skills" section belong to the user; the Skills section links this file.
