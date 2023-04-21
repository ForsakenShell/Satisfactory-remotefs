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
        local ctype = findClass( class )
        if ctype ~= nil then
            local comps = component.findComponent( ctype )
            for _, c in pairs( comps ) do
                local proxy = component.proxy( c )
                if not table.hasValue( results, proxy ) then
                    table.insert( results, proxy )
                end
            end
        end
    end
    
    return results
end




-- Storage name constants --
component.INV_INVENTORY     = 'Inventory'
component.INV_STORAGE       = 'StorageInventory'
component.INV_INPUT         = 'InputInventory'
component.INV_OUTPUT        = 'OutputInventory'
component.INV_POTENTIAL     = 'InventoryPotential'

---Get an inventories index by it's internal name.  Why?  Because not everything with an inventory uses the same index but they use the same name.
function component.getInventoryIndexByName( proxy, name )
    if proxy == nil then return nil end
    if type( proxy ) ~= "userdata" then return nil end
    local gi = proxy[ "getInventories" ]
    if gi == nil or type( gi ) ~= "function" then return nil end
    local inventories = gi( proxy )
    for idx = 1, #inventories do
        local inv = inventories[ idx ]
        if inv.internalName == name then return idx end
    end
    return nil
end

---Get an inventory by it's internal name instead of index.  Why?  Because not everything with an inventory uses the same index but they use the same name.
function component.getInventoryByName( proxy, name )
    if proxy == nil or type( proxy ) ~= "userdata" then return nil end
    local gi = proxy[ "getInventories" ]
    if gi == nil or type( gi ) ~= "function" then return nil end
    local inventories = gi( proxy )
    --print( proxy.internalName )
    for _, inv in pairs( inventories ) do
        --print( _, "'" .. inv.internalName .. "'" )
        if inv.internalName == name then return inv end
    end
    return nil
end

