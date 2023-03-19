INV_STORAGE             = 1

ITEM_SOLID              = 1
ITEM_FLUID              = 2

MAIN_UPDATE_TIME        = 0.25

--Load States
LS_WAIT_FOR_DEPARTURE   = -1
LS_WAIT_FOR_ARRIVAL     = 0
LS_LOAD_REQUEST         = 1


storageIndexKey         = "Storage"
signIndexKey            = "Sign"
itemSettingsKey         = "item"

gpuClass                = "GPUT1"
screenClassPCIDevice    = "FINComputerScreen"
screenClassNetwork      = "Screen"
storageClasses          = { "FGBuildableStorage" }
signClasses             = { "WidgetSign" }
mergerClass             = "CodeableMerger"
stationClass            = "RailroadStation"





MonitorTemplate = {
    item_name = '',
    item = nil,
    storage = nil,
    sign = nil,
    units = function( this )
        if this.item == nil then return '' end
        if this.item.form == ITEM_FORM_LIQUID then return 'm³' end
        return ''
    end,
    max = function( this )
        if this.storage == nil then return 0 end
        
        local inventories = this.storage:getInventories()
        if inventories == nil or #inventories < INV_STORAGE then return 0 end
        
        local inventory = inventories[ INV_STORAGE ]
        if inventory == nil then return 0 end
        
        local result = inventory.size
        
        if this.item ~= nil then
            result = result * this.item.max
        end
        
        return result
    end,
    current = function( this )
        if this.storage == nil then return 0 end
        
        local inventories = this.storage:getInventories()
        if inventories == nil or #inventories < INV_STORAGE then return 0 end
        
        local inventory = inventories[ INV_STORAGE ]
        if inventory == nil then return 0 end
        
        return inventory.itemCount
    end,
    status = function( this )
        return formatNumber( this:current() ) .. '/' .. formatNumber( this:max() ) .. this:units()
    end,
    updateSign = function( this )
        if this.sign == nil then
            print( 'No sign for ' .. this.storage.internalName )
            return
        end
        
        local prefab = this.sign:getPrefabSignData()
        if prefab == nil then
            computer.panic( "Could not getPrefabSignData()\n\t" .. this.sign.internalName .. "\n\t" .. this.sign.nick )
        end
        
        prefab:setTextElement( 'Name', this:status() )
        
        this.sign:setPrefabSignData( prefab )
    end,
}
MonitorTemplate.__index = MonitorTemplate

Monitors = {}
function findOrCreateMonitor( index )
    
    local monitor = Monitors[ index ]
    if monitor == nil then
        monitor = {
            item_name = '',
            item = nil,
            storage = nil,
            sign = nil,
        }
        setmetatable( monitor, { __index = MonitorTemplate } )
    end
    
    return monitor
end





function encodeSettings( data )
    local settings = ''
    for key, value in pairs( data ) do
        if settings ~= '' then settings = settings .. ' ' end
        settings = settings .. key .. '="' .. value .. '"'
    end
    return settings
end


function decodeSettings( settings )
    local data = {}
    for key, value in string.gmatch( settings, '(%w+)=(%b"")' ) do
        local trimmed = string.sub( value, 2, string.len( value ) - 1 )
        data[ key ] = trimmed
    end
    return data
end




function formatNumber( n, leader, decimals, prefixPositive )
    local result = string.format( '%' .. ( leader or 0 ) .. '.' .. ( decimals or 0 ) .. 'f', n )
    prefixPositive = prefixPositive or false
    if prefixPositive and n > 0 then
        result = '+' .. result
    end
    return result
end


function findCompsByClass( class )
    local results = {}
    local comps = component.findComponent( findClass( class ) )
    for _,c in pairs( comps ) do
        table.insert( results, component.proxy( c ) )
    end
    return results
end


function findCompsByClasses( classes )
    local results = {}
    for _, class in pairs( classes ) do
        local comps = component.findComponent( findClass( class ) )
        for _,c in pairs( comps ) do
            table.insert( results, component.proxy( c ) )
        end
    end
    return results
end


function getSettingByName( proxy, settings, key, stype )
    local setting = settings[ key ]
    if setting == nil  then
        computer.panic( "Network Component does not have a setting with key '" .. key .. "'\n\t" .. proxy.internalName .. "\n\t" .. proxy.nick )
    end
    
    if type( setting ) == "string" and stype == "number" then
        setting = math.tointeger( setting ) -- Try force it
    end
    
    if setting == nil or type( setting ) ~= stype then
        computer.panic( "Network Component setting '" .. key .. "' did not resolve to a '" .. stype .. "' got '" .. tostring( type( setting ) ) .. "'\n\t" .. proxy.internalName .. "\n\t" .. proxy.nick )
    end
    return setting
end


function findCompWithIndex( comps, key, value )
    for _, comp in pairs( comps ) do
        
        local settings = decodeSettings( comp.nick )
        
        local idx = getSettingByName( comp, settings, key, "number" )
        if idx ~= nil and idx >= 1 then
            if idx == value then return comp end
        end
        
    end
    return nil
end


---Counts how many key, value pairs as in an unindexed table.
-- Why would you want this?  Because sometimes you want to know how big an unindexed table is
---@param t table
---@return integer
function table.countKeyValuePairs( t )
    if t == nil or type( t ) ~= "table" then return 0 end
    local count = 0
    for k, v in pairs( t ) do
        count = count + 1
    end
    return count
end


---Get the platforms making up this entire station as an array starting with the station itself (it is a platform after all)
---@param station userdata The station to return the array of platforms (in-order) that are connected to it
---@return table The platforms, starting with the station at [1] and all others at [2...]
local function getPlatforms( station )
    if station == nil or type( station ) ~= "userdata" then return nil end
    local results = {}
    table.insert( results, station )
    
    local pLast = nil
    local pCur = station
    while( pCur ~= nil )do
        local pNext = pCur:getConnectedPlatform( 1 )
        if pNext == nil or ( pLast ~= nil and pNext == pLast )then
            -- Nothing in that direction or we got the previous platform (this platform is reversed)
            pNext = pCur:getConnectedPlatform( 0 )
            if pNext == nil or pNext == pLast then
                -- No really, we're done
                break
            end
        end
        if pNext ~= nil then
            pLast = pCur
            pCur = pNext
            table.insert( results, pCur )
        end
    end
    
    return results
end


---Take a platform, return it's "type"
--- Lua is garbage in this so we need to do some work to do type coersion so we can talk to the platforms properly
---@param platform userdata
---@return string The type of station platform, "empty", "cargo", "fluid" or, "station"
local function platformType( platform )
    if platform == nil or type( platform ) ~= "userdata" then return nil end
    
    -- is it a station?  Only stations have a "name"
    if platform[ "name" ] ~= nil then return "station" end
    
    -- is it an empty platform?  Only docking platforms have an "isLoading"
    if platform[ "isLoading" ] == nil then return "empty" end
    
    -- So we know it's a cargo or fluid platform, now we need to figure out which is which from otherwise
    -- identical platforms.  There is nothing about them that we can use to distinguish them other than
    -- their class name
    local class = string.lower( tostring( platform ) )
    
    if string.find( class, "fluid" ) ~= nil then return "fluid" end
    if string.find( class, "liquid" ) ~= nil then return "fluid" end
    
    -- welp, I'm out of ideas for how to test them, assume solids
    return "cargo"
end


---Take a railcar, return it's "type"
--- Lua is garbage in this so we need to do some work to do type coersion so we can talk to the platforms properly
---@param vehicle userdata
---@return string The type of railcar, "cargo", "locomotive"
local function railcarType( vehicle )
    if vehicle == nil or type( vehicle ) ~= "userdata" or tostring( vehicle ) ~= "RailroadVehicle" then return nil end
    
    -- So we know it's a RailroadVehicle - big whoop
    
    -- Now we need to figure out which is which from otherwise identical railcars and locomotives.
    -- There is nothing about them that we can use to distinguish them other than their class name.
    local class = string.lower( vehicle.internalName )
    
    if string.find( class, "locomotive" ) ~= nil then return "locomotive" end
    
    -- welp, I'm out of ideas for how to test them, assume a freight car
    return "cargo"
end


function countInStorage( item, containers )
    if item == nil then return 0 end
    if containers == nil or #containers == 0 then return 0 end
    
    local total = 0
    for _, c in pairs( containers ) do
        
        local inv = c:getInventories()[ INV_STORAGE ]
        local cItem = nil
        local cTotal = 0
        
        for sIdx = 1, inv.size do
            
            local stack = inv:getStack( sIdx )
            if stack ~= nil then
                
                local count = stack.count
                if count > 0 then
                    
                    local sItem = stack.item.type
                    if sItem ~= nil then
                        
                        if cItem == nil then
                            cItem = sItem
                        elseif cItem ~= sItem then
                            print( "Cannot handle mixed-inventory storage, ignoring this container" )
                            print( cItem.name, sItem.name )
                            cTotal = 0
                            sIdx = inv.size + 1
                            
                        elseif sItem == item then
                            cTotal = cTotal + count
                        end
                        
                    end
                end
            end
        end
        
        total = total + cTotal
        
    end
    
    return total
end


RequestFromStorage = {
    target = -1,    -- Platform/railcar index
    vehicle = nil,  -- The railcar
    platform = nil, -- The platform
    mergers = nil,  -- The CodeableMergers used to control item flow
    item = nil,     -- Item to be loaded into the railcar
    count = 0,      -- Amount to transfer from storage to the station
    current = 0,    -- Current count of amount transfered to the station
}
RequestFromStorage.__index = RequestFromStorage
function RequestFromStorage:itemsFetchedFromStorage()
    return self.current >= self.count
end

function RequestFromStorage:status()
    local s = self.platform.status
    if s == 2 then
        return "Loading " .. self.item.name .. " onto train"
    elseif s == 10 then
        return "Unloading " .. self.item.name .. " from train"
    elseif s == 6 then
        return tostring( self.current ) .. "/" .. tostring( self.count ) .. " " .. self.item.name
    end
    local t = tostring( s )
    return t
end

function RequestFromStorage:tryTransferItems()
    if self.current >= self.count then return end
    
    for _, merger in pairs( self.mergers ) do
        if merger.canOutput then
            for i = 0, 2 do
                
                local item = merger:getInput( i )
                if item ~= nil and item.type ~= nil and item.type == self.item then
                    if merger:transferItem( i ) then
                        self.current = self.current + 1
                        if self.current >= self.count then return end
                        break
                    end
                end
                
            end
        end
    end
end



local function minAB( a, b )
    if a < b then return a end
    return b
end

function RequestFromStorage.create( train, platforms, mergers )
    if train == nil then
        print( "RequestFromStorage.create() : Invalid train" )
        return nil
    end
    
    local vehicles = train:getVehicles()
    
    -- go through the train and platforms and generate a transfer amount per
    local maxDex = minAB( #vehicles, #platforms ) -- Last car we can deal with is dependant on which is shorter, the train or the train station
    if maxDex < 2 then
        print( "RequestFromStorage.create() : Too few platforms/cars" )
        return nil
    end -- Need one loco and one car, so min train/station length of 2
    
    local nick = train:getName()                 -- Get the settings from the train
    print( nick )
    if nick == nil or nick == '' then
        print( "RequestFromStorage.create() : Unable to read train settings" )
        return nil
    end -- Loco needs to tells us what to load in each car
    local settings = decodeSettings( nick )
    
    local requests = {}
    
    for k,v in pairs( settings ) do
        
        print( k, v )
        local index = tonumber( k )
        if index ~= nil and index > 1 and index <= maxDex then
            
            local item = findItem( v )
            if item ~= nil then
                
                local vehicle = vehicles[ index ]
                local platform = platforms[ index ]
                
                local isSolid = item.form == ITEM_SOLID
                --local isFluid = item.form == ITEM_FLUID
                
                local amount = 0
                if isSolid and railcarType( vehicle ) == "cargo" and platformType( platform ) == "cargo" then
                    amount = minAB( vehicle:getInventories()[ INV_STORAGE ].size, platform:getInventories()[ INV_STORAGE ].size )
                    amount = amount - 1             -- Platforms have a bug where they will load as soon as they have items in all stack slots, not when those stacks are full; so, trick it by filling one less slot
                    amount = amount * item.max
                    amount = amount + 1             -- Plus one item so that the last stack is used but only by 1 item, triggering the load onto the car but not allowing items end up left in the platform
                    --amount = 500
                    
                --elseif isFluid and railcarType( vehicle ) == "cargo" and platformType( platform ) == "fluid" then
                --    TODO:  CHECK THIS
                --    amount = vehicle:getInventories()[ INV_STORAGE ].size * 1000.0
                    
                end
                
                --Create the request for this car
                if amount > 0 then
                    
                    local _mergers = {}
                    for _, merger in pairs( mergers ) do
                        local id = tonumber( merger.nick ) or -1
                        if id == index then
                            table.insert( _mergers, merger )
                        end
                    end
                    
                    local request = setmetatable(
                        {
                            target = index,
                            vehicle = vehicles[ index ],
                            platform = platforms[ index ],
                            mergers = _mergers,
                            item = item,
                            count = amount,
                            current = 0,
                        }, RequestFromStorage )
                    table.insert( requests, request )
                end
            end
        end
    end
    
    -- Return the per car/station requests from storage
    return requests
end

function allRequestsFromStorageFilled( requests )
    if requests == nil or type( requests ) ~= "table" then return false end
    for _, request in pairs( requests ) do
        if not request:itemsFetchedFromStorage() then return false end
    end
    return true
end




function createStorageMonitors()
    
    
    local storageContainers = findCompsByClasses( storageClasses )
    local signage = findCompsByClasses( signClasses )
    
    -- Go through the found storageContainers and make Monitors for them
    for _, storage in pairs( storageContainers ) do
        
        local nick = storage.nick
        local settings = decodeSettings( nick )
        
        local idx = getSettingByName( storage, settings, storageIndexKey, "number" )
        if idx == nil or idx < 1 then
            computer.panic( "Storage Container does not have a valid index key\n\t" .. storage.internalName .. "\n\t" .. nick )
        end
        
        local iname = getSettingByName( storage, settings, itemSettingsKey, "string" )
        if iname == nil or iname == '' then
            computer.panic( "Storage Container does not have a valid item key\n\t" .. storage.internalName .. "\n\t" .. nick )
        end
        
        local item = findItem( iname )
        if item == nil then
            computer.panic( "Storage Container does not have a valid item key, could not resolve item\n\t" .. storage.internalName .. "\n\t" .. nick )
        end
        
        local monitor = findOrCreateMonitor( idx )
        if monitor == nil then
            computer.panic( "Could not create Monitor for\n\t" .. storage.internalName .. "\n\t" .. nick )
        end
        
        monitor.item_name = iname
        monitor.item = item
        monitor.storage = storage
        monitor.sign = findCompWithIndex( signage, signIndexKey, idx )
        
        Monitors[ idx ] = monitor
        
        monitor:updateSign()
        
    end
    
end


function getGPUScreen()
    
    local gpu = computer.getPCIDevices( findClass( gpuClass ) )[ 1 ]
    if gpu == nil then
        computer.panic( "No GPU" )
    end
    
    local w = 2
    local h = 2
    local screen = computer.getPCIDevices( findClass( screenClassPCIDevice ) )[ 1 ]                    -- Try PCI screen first
    if screen == nil then
        screen = component.proxy( component.findComponent( findClass( screenClassNetwork ) )[ 1 ] )     -- Try Component screen second
        if screen ~= nil then w, h = screen:getSize() end
    end
    if screen == nil then
        computer.panic( "No Screen" )
    end
    
    
    
    local x = 30 * w
    local y = 15 * h
    gpu:bindScreen( screen )
    gpu:setSize( x, y )
    
    return gpu, screen, x, y
end

local gpu, screen, SCREEN_WIDTH, SCREEN_HEIGHT = getGPUScreen()
local stationStatus = ''
local requests = nil


function updateMonitors( station )
    
    local timestamp = computer.millis()
    
    gpu:setBackground( 0.0, 0.0, 0.0, 1.0 )
    gpu:setForeground( 0.0, 0.0, 0.0, 1.0 )
    gpu:fill( 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, ' ' )
    gpu:setForeground( 1.0, 1.0, 1.0, 1.0 )
    
    gpu:setText( 0, 0, "Monitored Storage: " .. tostring( table.countKeyValuePairs( Monitors ) ) )
    
    local t = tostring( timestamp )
    local x = SCREEN_WIDTH - string.len( t ) - 1
    gpu:setText( x, 0, t )
    
    local y = 1
    for _, monitor in pairs( Monitors ) do
        t = string.sub( monitor.item_name, 1, math.min( string.len( monitor.item_name ), 25 ) )
        t = t .. string.rep( ' ', 30 - string.len( t ) )
        t = t .. monitor:status()
        gpu:setText( 0, y, t )
        monitor:updateSign()
        y = y + 1
    end
    
    y = SCREEN_HEIGHT - 10
    gpu:setText( 0, y, "Station Status: " .. station.name )
    y = y + 1
    gpu:setText( 3, y, stationStatus )
    y = y + 1
    
    
    if requests ~= nil then
        for _, request in pairs( requests ) do
            gpu:setText( 3, y, "Platform " .. request.target .. " : " .. request:status() )
            y = y + 1
        end
    end
    
    gpu:flush()
end


createStorageMonitors()


local mergers = component.proxy( component.findComponent( findClass( mergerClass ) ) )
local station = component.proxy( component.findComponent( findClass( stationClass ) )[ 1 ] )


-- Prepare event handling
event.clear()
event.ignoreAll()

-- We don't actually care about the merger events, just need to get event.pull() to pump the loop
for _, merger in pairs( mergers ) do
    event.listen( merger )
end

-- We do want train arrival signals
--event.listen( station )   -- Well, we would but there isn't one, so we'll have to poll for it


local loadstate = LS_WAIT_FOR_ARRIVAL

while true do
    updateMonitors( station )
    local edata = { event.pull( MAIN_UPDATE_TIME ) }
    if edata ~= nil and edata[ 1 ] ~= nil then
        --local e = edata[ 1 ]
        --local s = edata[ 2 ]
        --print( tostring( computer.millis() ), e, s )
    end
    
    if loadstate == LS_WAIT_FOR_DEPARTURE then
        -- Wait until the train leaves before going back to the monitoring state
        
        local loco = station:getDockedLocomotive()
        if loco == nil then
            loadstate = LS_WAIT_FOR_ARRIVAL
            requests = nil
            print( "Train has departed" )
        else
            stationStatus = "Waiting for train departure..."
        end
        
    elseif loadstate == LS_WAIT_FOR_ARRIVAL then
        
        -- Check for a train at the station
        local loco = station:getDockedLocomotive()
        if loco == nil then
            stationStatus = "Waiting for train arrival..."
            
        else
            stationStatus = "Creating Storage Requests..."
            print( "Train has arrived" )
            
            requests = RequestFromStorage.create( loco:getTrain(), getPlatforms( station ), mergers )
            if requests == nil or #requests == 0 then
                print( "Could not create storage requests" )
                loadstate = LS_WAIT_FOR_DEPARTURE
            else
                local t = "Preparing to load:"
                for _, request in pairs( requests ) do
                    t = t .. "\n\tTarget: " .. tostring( request.target ) .. " : " .. tostring( request.count ) .. " " .. request.item.name
                end
                print( t )
                loadstate = LS_LOAD_REQUEST
            end
        end
        
        
    elseif loadstate == LS_LOAD_REQUEST then
        
        stationStatus = "Transfering items to train platforms"
        
        for _, request in pairs( requests ) do
            request:tryTransferItems()
        end
        
        if allRequestsFromStorageFilled( requests ) then
            stationStatus = "Load requests complete, waiting for transfer to and departure of train"
            loadstate = LS_WAIT_FOR_DEPARTURE
        end
        
    end
    
end
