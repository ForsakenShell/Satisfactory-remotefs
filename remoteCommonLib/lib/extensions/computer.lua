-- computer class extension functions


require( "/lib/extensions/tables.lua", EEPROM.Remote.CommonLib )


---Find and return a table of all the PCIDevices that are of the given class[es]
---@param class any Class name or table (of tables) of class names
---@return table indexed table of all PCIDevices found
function computer.getPCIDevicesByClass( class )
    local results = {}
    
    if type( class ) == "table" then
        for _, c in pairs( class ) do
            table.merge( results, computer.getPCIDevicesByClass( c ) )
        end
        
    elseif type( class ) == "string" then
        local ctype = findClass( class )
        if ctype ~= nil then
            results = computer.getPCIDevices( ctype )
        end
    end
    
    return results
end




--- This is to try and capture saving the game throwing off the timer
--- Seems like this is one of several bugs with saving :\
local oldmillis = computer.millis
function computer.millis()
    local a = oldmillis()
    local b = oldmillis()
    local c = math.abs( b - a )
    while c > 1 do
        local ts, ssf, dts = computer.magicTime()
        print( string.format( "%s : computer timer anomaly detected: %d ? %d ? %d", dts, a, b, c ) )
        a = oldmillis()
        b = oldmillis()
        c = math.abs( b - a )
    end
    return a
end



