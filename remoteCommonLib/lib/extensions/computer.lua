-- computer class extension functions


require( "/lib/extensions/tables.lua", EEPROM.Remote.CommonLib )


---Find and return a table of all the PCIDevices that are of the given class[es]
---@param class any Class name or table (of tables) of class names
---@return table: indexed table of all PCIDevices found
function computer.getPCIDevicesByClass( class )
    local results = {}
    
    if type( class ) == "table" then
        for _, c in pairs( class ) do
            table.merge( results, computer.getPCIDevicesByClass( c ) )
        end
        
    elseif type( class ) == "string" then
        results = computer.getPCIDevices( findClass( class ) )
    end
    
    return results
end



