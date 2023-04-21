---Inventory Storage Array
---@class StorageArray:table
---@field item ItemType Item being stored in the array
---@field storage array Array of storage containers; must be appropriate for the item
local StorageArray = _G[ "____StorageArray" ]
if StorageArray ~= nil then return StorageArray end




----------------------------------------------------------------

local ItemDatum                 = require( "/lib/ItemDatum.lua", EEPROM.Remote.CommonLib )




-- Internal magic
local __ST_FLUID                = findClass( "PipeReservoir" )
local __ST_SOLID                = findClass( "FGBuildableStorage" )

----------------------------------------------------------------

---@class StorageArray:table
---@field item ItemDatum item stored in the array
---@field isFluid boolean item is a fluid (or not)
---@field max integer maximum item count or fluid volume
StorageArray = {
    name = '',
    item = nil,
    isFluid = false,
    max = 0,
    current = 0,
    rate = 0.0,
    units = nil,
    unitsLen = nil,
    count = 0,
}
StorageArray.__index = StorageArray
_G[ "____StorageArray" ] = StorageArray


StorageArray.ST_FLUID = __ST_FLUID
StorageArray.ST_SOLID = __ST_SOLID

StorageArray.THROUGHPUT_UPDATE_MS = 10000   -- Update the throughput rate monitoring every X ms, default is 10000 (10 seconds); more time = more accurate but less frequent display updates of the "rate"
local throughUpdateTimeToMinute = 60000 / StorageArray.THROUGHPUT_UPDATE_MS  -- Scalar to get the per minute rate


---Create a new StorageArray for the ItemDatum and the storage array
function StorageArray.new( item, storages )
    if not ItemDatum.isItemDatum( item ) then return nil, "item is not an ItemDatum" end
    if storages == nil or type( storages ) ~= "table" or #storages == 0 then return nil, "storage array is invalid" end
    
    local isFluid = item.isFluid
    local stackSize = item.stackSize
    
    local stores = {}
    local totalmax = 0
    
    for idx, storage in pairs( storages ) do
        if type( storage ) ~= "userdata" then return nil, "storage[ " .. tonumber( idx ) .. " ] is invalid" end
        local gt = storage[ "getType" ]
        if gt == nil or type( gt ) ~= "function" then return nil, "storage[ " .. tonumber( idx ) .. " ] is invalid" end
        local st = gt( storage )
        
        local max = nil
        local invidx = nil
        
        if isFluid then
            
            if not st:isChildOf( __ST_FLUID ) then return nil, "storage[ " .. tonumber( idx ) .. " ] is invalid, must be fluid storage" end
            max = storage.maxFluidContent
            
        else
            
            if not st:isChildOf( __ST_SOLID ) then return nil, "storage[ " .. tonumber( idx ) .. " ] is invalid, must be solid storage" end
            
            local invname = component.INV_STORAGE
            invidx = component.getInventoryIndexByName( storage, invname )
            if invidx == nil then return nil, "storage[ " .. tonumber( idx ) .. " ] - could not get " .. invname end
            local inv = storage:getInventories()[ invidx ]
            max = inv.size * stackSize
            
        end
        
        local name = storage.nick
        if name == nil or name == '' then
            name = storage.id
        end
        
        table.insert( stores, 
            {
                proxy = storage,
                name = name,
                max = max,
                idx = invidx,   -- Store the resolved inventory index, NOT the resolved inventory reference
            } )
        
        totalmax = totalmax + max
    end
    
    local array = {
        -- Public:
        name = item.name,
        item = item,
        isFluid = isFluid,
        max = totalmax,
        count = #stores,
        units = item.units,
        unitsLen = item.unitsLen,
        rate = 0.0,
        -- Private:
        __stores = stores,
        __lastTimestamp = -1,
    }
    setmetatable( array, { __index = StorageArray } )
    array:update()
    return array
end



---Get the proxy of the individual storage container in the array by index, 1 .. StorageArray.count
function StorageArray:storeProxy( index )
    if index < 1 or index > self.count then return nil end
    return self.__stores[ index ].proxy
end


---Get the Storage Inventory of the individual storage container (or nil for fluid storage) in the array by index, 1 .. StorageArray.count
function StorageArray:storeInventory( index )
    if self.isFluid or index < 1 or index > self.count then return nil end
    return self.__stores[ index ].proxy:getInventories()[ store.idx ] -- For solids, return the storage inventory for the proxy
end


---Get the "name" (nickname or id) of the individual storage container in the array by index, 1 .. StorageArray.count
function StorageArray:storeName( index )
    if index < 1 or index > self.count then return nil end
    return self.__stores[ index ].name
end


---Get the current volume level of the individual storage container in the array by index, 1 .. StorageArray.count
function StorageArray:storeCurrent( index )
    if index < 1 or index > self.count then return nil end
    
    local store = self.__stores[ index ]
    local proxy = store.proxy
    
    if self.isFluid then
        return proxy.fluidContent
    end
    
    return proxy:getInventories()[ store.idx ].itemCount
end


---Get the maximum volume level of the individual storage container in the array by index, 1 .. StorageArray.count
function StorageArray:storeMax( index )
    if index < 1 or index > self.count then return nil end
    return self.__stores[ index ].max
end


---Get the "useful data" of the individual storage container in the array by index, 1 .. StorageArray.count
---@returns string, integer, integer, name, current, max
function StorageArray:storeUsefulData( index )
    if index < 1 or index > self.count then return nil end
    local store = self.__stores[ index ]
    local proxy = store.proxy
    local current = nil
    if self.isFluid then
        current = proxy.fluidContent
    else
        current = proxy:getInventories()[ store.idx ].itemCount
    end
    return store.name, current, store.max
end

function StorageArray:resetThroughput()
    self.__lastCount        = self.current
    self.__lastTimestamp    = computer.millis()
end

---Get the current number of items/stacks this inventory is holding
function StorageArray:update()
    local current = 0
    local stores = self.__stores
    
    if self.isFluid then
        
        for _, store in pairs( stores ) do
            current = current + store.proxy.fluidContent
        end
        
    else
        
        for _, store in pairs( stores ) do
            current = current + store.proxy:getInventories()[ store.idx ].itemCount
        end
        
    end
    
    self.current = current
    
    if self.__lastTimestamp < 0 then
        self.__lastCount        = current
        self.__lastTimestamp    = computer.millis()
        
    else
        local newTimestamp      = computer.millis()
        local deltaTime         = newTimestamp - self.__lastTimestamp
        
        if deltaTime < 0 then
            self.__lastCount    = current
            self.__lastTimestamp = newTimestamp
            
        else
            local tuMS = StorageArray.THROUGHPUT_UPDATE_MS
            if deltaTime >= tuMS then
                local deltaCount = current - self.__lastCount
                self.rate = ( deltaCount * ( deltaTime / tuMS ) ) * throughUpdateTimeToMinute
                self.__lastCount = current
                self.__lastTimestamp= newTimestamp
            end
        end
        
        
    end
    
end




return StorageArray