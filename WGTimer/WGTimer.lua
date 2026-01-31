WG_TIMER = { 
    status = "idle", 
    time = 0,
    endTime = 0,
    lastUpdate = 0,
    announceEnabled = false  -- Default: OFF
}

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("UNIT_AURA")

-- Skapa custom event för WeakAuras
local updateThrottle = 0
local UPDATE_INTERVAL = 1  -- Uppdatera varje sekund istället för varje frame

local function UpdateWG()
    local currentTime = GetTime()
    
    -- Kolla om Tenacity-buffen finns (battle pågår)
    local _, _, _, _, _, _, exp = UnitBuff("player", "Tenacity")
    if exp and exp > currentTime then
        WG_TIMER.status = "active"
        WG_TIMER.endTime = exp
        WG_TIMER.time = exp - currentTime
        WG_TIMER.lastUpdate = currentTime
        return
    end
    
    -- Kolla Warmane server timer (väntar på nästa battle)
    if GetWintergraspWaitTime then
        local t = GetWintergraspWaitTime()
        if t and t > 0 then
            WG_TIMER.status = "waiting"
            WG_TIMER.endTime = currentTime + t
            WG_TIMER.time = t
            WG_TIMER.lastUpdate = currentTime
            return
        end
    end
    
    -- Default idle
    WG_TIMER.status = "idle"
    WG_TIMER.time = 0
    WG_TIMER.endTime = 0
    WG_TIMER.lastUpdate = currentTime
end

-- Event handler
f:SetScript("OnEvent", function(self, event, ...)
    UpdateWG()
    -- Trigga custom event för WeakAuras
    if WeakAuras and WeakAuras.ScanEvents then
        WeakAuras.ScanEvents("WG_TIMER_UPDATE")
    end
end)

-- Throttled OnUpdate - körs max 1 gång per sekund
f:SetScript("OnUpdate", function(self, elapsed)
    updateThrottle = updateThrottle + elapsed
    
    if updateThrottle >= UPDATE_INTERVAL then
        updateThrottle = 0
        
        if WG_TIMER.endTime > 0 then
            local currentTime = GetTime()
            local oldTime = WG_TIMER.time
            WG_TIMER.time = math.max(0, WG_TIMER.endTime - currentTime)
            
            -- Trigga event bara om tiden har förändrats
            if math.floor(oldTime) ~= math.floor(WG_TIMER.time) then
                if WeakAuras and WeakAuras.ScanEvents then
                    WeakAuras.ScanEvents("WG_TIMER_UPDATE")
                end
            end
            
            -- Om tiden är slut, uppdatera status
            if WG_TIMER.time <= 0 then
                UpdateWG()
                if WeakAuras and WeakAuras.ScanEvents then
                    WeakAuras.ScanEvents("WG_TIMER_UPDATE")
                end
            end
        end
    end
end)

-- Slash command för debugging
SLASH_WGTIMER1 = "/wgt"
SlashCmdList["WGTIMER"] = function(msg)
    local command, arg = msg:match("^(%S*)%s*(.-)$")
    
    if command == "announce" then
        if arg == "on" then
            WG_TIMER.announceEnabled = true
            print("|cFF00FF00[WG Timer]|r Guild announce |cFF00FF00ENABLED|r - Will announce 20 min before battle")
        elseif arg == "off" then
            WG_TIMER.announceEnabled = false
            print("|cFFFF0000[WG Timer]|r Guild announce |cFFFF0000DISABLED|r")
        else
            local status = WG_TIMER.announceEnabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"
            print("|cFFFFFF00[WG Timer]|r Guild announce is currently: " .. status)
            print("Usage: /wgt announce on|off")
        end
    else
        print("=== WG Timer Debug ===")
        print("Status:", WG_TIMER.status)
        print("Time remaining:", string.format("%.1f", WG_TIMER.time))
        print("End time:", WG_TIMER.endTime)
        print("Last update:", string.format("%.1f", GetTime() - WG_TIMER.lastUpdate), "seconds ago")
        print("Guild announce:", WG_TIMER.announceEnabled and "|cFF00FF00ENABLED|r" or "|cFFFF0000DISABLED|r")
        print(" ")
        print("Commands:")
        print("/wgt - Show debug info")
        print("/wgt announce on - Enable guild announcements")
        print("/wgt announce off - Disable guild announcements")
    end
end

-- Force update command
SLASH_WGTIMERFORCE1 = "/wgtforce"
SlashCmdList["WGTIMERFORCE"] = function()
    UpdateWG()
    if WeakAuras and WeakAuras.ScanEvents then
        WeakAuras.ScanEvents("WG_TIMER_UPDATE")
    end
    print("WG Timer forced update")
end