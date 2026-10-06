--[[--
KOReader custom keymap for Miyoo Mini V4 (SigmaStar SSD202D).

This file is merged over the built-in Miyoo keymap at startup, so only the
keys listed here take effect. Based on the community-verified Miyoo keymap
(Allium launcher / Onion OS, Miyoo Mini / Mini+ / Flip):

    A        = KEY_SPACE      (57)   confirm / "Press"
    B        = KEY_LEFTCTRL   (29)   back
    X        = KEY_LEFTSHIFT  (42)   main menu
    Y        = KEY_LEFTALT    (56)   toggle screensaver
    Start    = KEY_ENTER      (28)   confirm
    Menu     = KEY_ESC        (1)    main menu
    Select   = KEY_RIGHTCTRL  (97)   back
    L2       = KEY_TAB        (15)   page back
    R2       = KEY_BACKSPACE  (14)   page forward
    D-Pad    = KEY_UP/DOWN/LEFT/RIGHT (103/108/105/106)

Extra letter-key candidates are included as a fallback for SigmaStar boards
whose gpio-keys may report KEY_A/KEY_B/KEY_X/KEY_Y instead of the modifier
codes above. They are inert if those codes never arrive.
--]]
return {
    -- D-Pad
    [103] = "Up",   -- KEY_UP
    [108] = "Down", -- KEY_DOWN
    [105] = "Left", -- KEY_LEFT
    [106] = "Right",-- KEY_RIGHT

    -- A / B (confirm / back)
    [57]  = "Press", -- KEY_SPACE (A)
    [29]  = "Back",  -- KEY_LEFTCTRL (B)

    -- X / Y
    [42]  = "Menu",  -- KEY_LEFTSHIFT (X) -> main menu
    [56]  = "ToggleScreenSaver", -- KEY_LEFTALT (Y)

    -- Start / Menu / Select
    [28]  = "Press", -- KEY_ENTER (Start) -> confirm
    [1]   = "Menu",  -- KEY_ESC (Menu button) -> main menu
    [97]  = "Back",  -- KEY_RIGHTCTRL (Select) -> back

    -- Shoulder buttons: page up / page down
    [15]  = "RPgBack", -- KEY_TAB (L2)
    [14]  = "RPgFwd",  -- KEY_BACKSPACE (R2)

    -- SigmaStar letter-key candidates (inert if unused)
    [30]  = "Press",            -- KEY_A
    [48]  = "Back",             -- KEY_B
    [45]  = "Menu",             -- KEY_X
    [44]  = "ToggleScreenSaver",-- KEY_Y
    [116] = "Menu",             -- KEY_POWER
}
