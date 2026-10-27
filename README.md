# Pink Sweets Forever

## Bugs
1. investigate a possible bug with kasumi where it stopped in the Ruins but the song kept playing for a bit then the song stopped
2. expand highscore to 9 digits

## To Do
1. update warning page
2. update title page and separate the press start from the rest
3. update title page and remove sale by ami
4. Update MRA files to include button names
5. **All:** update HUD and make the boss health as a bar and explore rank and timer placements
6. **All** draw a transparent box around the boss health
7. **Arrange:** suck in medals when holding focus more than 2 seconds
8. **Arrange:** tweak rank, 1up adds 5, dying subtracks 3
9. **Arrange:** extends the same as dipsw
10. **Arrange:** drop lipstick for extend score
11. **Arrange:** increase volume for medals that are collected
12. **Arrange:** add big boss's hadougun
13. **Arrange:** dying adds hadougun
14. **Arrange:** holding bomb for more than 2 seconds hadougun, releasing the button shoots it
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
  - ROSY'S ARRANGE plays **Pink Sweets Rosy Arrange** (1 player): Start goes to its own How to Play page, then the usual character select. It uses the Rosy Arrange rules and HUD (TYPE, RANK, rose cracker meter that fills from tick-points and shield cancels, weak/full rose cracker with a 2-second cooldown, flower chain, D or Start to change shot type). See the [Rosy Arrange README](https://github.com/IAmTheChuckster/Pink-Sweets-Rosy-Arrange) for the full rules. The other four modes play exactly as before.
  - Move the arrow with the joystick and press Start.
  - Harder, Extended and Score Attack are unlocked, so the button codes aren't needed.
- **HUD layout.**
  - Arcade, Harder and Extended: ZAN sits under RK on the right, with the boss timer and health under it in place of the credit message.
  - Score Attack: no extra HUD, the game's own display is left as it is.
  - 2 players: ZAN, the boss timer and the rank meter are removed and the 2P score comes back.
- **Warning screen.** Shows `PINK SWEETS ROSY FUTURE` and `CAVE OWNS!!!`, with `2026/10/15 ROSY FUTURE` at the bottom.

## Patching the game

| | CRC32 |
|---|---|
| Original `pinkswts_u4` (required) | `5d812c9e` |
| Patched `pinkswtsfe_u4` | `1d5f4e62` |

Only the u4 changes: the patched program is saved as `pinkswtsfe_u4` in `pinkswtsfe.zip`. `pinkswts_u2`, `u23` and `u24` stay as they are. For MiSTer (ikacore CV1k), use `pinkswtsfe.zip` with `Pink Sweets Forever.mra` (in [`mister/`](mister/), also offered by both patchers).

### Web patcher

Open the **[Pink Sweets Forever Patcher](https://iamthechuckster.github.io/Pink_Sweets_Forever/)** and drop in `pinkswts.zip` (the 4 files only, no subfolders). You can also drop a loose `pinkswts_u4`.

The page checks that `pinkswts_u4` is the original and that the result is `1d5f4e62` before offering `pinkswtsfe.zip` (full set with the patched `pinkswtsfe_u4`), `pinkswtsfe_u4.zip`, the raw `pinkswtsfe_u4` and `Pink Sweets Forever.mra`. Everything runs in your browser and nothing is uploaded.

### Python patcher

Python 3, standard library only. Repacking the game program takes about a minute.

```
python3 pinkswts_patch.py pinkswts.zip          # writes pinkswtsfe_u4 next to the zip
python3 pinkswts_patch.py pinkswts.zip --zip    # also writes pinkswtsfe.zip and Pink Sweets Forever.mra
python3 pinkswts_patch.py pinkswts_u4           # patches a loose file -> pinkswtsfe_u4
python3 pinkswts_patch.py pinkswts.zip -o OUT   # choose the output file
```

MAME will warn about a wrong checksum for the u4 (rename `pinkswtsfe_u4` to `pinkswts_u4` in a `pinkswts` set for MAME). That's expected. On real hardware, keep a backup of your original u4 before flashing.

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
