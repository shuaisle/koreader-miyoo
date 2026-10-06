--[[--
Miyoo Mini V4 keymap: evdev keycodes -> KOReader events.

Based on the community-verified Miyoo keymap (Allium launcher / Onion OS):
    A=KEY_SPACE(57)  B=KEY_LEFTCTRL(29)  X=KEY_LEFTSHIFT(42)  Y=KEY_LEFTALT(56)
    Start=KEY_ENTER(28)  Menu=KEY_ESC(1)  Select=KEY_RIGHTCTRL(97)
    L2=KEY_TAB(15)  R2=KEY_BACKSPACE(14)
    D-Pad=KEY_UP(103)/KEY_DOWN(108)/KEY_LEFT(105)/KEY_RIGHT(106)

A runtime override lives in koreader/settings/event_map.lua (merged on top
of this table at startup); ship the same mapping there so users can tweak
keys without rebuilding.

Extra letter-key candidates (KEY_A=30, KEY_B=48, KEY_X=45, KEY_Y=44,
KEY_POWER=116) cover SigmaStar boards whose gpio-keys may report those
codes instead; they are inert if never delivered.
--]]
return {
    -- D-Pad
    [103] = "Up",      -- KEY_UP
    [108] = "Down",    -- KEY_DOWN
    [105] = "Left",    -- KEY_LEFT
    [106] = "Right",   -- KEY_RIGHT

    -- A / B (confirm / back)
    [57]  = "Press",   -- KEY_SPACE (A)
    [29]  = "Back",    -- KEY_LEFTCTRL (B)

    -- X / Y
    [42]  = "Menu",    -- KEY_LEFTSHIFT (X) -> main menu
    [56]  = "ToggleScreenSaver", -- KEY_LEFTALT (Y)

    -- Start / Menu / Select
    [28]  = "Press",   -- KEY_ENTER (Start) -> confirm
    [1]   = "Menu",    -- KEY_ESC (Menu button) -> main menu
    [97]  = "Back",    -- KEY_RIGHTCTRL (Select) -> back

    -- Shoulder buttons: page up / page down
    [15]  = "RPgBack", -- KEY_TAB (L2)
    [14]  = "RPgFwd",  -- KEY_BACKSPACE (R2)

    -- SigmaStar letter-key candidates (inert if unused)
    [30]  = "Press",   -- KEY_A
    [48]  = "Back",    -- KEY_B
    [45]  = "Menu",    -- KEY_X
    [44]  = "ToggleScreenSaver", -- KEY_Y
    [116] = "Menu",    -- KEY_POWER
}
