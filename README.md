# Pink Sweets Rosy Future

## To Do
15. add skills

A patch for **Pink Sweets: Ibara Sorekara** (2006/04/06 MASTER VER....)<br>
This repository holds only source, tools and notes. **No ROM data is included**; you patch your own legally owned dump.

## About this project
Why did I make this? Because it's fun and for my own personal research to see the capabilities of Claude.<br>
While Claude was used I put effort in making sure there are balanced gameplay.<br>
I did all the testing and planning.

## Patch Notes

- **ZAN counter.** Shows the hidden 1UP counter. It starts at 2500, kills lower it and bomb kills raise it again. At 0 it shows **READY**, and it goes back to 2500 after the extra life item appears.
- **Boss and midboss timer.** Shows the seconds left in every boss and midboss fight from stage 1 to stage 7, with one decimal. It only appears during those fights.
- **Boss health.** Shown under the timer and counts down as the enemy takes damage.
- **Rank meter.** Shows the hidden rank as **RK** with two decimals in place of the 2P score, for example `RK  19.37`. 100.00 is the hardest and the game starts at 18.75.
- **Title menu.** After a coin is inserted, the title shows **ARCADE / HARDER / EXTENDED / SCORE ATTACK / ROSY'S ARRANGE**.
  - ROSY'S ARRANGE plays **Pink Sweets Rosy Arrange** (1 player): Start goes to its own How to Play page, then the usual character select. It uses the Rosy Arrange rules and HUD (TYPE, RANK, rose cracker meter that fills from tick-points and shield cancels, weak/full rose cracker with a 2-second cooldown, flower chain, D or Start to change shot type). Differences from the standalone Rosy Arrange: extends follow the DIP setting (a lipstick 1UP drops from the top at each extend score), each extend raises RANK by 5, each death lowers it by 3, and the cracker flowers' pickup sound is 50% louder. See the [Rosy Arrange README](https://github.com/IAmTheChuckster/Pink-Sweets-Rosy-Arrange) for the full rules. In ROSY'S ARRANGE the boss/midboss timer sits in the top right under the RANK value, with the boss health shown as a bar under it (white outline; green above 30 health, yellow from 30, red at 15 and below, with the remaining health counting down 15 ... 1 inside the bar); it refills for each new phase. The other four modes play exactly as before.
  - Move the arrow with the joystick and press Start. The menu and **PRESS START** sit higher on the screen (blank row between them), clear of the countdown.
  - Harder, Extended and Score Attack are unlocked, so the button codes aren't needed.
- **HUD layout.**
  - Arcade, Harder and Extended: ZAN sits under RK on the right, with the boss timer and health under it in place of the credit message.
  - Score Attack: no extra HUD, the game's own display is left as it is.
  - 2 players: ZAN, the boss timer and the rank meter are removed and the 2P score comes back.
- **HADOUGUN (ROSY'S ARRANGE).** You start with 1 (shown as icons in the lower right), each death adds 1, up to 4. With HADOUGUN in stock, a quick tap of B (let go within 1/4 second) fires the rose cracker as you let go; hold B longer and no cracker fires: your two options swing in front of the ship (ready after 1 second of holding) while dotted aim lines grow from them. With none in stock, B fires the cracker the moment you press it, as before. Let go after that and the HADOUGUN flies straight up, leaving a red trail that stays for about 15 seconds (slowly fading) and damages enemies and cancels bullets the whole time; a bright white cloud of smoke rises with it, and the shot sticks to the first enemy it hits as a red ball that keeps damaging it for up to 15 seconds, fading out at the end or when the enemy is destroyed. Let go earlier and the options go back to your sides. Each shot uses one; with none left the options are gone until a death gives you one back. The HADOUGUN graphics come from your Ibara set (see below).
- **High scores.** The ranking table shows all 9 digits of the score (was 8), in every mode.
- **Warning screen.** A notice that this project is unofficial and not affiliated with, endorsed by or authorized by CAVE, then `HAVE FUN!!!`, with `2026/10/30 ROSY FUTURE` at the bottom.
- **Title footer.** `SALE BY AMI` is replaced by `NOT FOR SALE`.

## Patching the game

| | CRC32 |
|---|---|
| Original `pinkswts_u4` (required) | `5d812c9e` |
| Ibara `u2` from `ibara.zip` (MAME set `ibarao`, required) | `55840976` |
| Patched `pinkswtsrf_u4` | `b89e6b16` |

Both your `pinkswts.zip` and your `ibara.zip` are needed: the HADOUGUN graphics are read from Ibara's `u2` while patching (only the few sprite frames it uses; nothing from Ibara is stored in this repository). Only the u4 changes: the patched program is saved as `pinkswtsrf_u4` in `pinkswtsrf.zip`. `pinkswts_u2`, `u23` and `u24` stay as they are. For MiSTer (ikacore CV1k), use `pinkswtsrf.zip` with `Pink Sweets Rosy Future.mra` (in [`mister/`](mister/), also offered by both patchers).

### Web patcher

Open the **[Pink Sweets Forever Patcher](https://iamthechuckster.github.io/Pink_Sweets_Forever/)** and drop in `pinkswts.zip` and `ibara.zip` together (the sets' files only, no subfolders). Loose `pinkswts_u4` and Ibara `u2` files work too.

The page checks that `pinkswts_u4` is the original and that the result is `b89e6b16` before offering `pinkswtsrf.zip` (full set with the patched `pinkswtsrf_u4`), `pinkswtsrf_u4.zip`, the raw `pinkswtsrf_u4` and `Pink Sweets Rosy Future.mra`. Everything runs in your browser and nothing is uploaded.

### Python patcher

Python 3, standard library only. Repacking the game program takes about a minute.

```
python3 pinkswts_patch.py pinkswts.zip ibara.zip          # writes pinkswtsrf_u4 next to pinkswts.zip
python3 pinkswts_patch.py pinkswts.zip ibara.zip --zip    # also writes pinkswtsrf.zip and Pink Sweets Rosy Future.mra
python3 pinkswts_patch.py pinkswts_u4 u2                  # loose files (u2 = Ibara's) -> pinkswtsrf_u4
python3 pinkswts_patch.py pinkswts.zip ibara.zip -o OUT   # choose the output file
```

MAME will warn about a wrong checksum for the u4 (rename `pinkswtsrf_u4` to `pinkswts_u4` in a `pinkswts` set for MAME). That's expected. On real hardware, keep a backup of your original u4 before flashing.

## Testing
This patch was tested with MAME 0.289 and [CV1k core for the MiSTer FPGA by Raki](https://www.patreon.com/c/ikamusume/posts)<br>
It may even work on a PCB but do so on your own risk.

## Credits

- [IAmTheChuckster](https://github.com/IAmTheChuckster)  project, testing
- [Claude](https://claude.ai) (Anthropic)  reverse engineering and patcher code
- Tested on the CV1k core for the MiSTer FPGA by [Raki](https://www.patreon.com/c/ikamusume/posts)
- Rank research from the [shmups.wiki](https://shmups.wiki) Pink Sweets pages and from [Pink Sweets Suicide Club Rom Hack](https://suicideclub.gameordie.com/)

## Disclaimer

This repository contains a fan-made patch for research and technical analysis. The repository does not intentionally distribute the original game ROM, executable, or game assets. Users must obtain their own copy of the original game. This project is unofficial and is not affiliated with, endorsed by, or authorized by CAVE. All rights to the original game and its associated intellectual property remain with their respective rights holders. No license to third-party copyrighted material is granted by this repository.
