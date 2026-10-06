--[[--
Miyoo Mini keymap: evdev keycodes -> KOReader events.

These are PLACEHOLDERS based on common Miyoo / gpio-keys conventions.
To get the real keycodes on your device:
  1. SSH into the Miyoo (Onion OS), run:  cat /proc/bus/input/devices
     -> note which eventX is the keypad and which keycodes it supports (bitmap).
  2. Run:  cat /dev/input/eventX | hexdump -C   (then press each button)
     -> each input_event is 24 bytes: type(2) code(2) value(4) ...
        code is the evdev keycode for the button you pressed.
  3. Update this file accordingly and re-run the build.

Common evdev keycodes (linux/input-event-codes.h):
  KEY_UP=103  KEY_DOWN=108  KEY_LEFT=105  KEY_RIGHT=106
  KEY_ENTER=28 (A)  KEY_ESC=1 (B)  KEY_TAB=15 (L1)  KEY_BACKSPACE=14 (R1)
  KEY_SPACE=57 (X)  KEY_LEFTSHIFT=42 (Y)  KEY_LEFTCTRL=29 (Select)
  KEY_LEFTALT=56 (Start)  KEY_POWER=116 (Menu/Power)
--]]
return {
    -- D-Pad
    [103] = "Up",      -- KEY_UP
    [108] = "Down",    -- KEY_DOWN
    [105] = "Left",    -- KEY_LEFT
    [106] = "Right",   -- KEY_RIGHT

    -- A / B (confirm / back)
    [28]  = "Press",   -- KEY_ENTER (A)
    [1]   = "Back",    -- KEY_ESC (B)

    -- Shoulder buttons: page up / page down
    [15]  = "RPgBack", -- KEY_TAB (L1)
    [14]  = "RPgFwd",  -- KEY_BACKSPACE (R1)

    -- X / Y
    [57]  = "Menu",    -- KEY_SPACE (X)
    [42]  = "Light",   -- KEY_LEFTSHIFT (Y)

    -- Start / Select
    [56]  = "ToggleScreenSaver", -- KEY_LEFTALT (Start)
    [29]  = "Light",   -- KEY_LEFTCTRL (Select)
}
