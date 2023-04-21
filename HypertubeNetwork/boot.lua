---
--- Created by 1000101
--- DateTime: 14/03/2023 12:26 am
---

--- Use the nickname on the Computer to set the settings:
--- vertex="integer"        -- vertex is required and must be unique in the entire HypertubeNetwork
--- name="display text"     -- name is only used for destinations, junctions should not set this or set it to an empty string




if ____Disk_UUID ~= nil and ____Disk_UUID ~= '' then
    -- A disk in the Hypertube Node computer means the player is doing some
    -- maintainence on the network and will want a full log of events.
    require( "/lib/ConsoleToFile.lua", EEPROM.Remote.CommonLib )
end




require( "HypertubeNode.lua" )




HypertubeNode.init()

while true do
    HypertubeNode.UIO.update()
    
    local edata = { event.pull() }
    
    HypertubeNode.handleEvent( edata )
    
end