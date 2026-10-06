--[[--
Minimal power management for the Miyoo Mini.
Reads battery capacity/status from sysfs when available, otherwise
reports sane defaults (100% / not charging) to avoid bogus warnings.
--]]

local BasePowerD = require("device/generic/powerd")

local MiyooPowerD = BasePowerD:new{}

function MiyooPowerD:getCapacityHW()
    local f = io.open("/sys/class/power_supply/battery/capacity", "r")
    if f then
        local cap = tonumber(f:read("*a"))
        f:close()
        if cap then
            return cap
        end
    end
    return 100
end

function MiyooPowerD:isChargingHW()
    local f = io.open("/sys/class/power_supply/battery/status", "r")
    if f then
        local s = f:read("*a")
        f:close()
        return s ~= nil and s:match("Charging") ~= nil
    end
    return false
end

return MiyooPowerD
