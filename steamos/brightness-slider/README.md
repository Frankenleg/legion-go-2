# Brightness slider fix for the Legion Go 2 OLED on SteamOS

On the Lenovo Legion Go 2 OLED, the brightness slider in SteamOS Game Mode
does nothing. This fix makes it work again. It adds one small settings file to
your home folder, needs no password or root access, and does not use Decky.

## Is this for you?

- You have a Lenovo Legion Go 2 with the OLED screen.
- You run SteamOS.
- Moving the brightness slider in Game Mode does not change the screen.

If your SteamOS already has gamescope 3.16.29 or later, you don't need this
fix. The installer checks and tells you.

## Trade-off

While this fix is installed, HDR games show standard (SDR) picture quality
instead of HDR. Uninstall it any time to go back.

## Option 1: quick install

You need an internet connection. It takes a few minutes.

1. **Switch to Desktop Mode.** Press the Steam button, choose **Power**, then
   choose **Switch to Desktop**.
2. **Open this page in a web browser** on the handheld, so you can copy the
   command in step 4.
3. **Open Konsole.** Click the app menu in the bottom-left corner of the
   screen, choose **System**, then **Konsole**.
4. **Copy this command:**

   ```bash
   curl -fsSL https://raw.githubusercontent.com/Frankenleg/legion-go-2/brightness-slider-v1.0.0/steamos/brightness-slider/install.sh | bash
   ```

5. **Paste it into Konsole** with **Ctrl+Shift+V**, or right-click inside
   Konsole and choose **Paste**. Then press **Enter**.
6. **Read the message.** `Installed the brightness-slider profile` means the
   fix is in place. If it says `Not installed:`, the rest of the message says
   why, and nothing was changed.
7. **Return to Game Mode.** Double-click **Return to Gaming Mode** on the
   desktop.
8. **Try the slider.** Open the Quick Access menu and move the brightness
   slider. The screen should get brighter and darker.

Tip: to type without a keyboard in Desktop Mode, press **Steam + X** to show
the on-screen keyboard.

The installer is a short script you can read first: [install.sh](install.sh).
It checks that it is running on SteamOS on a Legion Go 2 OLED that still
needs the fix before it changes anything.

## Option 2: manual install

No terminal needed.

1. Switch to Desktop Mode (step 1 above).
2. In a web browser, open
   [the profile file](https://github.com/Frankenleg/legion-go-2/raw/brightness-slider-v1.0.0/steamos/brightness-slider/lenovo.legiongo2.oled.lua)
   and save it with **Ctrl+S**. Keep the name `lenovo.legiongo2.oled.lua`.
3. Open the **Dolphin** file manager and go to your home folder. Press
   **Ctrl+H** to show hidden folders.
4. Open `.config`. If there is no `gamescope` folder, create it: right-click,
   choose **Create New**, then **Folder**. Open `gamescope`, and in the same
   way create and open a folder named `scripts`.
5. Move the file you saved into `scripts`. Its full path is
   `~/.config/gamescope/scripts/lenovo.legiongo2.oled.lua`.
6. Double-click **Return to Gaming Mode** on the desktop and try the slider.

## Check that it worked

In Desktop Mode, after Game Mode has started at least once with the fix
installed, run this in Konsole:

```bash
journalctl -b -t gamescope-session | grep -q "Matched vendor: SDC product: 0x4301" && echo "working" || echo "not active yet"
```

- `working`: the fix was active the last time Game Mode started.
- `not active yet`: Game Mode has not started with the fix since the handheld
  was turned on. Return to Game Mode once, then check again. If it still says
  `not active yet`, check that the file is at
  `~/.config/gamescope/scripts/lenovo.legiongo2.oled.lua`.

## Uninstall

If you used Option 1, run this in Konsole in Desktop Mode, then double-click
**Return to Gaming Mode**:

```bash
curl -fsSL https://raw.githubusercontent.com/Frankenleg/legion-go-2/brightness-slider-v1.0.0/steamos/brightness-slider/uninstall.sh | bash
```

If you used Option 2, delete
`~/.config/gamescope/scripts/lenovo.legiongo2.oled.lua` in Dolphin, then
return to Game Mode.

If the installer replaced an earlier file, it kept a copy beside it named
`lenovo.legiongo2.oled.lua.bak-<date>`.

## When SteamOS gets gamescope 3.16.29

gamescope 3.16.29 includes Valve's own profile for this screen, which also
keeps real HDR in HDR games. Once a SteamOS update brings it, this fix steps
aside by itself, and you can uninstall it. To see your version, run
`pacman -Q gamescope` in Konsole.

## How it works

gamescope 3.16.23.6, the version in stable SteamOS 3.8, has no profile for
this screen. It follows the screen's EDID, which advertises HDR (PQ), and
drives the screen with a PQ signal. In PQ mode the screen ignores its
backlight, so the slider has no effect. This fix is a gamescope display
profile, [lenovo.legiongo2.oled.lua](lenovo.legiongo2.oled.lua), that
declares the screen as gamma 2.2, as Valve's Steam Deck OLED profile does.
That keeps the screen out of PQ mode, and the backlight follows the slider
again.

gamescope loads its own profiles first and user profiles from
`~/.config/gamescope/scripts/` afterwards. This profile checks whether
gamescope already has a Legion Go 2 profile and does nothing if it does.

Neither script uses `sudo` or root access.

Background:
[ValveSoftware/gamescope#2172](https://github.com/ValveSoftware/gamescope/issues/2172)
(the bug report) and
[ValveSoftware/gamescope#2148](https://github.com/ValveSoftware/gamescope/pull/2148)
(Valve's change in gamescope 3.16.29).
