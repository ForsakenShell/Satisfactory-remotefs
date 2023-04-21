---Train Platform Controller
---@class PlatformController:table
local PlatformController = _G[ "____PlatformController" ]
if PlatformController ~= nil then return PlatformController end


local ClassGroup = require( "/lib/classgroups.lua", EEPROM.Remote.CommonLib )
local ItemTransferRequest = require( "/lib/ItemTransferRequest.lua", EEPROM.Remote.CommonLib )


local ITEM_FORM_SOLID           = 1
local ITEM_FORM_FLUID           = 2

--Platform States
local PS_INVALID                = -1
local PS_WAIT_FOR_DEPARTURE     =  0
local PS_WAIT_FOR_ARRIVAL       =  1
local PS_LOAD_REQUEST           =  2

PlatformController = {
    station = nil,
    mergers = nil,
    platforms = nil,
    signs = nil,
    transfers = nil,
    state = PS_INVALID,
    status = 'Invalid PlatformController',
}
PlatformController.__index = PlatformController
_G[ "____PlatformController" ] = PlatformController




-- TODO:  Move these and the associated functions to a generic train module


--- Platform Types
PlatformController.PT_EMPTY         = 0
PlatformController.PT_STATION       = 1
PlatformController.PT_CARGO         = 2
PlatformController.PT_FLUID         = 3


-- Railcar Types
PlatformController.RT_EMPTY         = 0
PlatformController.RT_LOCOMOTIVE    = 1
PlatformController.RT_CARGO         = 2
PlatformController.RT_FLUID         = PlatformController.RT_CARGO   -- The game shares these railcar types




local function minAB( a, b )
    if a < b then return a end
    return b
end


---Get the individual platforms making up this entire station platform as an array starting with the station itself (it is a platform after all)
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


---Take a platform, return it's type
---@param platform userdata
---@return integer The type of station platform, PlaformController.PT_foo or nil
function PlatformController.platformType( platform )
    if platform == nil or type( platform ) ~= "userdata" then return nil end
    
    -- is it a station?  Only stations have a "name"
    if platform[ "name" ] ~= nil then return PlatformController.PT_STATION end
    
    -- is it an empty platform?  Only docking platforms have an "isLoading"
    if platform[ "isLoading" ] == nil then return PlatformController.PT_EMPTY end
    
    -- So we know it's a cargo or fluid platform
    
    -- Look at FactoryConnections to determine type
    local conns = platform:getFactoryConnectors()
    for _, conn in pairs( conns ) do
        if conn.type == 1 then return PlatformController.PT_FLUID end
        if conn.type == 0 then return PlatformController.PT_CARGO end
    end
    
    -- No connectors?
    return PlatformController.PT_EMPTY
end
function PlatformController.platformTypeName( pt )
    if     pt == nil or type( pt ) ~= "number" then return 'nil' end
    if     pt == PlatformController.PT_EMPTY    then return "PT_EMPTY"
    elseif pt == PlatformController.PT_STATION  then return "PT_STATION"
    elseif pt == PlatformController.PT_CARGO    then return "PT_CARGO"
    elseif pt == PlatformController.PT_FLUID    then return "PT_FLUID"
    end
    return "invalid"
end


---Take a railcar, return it's type
---@param vehicle userdata
---@return string The type of railcar, PlaformController.RT_foo or nil
function PlatformController.railcarType( vehicle )
    if vehicle == nil or type( vehicle ) ~= "userdata" or tostring( vehicle ) ~= "RailroadVehicle" then return nil end
    
    local class = string.lower( vehicle.internalName )
    
    if string.find( class, "locomotive" ) ~= nil then return PlatformController.RT_LOCOMOTIVE end
    
    return PlatformController.RT_CARGO
end
function PlatformController.railcarTypeName( rt )
    if     rt == nil or type( rt ) ~= "number" then return 'nil' end
    if     rt == PlatformController.RT_EMPTY    then return "RT_EMPTY"
    elseif rt == PlatformController.RT_STATION  then return "RT_STATION"
    elseif rt == PlatformController.RT_CARGO    then return "RT_CARGO"
    elseif rt == PlatformController.RT_FLUID    then return "RT_FLUID"
    end
    return "invalid"
end




local function createItemTransferRequests( station, train, platforms, mergers )
    if train == nil then
        print( "createItemTransferRequests() : Invalid train" )
        return nil
    end
    
    local vehicles = train:getVehicles()
    
    -- go through the train and platforms and generate a transfer amount per
    local maxDex = minAB( #vehicles, #platforms ) -- Last car we can deal with is dependant on which is shorter, the train or the train station
    if maxDex < 2 then
        print( "createItemTransferRequests() : Too few platforms/cars" )
        return nil
    end -- Need one loco and one car, so min train/station length of 2
    
    local name = train:getName()                 -- Get the settings from the train
    print( name )
    if name == nil or name == '' then
        print( "createItemTransferRequests() : Unable to read train settings" )
        return nil
    end -- Loco needs to tells us what to load in each car
    local settings = EEPROM.Settings.FromString( name, true )
    
    local requests = {}
    
    for k,v in pairs( settings ) do
        
        print( k, v )
        local index = tonumber( k )
        if index ~= nil and index > 1 and index <= maxDex then
            
            local item = findItem( v )
            if item ~= nil then
                
                local vehicle = vehicles[ index ]
                local platform = platforms[ index ]
                
                local isSolid = item.form == ITEM_FORM_SOLID
                --local isFluid = item.form == ITEM_FORM_FLUID
                
                local vInv = component.getInventoryByName( vehicle, component.INV_STORAGE )
                local pInv = component.getInventoryByName( platform, component.INV_INVENTORY )
                
                print( type( vInv ), type( pInv ) )
                
                local current = 0
                local amount = 0
                
                local carType = PlatformController.railcarType( vehicle )
                local platType = PlatformController.platformType( platform )
                print( PlatformController.platformTypeName( platType ), PlatformController.railcarTypeName( carType ) )
                
                if isSolid and carType == PlatformController.RT_CARGO and platType == PlatformController.PT_CARGO then
                    amount = minAB( vInv.size, pInv.size )
                    amount = amount - 1             -- Platforms have a bug where they will load as soon as they have items in all stack slots, not when those stacks are full; so, trick it by filling one less slot
                    amount = amount * item.max
                    amount = amount + 1             -- Plus one item so that the last stack is used but only by 1 item, triggering the load onto the car but not allowing items end up left in the platform
                    --amount = 500
                    
                    current = pInv.itemCount        -- How many are currently in the platform inventory?
                    
                --elseif isFluid and carType == PlatformController.RT_FLUID and platType == PlatformController.PT_FLUID then
                --    TODO:  CHECK THIS
                --    amount = vInv.size * 1000.0
                    
                end
                
                --Create the request for this car
                if amount > 0 then
                    
                    local stationID = tonumber( EEPROM.Settings.FromComponentNickname( station )[ "station" ] )
                    
                    local mergerID = string.format( "%s.%d", stationID, index )
                    print( mergerID )
                    local pmergers = {}
                    for _, merger in pairs( mergers ) do
                        local mID = EEPROM.Settings.FromComponentNickname( merger )[ "merger" ]
                        print( mID )
                        if mID == mergerID then
                            table.insert( pmergers, merger )
                        end
                    end
                    
                    -- Better grab it before we nuke it!
                    pInv:flush()
                    
                    local request = ItemTransferRequest.new(
                        {
                            item = item,
                            count = amount,
                            current = current,
                            mergers = pmergers,
                            target = mergerID,
                            vehicle = vehicle,
                            platform = platform,
                         } )
                    if request == nil then
                        computer.panic( debug.traceback( "Could not create ItemTransferReuest for platform " .. mergerID ) )
                    end
                    table.insert( requests, request )
                end
            end
        end
    end
    
    -- Return the per car/station requests from storage
    return requests
end


local function allItemTransfersComplete( requests )
    if requests == nil or type( requests ) ~= "table" then return false end
    for _, request in pairs( requests ) do
        if not request:isComplete() then return false end
    end
    return true
end


local function cleanItemTransferRequests( self )
    local requests = self.transfers
    if requests == nil or type( requests ) ~= "table" then return end
    self.transfers = nil
    for _, request in pairs( requests ) do
        request.item = nil
        request.mergers = nil
        request.target = nil
        request.vehicle = nil
        request.platform = nil
    end
end








---Create a new StationLoader
---@param station userdata NetworkComponent Proxy of the train station
function PlatformController.new( station )
    if station == nil or type( station ) ~= "userdata" then return nil end
    local stationID = tonumber( EEPROM.Settings.FromComponentNickname( station )[ "station" ] )
    if stationID == nil or type( stationID ) ~= "number" then
        computer.panic( debug.traceback( "Invalid nickname, must be an integer uniquely identifying this platform amongst the other platforms for this station" ) )
    end
    
    local childIdxPrefix = string.format( "%d.", stationID )
    local lchildIdxPrefix = string.len( childIdxPrefix )
    print( "\t", stationID, station  )
    
    local allMergers = component.getComponentsByClass( ClassGroup.CodeableMergers.All )
    if allMergers == nil or #allMergers == 0 then
        computer.panic( debug.traceback( "No codeable mergers found, so none that can feed any platform" ) )
    end
    
    local mergers = {}
    for _, merger in pairs( allMergers ) do
        local mergerID = EEPROM.Settings.FromComponentNickname( merger )[ "merger" ]
        if mergerID ~= nil and mergerID ~= '' and string.len( mergerID ) > lchildIdxPrefix and string.sub( mergerID, 1, lchildIdxPrefix ) == childIdxPrefix then
            print( "\t", mergerID, merger )
            table.insert( mergers, merger )
        end
    end
    
    if mergers == nil or #mergers == 0 then
        computer.panic( debug.traceback( string.format( "No codeable mergers found with matching nickname to feed this platform - looking for mergers with a nickname starting with '%s'", childIdxPrefix ) ) )
    end
    
    local platforms = getPlatforms( station )
    if platforms == nil or #platforms == 0 then
        computer.panic( debug.traceback( "No platforms found for this station!  Not even the station!  Ruh-roh, Raggy!" ) )
    end
    
    local o = {
        station = station,
        mergers = mergers,
        platforms = platforms,
        signs = nil,
        transfers = nil,
        state = PS_WAIT_FOR_ARRIVAL,
        status = 'Waiting for train arrival...',
        }
    setmetatable( o, { __index = PlatformController } )
    return o
end



---PlatformController dispatcher.  Call this in your main loop.
---@param edata table table {event.pull()}
---@return boolean true, event was handled, false otherwise
function PlatformController.handleEvent( edata )
    return ItemTransferRequest.handleEvent( edata )
end




---Factory tick
function PlatformController:factoryTick()
    local state = self.state
    local station = self.station
    
    if state == PS_WAIT_FOR_DEPARTURE then
        -- Wait until the train leaves before going back to the monitoring state
        
        local loco = station:getDockedLocomotive()
        if loco == nil then
            state = PS_WAIT_FOR_ARRIVAL
            print( "Train has departed from platform " .. station.nick )
        else
            self.status = "Waiting for train departure... "
            
            -- Try to kick the train out so it's not waiting for platforms that aren't un/loaded at this station
            --[[
            local train = loco:getTrain()
            if train.isDocked then
                local timetable = train:getTimeTable()
                local stopIndex = timetable:getCurrentStop()
                local stopTable = timetable:getStops()[ stopIndex ]
                local stopStation = stopTable.station
                if stopStation == station then
                    print( "Kicking train out of station..." )
                    
                    local function updateSelfDrive( train, newState )
                        while train.isSelfDriving ~= newState do
                            train:setSelfDriving( newState )
                            event.pull( 0 )
                        end
                    end
                    
                    updateSelfDrive( train, false )
                    
                    local ruleSet = stopTable:getRuleSet()
                    
                    local odef = ruleSet.definition
                    local odur = ruleSet.duration
                    local odar = ruleSet.isDurationAndRule
                    
                    ruleSet.definition = 0
                    ruleSet.duration = 0.0
                    ruleSet.isDurationAndRule = false
                    stopTable:setRuleSet( ruleSet )
                    
                    updateSelfDrive( train, true )
                    
                    local waitUntil = computer.millis() + 5000
                    while train.isDocked and computer.millis() < waitUntil do
                        print( "...waiting for docking status to change" )
                        event.pull( 0.25 )
                    end
                    
                    updateSelfDrive( train, false )
                    
                    ruleSet.definition = odef
                    ruleSet.duration = odur
                    ruleSet.isDurationAndRule = odar
                    stopTable:setRuleSet( ruleSet )
                    
                    updateSelfDrive( train, true )
                    
                end
            end
            ]]
        end
        
    elseif state == PS_WAIT_FOR_ARRIVAL then
        
        -- Check for a train at the station
        local loco = station:getDockedLocomotive()
        if loco == nil then
            self.status = "Waiting for train arrival..."
            
        else
            self.status = "Creating Storage Requests..."
            print( "Train has arrived at platform " .. station.nick )
            
            local requests = createItemTransferRequests( station, loco:getTrain(), getPlatforms( station ), self.mergers )
            if requests == nil or #requests == 0 then
                print( "Could not create storage requests" )
                state = PS_WAIT_FOR_DEPARTURE
            else
                self.transfers = requests
                local t = "Preparing to load:"
                for _, request in pairs( requests ) do
                    t = t .. "\n\tTarget: " .. tostring( request.target ) .. " : " .. tostring( request.count ) .. " " .. request.item.name
                end
                print( t )
                state = PS_LOAD_REQUEST
            end
        end
        
        
    elseif state == PS_LOAD_REQUEST then
        
        self.status = "Transfering items to train platforms"
        local requests = self.transfers
        
        --for _, request in pairs( requests ) do
        --    request:tryTransferItems()
        --end
        
        if allItemTransfersComplete( requests ) then
            cleanItemTransferRequests( self )
            event.clear()
            self.status = "Load requests complete, waiting for transfer to and departure of train"
            state = PS_WAIT_FOR_DEPARTURE
        end
        
    end
    
    self.state = state
end







return PlatformController