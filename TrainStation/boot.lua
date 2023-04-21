Module = { Version = { full = { 1, 0, 0, '' } } }
---
--- Created by 1000101
--- DateTime: 22/03/2023 11:48 pm
---

--- Use the nickname on the Computer to set the settings:
--- foo="bar"               -- TBD



if EEPROM == nil then
    panic( "EEPROM is out of date!\nRequired: EEPROM v1.3.8 or later")
end

-- Versioning --
Module.Version.pretty = EEPROM.Version.ToString( Module.Version.full )
--[[ version history
1.0.0
 + Initial release
]]



if EEPROM.Boot.Disk ~= nil and EEPROM.Boot.Disk ~= '' then
    -- A disk in the Production Terminal computer means the player is doing some
    -- maintainence on the network and will want a full log of events.
    require( "/lib/ConsoleToFile.lua", EEPROM.Remote.CommonLib )
end




require( "TrainStationController.lua" )




--[[
TrainStationController.init()

while true do
    TrainStationController.UIO.update()
    
    local edata = { event.pull( 1.0 ) }
    
    TrainStationController.handleEvent( edata )
    
end
]]