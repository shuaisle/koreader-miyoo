--[[--
Miyoo Mini (V4) device backend for KOReader.

Display: generic Linux framebuffer (/dev/fb0, RGB565/RGB32).
         The FB memory is mmap'ed and written directly (LCD needs no refresh ioctl;
         KOReader's default refresh*Imp implementations are no-ops).
Input:   evdev via libkoreader-input (the standard KOReader input module,
         same as Kobo/Kindle/Cervantes devices).

NOTE: keycodes in event_map_miyoo.lua are placeholders until the real
      evdev keycodes are captured on the device.
--]]

local Generic = require("device/generic/device")
local logger = require("logger")

local function yes() return true end
local function no() return false end

local Device = Generic:extend{
    model = "MiyooMini",
    isTouchDevice = no,
    hasKeyboard = yes,
    hasKeys = yes,
    hasDPad = yes,
    useDPadAsActionKeys = yes,
    hasEinkScreen = no,
    hasColorScreen = yes,
    hasBattery = yes,
    hasFrontlight = no,
    hasNaturalLight = no,
    hasWifiToggle = no,
    hasSeamlessWifiToggle = no,
    isDefaultFullscreen = yes,
    canKeyRepeat = yes,
    hasExitOptions = yes,
    canSuspend = no,
    canStandby = no,
    canReboot = no,
    canPowerOff = no,
    home_dir = "/mnt/SDCARD",
    -- evdev devices to try, in order (the keypad device is usually event0).
    -- FIXME: confirm with `ls -l /dev/input/` on the device.
    input_devices = {
        "/dev/input/event0",
        "/dev/input/event1",
        "/dev/input/event2",
        "/dev/input/event3",
        "/dev/input/event4",
    },
}

function Device:init()
    self.screen = require("ffi/framebuffer_linux"):new{
        device = self,
        debug = logger.dbg,
    }

    self.powerd = require("device/miyoo/powerd"):new{
        device = self,
    }

    self.input = require("device/input"):new{
        device = self,
        event_map = require("device/miyoo/event_map_miyoo"),
    }

    -- Open the first available evdev input device.
    local opened = false
    for _, path in ipairs(self.input_devices) do
        local ok, err = pcall(function()
            self.input:open(path)
        end)
        if ok then
            logger.info("Opened input device:", path)
            opened = true
            break
        else
            logger.warn("Failed to open input device:", path, tostring(err))
        end
    end
    if not opened then
        logger.warn("No input device could be opened! Input handling will not work.")
    end

    Generic.init(self)
end

return Device
