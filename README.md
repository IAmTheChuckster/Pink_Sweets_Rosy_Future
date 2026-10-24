# Pink Sweets Rosy Future

A patch for **Pink Sweets: Ibara Sorekara** (2006/04/06 MASTER VER....)<br>
This repository holds only source, tools and notes. **No ROM data is included**; you patch your own legally owned dump.

## About this project
Why did I make this? Because it's fun and for my own personal research to see the capabilities of Claude.<br>
While Claude was used I put effort in making sure there are balanced gameplay.<br>
I did all the testing and planning.

## What it adds

- **ZAN counter.** Shows the hidden 1UP counter. It starts at 2500, kills lower it and bomb kills raise it again. At 0 it shows **READY**, and it goes back to 2500 after the extra life item appears.
- **Boss and midboss timer.** Shows the seconds left in every boss and midboss fight from stage 1 to stage 7, with one decimal. It only appears during those fights.
- **Boss health.** Shown under the timer and counts down as the enemy takes damage.
- **Rank meter.** Shows the hidden rank as **RK** with two decimals in place of the 2P score, for example `RK  19.37`. 100.00 is the hardest and the game starts at 18.75.
- **Title menu.** After a coin is inserted, the title shows **ARCADE / HARDER / EXTENDED / SCORE ATTACK / ROSY'S ARRANGE**.
  - ROSY'S ARRANGE is a placeholder for an upcoming mode; for now it plays as Arcade.
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
| Patched `pinkswts_u4` | `2b1d0fb1` |

Only `pinkswts_u4` changes. `pinkswts_u2`, `u23` and `u24` stay as they are.

### Web patcher

Open the **[Pink Sweets Rosy Future Patcher](https://iamthechuckster.github.io/Pink_Sweets_Rosy_Future/)** and drop in `pinkswts.zip` (the 4 files only, no subfolders). You can also drop a loose `pinkswts_u4`.

The page checks that `pinkswts_u4` is the original and that the result is `2b1d0fb1` before offering `pinkswts.zip` (full set with `pinkswts_u4` replaced), `pinkswts_u4.zip` or the raw `pinkswts_u4`. Everything runs in your browser and nothing is uploaded.

### Python patcher

Python 3, standard library only. Repacking the game program takes about a minute.

```
python3 pinkswts_patch.py pinkswts.zip          # writes pinkswts_u4 next to the zip
python3 pinkswts_patch.py pinkswts.zip --zip    # also writes pinkswts_patched.zip
python3 pinkswts_patch.py pinkswts_u4           # patches a loose file -> pinkswts_u4_patched
python3 pinkswts_patch.py pinkswts.zip -o OUT   # choose the output file
```

MAME will warn about a wrong checksum for `pinkswts_u4`. That's expected. On real hardware, keep a backup of your original u4 before flashing.

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
