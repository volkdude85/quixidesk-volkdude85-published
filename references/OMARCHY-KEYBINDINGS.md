# Omarchy 4.x default keybindings

Harvested from `/usr/share/omarchy/default/hypr/bindings/*.lua` on a live Omarchy 4.0.1 /
Hyprland 0.56.2 installation. These are the DECLARED bindings; `hyprctl -j binds` reports the
live state but labels every Omarchy binding `__lua` with a numeric argument, so the Lua files are
the only source that carries a human description.

Total: 88

| keys | description | command | module |
|---|---|---|---|
| `SUPER + CTRL + V` | Clipboard manager | `omarchy-shell shell toggle omarchy.clipboard` | clipboard |
| `ALT + SHIFT + XF86AudioPlay` | Previous track | `omarchy-shell media previous` | media |
| `ALT + XF86AudioLowerVolume` | Volume down precise | `omarchy-audio-output-volume -1` | media |
| `ALT + XF86AudioPlay` | Next track | `omarchy-shell media next` | media |
| `ALT + XF86AudioRaiseVolume` | Volume up precise | `omarchy-audio-output-volume +1` | media |
| `ALT + XF86MonBrightnessDown` | Brightness down precise | `omarchy-brightness-display 1%-` | media |
| `ALT + XF86MonBrightnessUp` | Brightness up precise | `omarchy-brightness-display +1%` | media |
| `SHIFT + XF86AudioMute` | Switch audio output | `omarchy-audio-output-switch` | media |
| `SHIFT + XF86AudioPause` | Switch media source | `omarchy-audio-source-switch` | media |
| `SHIFT + XF86AudioPlay` | Switch media source | `omarchy-audio-source-switch` | media |
| `SHIFT + XF86MonBrightnessDown` | Brightness minimum | `omarchy-brightness-display 1%` | media |
| `SHIFT + XF86MonBrightnessUp` | Brightness maximum | `omarchy-brightness-display 100%` | media |
| `XF86AudioLowerVolume` | Volume down | `omarchy-audio-output-volume lower` | media |
| `XF86AudioMicMute` | Mute microphone | `omarchy-audio-input-mute` | media |
| `XF86AudioMute` | Mute | `omarchy-audio-output-volume mute-toggle` | media |
| `XF86AudioNext` | Next track | `omarchy-shell media next` | media |
| `XF86AudioPause` | Pause | `omarchy-shell media playPause` | media |
| `XF86AudioPlay` | Play | `omarchy-shell media playPause` | media |
| `XF86AudioPrev` | Previous track | `omarchy-shell media previous` | media |
| `XF86AudioRaiseVolume` | Volume up | `omarchy-audio-output-volume raise` | media |
| `XF86Eject` | Eject media | `eject` | media |
| `XF86KbdBrightnessDown` | Keyboard brightness down | `omarchy-brightness-keyboard down` | media |
| `XF86KbdBrightnessUp` | Keyboard brightness up | `omarchy-brightness-keyboard up` | media |
| `XF86KbdLightOnOff` | Keyboard backlight cycle | `omarchy-brightness-keyboard cycle` | media |
| `XF86MonBrightnessDown` | Brightness down | `omarchy-brightness-display 5%-` | media |
| `XF86MonBrightnessUp` | Brightness up | `omarchy-brightness-display +5%` | media |
| `XF86TouchpadOff` | Disable touchpad | `omarchy-toggle-touchpad off` | media |
| `XF86TouchpadOn` | Enable touchpad | `omarchy-toggle-touchpad on` | media |
| `CTRL + ALT + DELETE` | Close all windows | `omarchy-hyprland-window-close-all` | tiling |
| `SUPER + ALT + Home` | Save window width | `omarchy-hyprland-window-width save` | tiling |
| `SUPER + ALT + SLASH` | Monitor scaling down | `omarchy-hyprland-monitor-scaling down` | tiling |
| `SUPER + CTRL + F` | Tiled full screen | `omarchy-hyprland-window-tiled-fullscreen-toggle` | tiling |
| `SUPER + Home` | Restore window width | `omarchy-hyprland-window-width restore` | tiling |
| `SUPER + L` | Toggle workspace layout | `omarchy-hyprland-workspace-layout-toggle` | tiling |
| `SUPER + O` | Pop window out (float & pin) | `omarchy-hyprland-window-pop` | tiling |
| `SUPER + SLASH` | Monitor scaling up | `omarchy-hyprland-monitor-scaling up` | tiling |
| `ALT + PRINT` | Screenrecording | `omarchy-capture-screenrecording --stop-recording \|\| omarchy-menu toggle trigger.capture.screenrecord` | utilities |
| `PRINT` | Screenshot | `omarchy-capture-screenshot` | utilities |
| `SUPER + ALT + K` | Tmux keybindings | `omarchy-menu-tmux-keybindings` | utilities |
| `SUPER + ALT + SPACE` | Apps menu | `omarchy-menu toggle apps` | utilities |
| `SUPER + ALT + code:34` | Make webcam overlay smaller | `omarchy-capture-webcam-resize smaller` | utilities |
| `SUPER + ALT + code:35` | Make webcam overlay larger | `omarchy-capture-webcam-resize larger` | utilities |
| `SUPER + ALT + comma` | Invoke last notification | `omarchy-shell notifications invokeLast` | utilities |
| `SUPER + BACKSPACE` | Toggle window transparency | `omarchy-hyprland-window-transparency-toggle` | utilities |
| `SUPER + CTRL + A` | Audio | `omarchy-shell shell toggle omarchy.audio` | utilities |
| `SUPER + CTRL + ALT + B` | Show battery remaining | `omarchy-notification-battery` | utilities |
| `SUPER + CTRL + ALT + D` | Calendar | `omarchy-shell shell toggle omarchy.clock` | utilities |
| `SUPER + CTRL + ALT + Delete` | Toggle laptop display mirroring | `omarchy-hyprland-monitor-internal-mirror toggle` | utilities |
| `SUPER + CTRL + ALT + R` | Show reminders | `omarchy-reminder show` | utilities |
| `SUPER + CTRL + ALT + T` | Show time | `omarchy-notification-time` | utilities |
| `SUPER + CTRL + ALT + W` | Toggle weather | `omarchy-notification-weather` | utilities |
| `SUPER + CTRL + B` | Bluetooth | `omarchy-shell shell toggle omarchy.bluetooth` | utilities |
| `SUPER + CTRL + BACKSPACE` | Toggle single-window square aspect | `omarchy-hyprland-window-single-square-aspect-toggle` | utilities |
| `SUPER + CTRL + C` | Capture menu | `omarchy-menu toggle capture` | utilities |
| `SUPER + CTRL + D` | Display | `omarchy-shell shell toggle omarchy.monitor` | utilities |
| `SUPER + CTRL + Delete` | Toggle laptop display | `omarchy-hyprland-monitor-internal toggle` | utilities |
| `SUPER + CTRL + E` | Emojis | `omarchy-shell shell toggle omarchy.emojis` | utilities |
| `SUPER + CTRL + H` | Hardware menu | `omarchy-menu toggle hardware` | utilities |
| `SUPER + CTRL + K` | Herdr keybindings | `omarchy-menu-herdr-keybindings` | utilities |
| `SUPER + CTRL + L` | Lock system | `omarchy-system-lock` | utilities |
| `SUPER + CTRL + O` | Toggle menu | `omarchy-menu toggle toggle` | utilities |
| `SUPER + CTRL + P` | Power | `omarchy-shell shell toggle omarchy.power` | utilities |
| `SUPER + CTRL + PERIOD` | Transcode | `omarchy-transcode` | utilities |
| `SUPER + CTRL + PRINT` | Extract text (OCR) from screenshot | `omarchy-capture-text` | utilities |
| `SUPER + CTRL + Q` | Calculator | `omacalc` | utilities |
| `SUPER + CTRL + R` | Set reminder | `omarchy-menu toggle reminder-set` | utilities |
| `SUPER + CTRL + S` | Share | `omarchy-menu toggle share` | utilities |
| `SUPER + CTRL + SPACE` | Background switcher | `omarchy-menu toggle background` | utilities |
| `SUPER + CTRL + W` | Network | `omarchy-shell shell toggle omarchy.network` | utilities |
| `SUPER + ESCAPE` | System menu | `omarchy-menu toggle system` | utilities |
| `SUPER + K` | Keybindings | `omarchy-menu-keybindings` | utilities |
| `SUPER + PRINT` | Color picker | `pkill hyprpicker \|\| hyprpicker -a` | utilities |
| `SUPER + SHIFT + ALT + comma` | Open notification history | `omarchy-shell notifications showHistory` | utilities |
| `SUPER + SHIFT + BACKSPACE` | Toggle window gaps | `omarchy-hyprland-window-gaps-toggle` | utilities |
| `SUPER + SHIFT + CTRL + A` | Agent | `omarchy-agent --pick` | utilities |
| `SUPER + SHIFT + CTRL + R` | Clear reminders | `omarchy-reminder clear` | utilities |
| `SUPER + SHIFT + CTRL + SPACE` | Theme menu | `omarchy-menu toggle theme` | utilities |
| `SUPER + SHIFT + code:201` | Omarchy menu | `omarchy-menu toggle root` | utilities |
| `SUPER + SHIFT + comma` | Dismiss all notifications | `omarchy-shell notifications dismissAll` | utilities |
| `SUPER + SPACE` | Omarchy menu | `omarchy-menu toggle` | utilities |
| `SUPER + comma` | Dismiss last notification | `omarchy-shell notifications dismissOne` | utilities |
| `XF86Calculator` | Calculator | `omacalc` | utilities |
| `XF86PowerOff` | Power menu | `omarchy-menu toggle system` | utilities |
| `switch:off:Lid Switch` |  | `omarchy-hyprland-monitor-clamshell` | utilities |
| `switch:on:Lid Switch` |  | `omarchy-system-lid-close` | utilities |
| `F9` | Start dictation (push-to-talk) | `voxtype record start` | voxtype |
| `F9` | Stop dictation (push-to-talk) | `voxtype record stop` | voxtype |
| `SUPER + CTRL + X` | Toggle dictation | `voxtype record toggle` | voxtype |
