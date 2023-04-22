---Inventory Storage Monitor
---OBSOLETE EXPERIMANTAL CODE
---Use StorageArray instead
---@class StorageMonitor:table
---@field item ItemType Item being requested
---@field storage Actor Storage container to monitor (can be any Actor that has an inventory)
---@field sign Actor Optional vanilla sign to update with the current and max count of items
---@field pattern string string.format() pattern used by StorageMonitor:status()
local StorageMonitor = _G[ "____StorageMonitor" ]
if StorageMonitor ~= nil then return StorageMonitor end

StorageMonitor = {
    item = nil,
    storage = nil,
    sign = nil,
    pattern = "%d/%d%s",
}
StorageMonitor.__index = StorageMonitor
_G[ "____StorageMonitor" ] = StorageMonitor




local ITEM_FORM_SOLID         = 1
local ITEM_FORM_LIQUID        = 2




function StorageMonitor.new( o )
    if o == nil or type( o ) ~= "table" then
        print( "StorageMonitor.new() :: o is nil or not a table" )
        return nil
    end
    if o.item == nil or type( o.item ) ~= "userdata" then
        print( "StorageMonitor.new() :: o.item is nil or not userdata" )
        return nil
    end
    if o.storage == nil or type( o.storage ) ~= "userdata" then
        print( "StorageMonitor.new() :: o.storage is nil or not userdata" )
        return nil
    end
    if o.sign ~= nil and type( o.sign ) ~= "userdata" then
        print( "StorageMonitor.new() :: o.sign is invalid" )
        return nil
    end
    setmetatable( o, { __index = StorageMonitor } )
    return o
end



---Get the Inventory being monitored
function StorageMonitor:getInventory()
    if self.storage == nil then return nil end
    return component.getInventoryByName( self.storage, component.INV_STORAGE )
end


---Get the "units" for the item, liquids will return 'm³', everything else will return ''
function StorageMonitor:units()
    if self.item == nil then return '' end
    if self.item.form == ITEM_FORM_LIQUID then return 'm³' end
    return ''
end


---Get the maximum number of items/stacks this inventory will hold
function StorageMonitor:max( stacksOnly )
    local inventory = self:getInventory()
    if inventory == nil then return 0 end
    
    local result = inventory.size
    
    stacksOnly = stacksOnly or false
    if not stacksOnly and self.item ~= nil then
        result = result * self.item.max
    end
    
    return result
end


---Get the current number of items/stacks this inventory is holding
function StorageMonitor:current( stacksOnly )
    local inventory = self:getInventory()
    if inventory == nil then return 0 end
    
    stacksOnly = stacksOnly or false
    local total = 0
    local iStacks = inventory.size
    
    for i = 0, iStacks - 1 do
        local stack = inventory:getStack( i )
        if stack ~= nil then
            if stack.item ~= nil and stack.item.type == self.item then
                if stacksOnly then
                    total = total + 1
                else
                    total = total + stack.count
                end
            end
        end
    end
    
    return total
end



---Return a patterned string with the current and maximum item count and units; override this if you want something more/else
function StorageMonitor:status()
    return string.format( self.pattern, self:current(), self:max(), self:units() )
end


---Update the signs prefab text 'Name' with the monitor status.  Does not change the layout or set any icons.
function StorageMonitor:updateSigns()
    if self.sign == nil then
        print( 'No sign for ' .. self.storage.internalName )
        return
    end
    
    local prefab = self.sign:getPrefabSignData()
    if prefab == nil then
        computer.panic( "Could not getPrefabSignData()\n\t" .. self.sign.internalName .. "\n\t" .. self.sign.nick )
    end
    
    prefab:setTextElement( 'Name', self:status() )
    
    self.sign:setPrefabSignData( prefab )
end




return StorageMonitor