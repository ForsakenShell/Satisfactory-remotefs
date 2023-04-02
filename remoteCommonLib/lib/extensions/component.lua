-- component class extension functions


require( "/lib/extensions/tables.lua", EEPROM.Remote.CommonLib )


---Find and return a table of all the NetworkComponent proxies that are of the given class[es]
---@param class any Class name or table (of tables) of class names
---@return table: indexed table of all NetworkComponents found
function component.getComponentsByClass( class )
    local results = {}
    
    if type( class ) == "table" then
        for _, c in pairs( class ) do
            --print( c )
            table.merge( results, component.getComponentsByClass( c ) )
        end
        
    elseif type( class ) == "string" then
        --print( class )
        local comps = component.findComponent( findClass( class ) )
        for _, c in pairs( comps ) do
            local proxy = component.proxy( c )
            if not table.hasValue( results, proxy ) then
                table.insert( results, proxy )
            end
        end
    end
    
    return results
end


