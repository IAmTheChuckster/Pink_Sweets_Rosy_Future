# ROSY'S ARRANGE source

Source for the ROSY'S ARRANGE mode (menu entry 5). No ROM data.

- `src/arrange.s` – SH-3 code, linked at RAM 0x0C7C0000, stored at u4 0x101000 and copied to RAM at boot (boot hook: literal at u4 0x18C).
- `build.py <Rosy Future u4 2b1d0fb1> <out>` – assembles it (needs sh-elf binutils) and writes the combined u4 (currently d435bd95). Rosy Arrange code changes that must only be active in this mode are swapped in and out at run time (`TOGGLES`, `mode_apply`).
- `data/rosy_future_hud.bin` – the Rosy Future code at u4 0x100000, used only to check the input.
- After a build, copy the changed byte runs (0x18C and 0x101000) into `EXTRA` in `../pinkswts_patch.py` and `"extra"` in `../index.html`, and update the CRC there, in the README and in the MRA.
- `tools/mame/` – headless MAME 0.289 test harness and input schedules (bootarr.txt = ROSY'S ARRANGE, boot_m0..3 = the other modes).
