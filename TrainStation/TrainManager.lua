---
--- Created by 1000101
--- DateTime: 18/04/2023 12:52 am
---




--------------------------------------------------------------------------------

if EEPROM.Boot.Disk ~= nil and EEPROM.Boot.Disk ~= '' then
    -- A disk in the Production Terminal computer means the player is doing some
    -- maintainence on the network and will want a full log of events.
    require( "/lib/ConsoleToFile.lua", EEPROM.Remote.CommonLib )
end




--------------------------------------------------------------------------------

local ClassGroup                = require( "/lib/classgroups.lua", EEPROM.Remote.CommonLib )
local GPUs                      = ClassGroup.Displays.GPUs
local Screens                   = ClassGroup.Displays.Screens
local SolidStorage              = ClassGroup.Storage.Solids
local WidgetSigns               = ClassGroup.Displays.Signs.WidgetSigns

local Vector3f                  = require( "/lib/Vector3f.lua", EEPROM.Remote.CommonLib )

local _Collimator               = require( "/lib/Collimator.lua", EEPROM.Remote.CommonLib )
local _Column                   = _Collimator.Column
local Color                     = require( "/lib/Colors.lua", EEPROM.Remote.CommonLib )


--------------------------------------------------------------------------------

TrainManager            = {}
TrainManager.__index    = TrainManager


TrainManager.RUNAWAY_TIMEOUT                        = 3000         -- number of milliseconds between detecting a runaway train and sending it to a depot
TrainManager.STATION_ACCEPTABLE_DISTANCE_MAX        = 4.0           -- Distance in meters from the station a locomotive must be to force pathing to it
TrainManager.SPEED_CONSTANT                         = 27.91666667   -- There was a whole discussion about this on Discord
-- https://discord.com/channels/735877487808086088/735879697728274512/1076575697134436513



--------------------------------------------------------------------------------
-- Magic strings

-- Train setting keys
local TS_Status             = "status"
local TS_Status_Parked      = "parked"
local TS_Status_Transit     = "transit"
local TS_Status_Player      = "player"
local TS_Status_Ready       = "ready"
local TS_Status_Runaway     = "runaway"

-- Station setting keys
local SS_Reserved           = "reserved"


-- to string patterns
local LocationPattern       = "%.0f,%.0f,%.0f"


--------------------------------------------------------------------------------

function distanceBetween( train, station )
    local loco = train:getVehicles()[ 1 ]
    return Vector3f.sub( loco.location, station.location ):length() / 100.0 -- Convert game units to meters
end


--------------------------------------------------------------------------------

local gpu = computer.getPCIDevicesByClass( GPUs.All )[ 1 ]
if gpu == nil then computer.panic( "no gpu" ) end
local screen = component.getComponentsByClass( Screens.Build_Screen_C )[ 1 ]
if screen == nil then computer.panic( "no screen" ) end

local panelX, panelY = screen:getSize()
local screenX = panelX * 30
local screenY = panelY * 15

gpu:bindScreen( screen )
gpu:setSize( screenX, screenY )

--------------------------------------------------------------------------------

function getTrackGraph()
    local station = component.getComponentsByClass( ClassGroup.TrainStations.All )[ 1 ]
    if station == nil then computer.panic( "no station" ) end
    local trackGraph = station:getTrackGraph()
    if trackGraph == nil then computer.panic( "no track graph" ) end
    return trackGraph
end

local trackGraph = getTrackGraph()


--------------------------------------------------------------------------------

local stations = trackGraph:getStations()
if stations == nil then computer.panic( "no stations" ) end


--------------------------------------------------------------------------------

local trains = trackGraph:getTrains()
if trains == nil then computer.panic( "no trains" ) end


--------------------------------------------------------------------------------

function isDepot( station )
    return string.find( string.lower( station.name ), "depot" ) ~= nil
end


--------------------------------------------------------------------------------

function getClosestPhysicalStationToTrain( train, stations, depotonly, allowreservedbyother )
    if train == nil or stations == nil or #stations == 0 then return nil end
    local loco = train:getVehicles()[ 1 ]
    if loco == nil then return nil end
    
    if depotonly == nil or type( depotonly ) ~= "boolean" then depotonly = false end
    if allowreservedbyother == nil or type( allowreservedbyother ) ~= "boolean" then allowreservedbyother = false end
    
    local tname = train.internalName
    local locoPos = loco.location
    
    local first = -1
    if depotonly then
        
        for index = 1, #stations do
            
            local station = stations[ index ]
            if isDepot( station ) then
                
                local settings = EEPROM.Settings.FromComponentNickname( station , false )
                local reservedby = settings[ SS_Reserved ]
                if( allowreservedbyother )or( reservedby == nil )or( reservedby == tname )then
                    
                    --print( "first depot: " .. station.name )
                    first = index
                    break
                    
                end
            end
        end
        
    else
        first = 1
    end
    if first < 1 then return nil end
    
    -- Take the first as the initial result
    local result = stations[ first ]
    local delta = Vector3f.sub( locoPos, result.location )
    local dist = delta:length()
    
    -- Find a closer one
    for index = 1, #stations do
        
        if index ~= first then
            
            local station = stations[ index ]
            if( not depotonly )or( isDepot( station ) )then
                
                local settings = EEPROM.Settings.FromComponentNickname( station , false )
                local reservedby = settings[ SS_Reserved ]
                if( allowreservedbyother )or( reservedby == nil )or( reservedby == tname )then
                    
                    
                    local delta = Vector3f.sub( locoPos, station.location )
                    local d = delta:length()
                    
                    if d < dist then
                        dist = d
                        result = station
                    end
                    
                end
            end
        end
    end
    
    return result
end


--------------------------------------------------------------------------------

function getStationByName( stations, name, lower )
    if stations == nil or #stations == 0 then return nil end
    if name == nil or type( name ) ~= "string" or name == '' then return nil end
    if lower == nil or type( lower ) ~= "boolean" then lower = false end
    
    local n = name
    if lower then n = string.lower( n ) end
    
    for index = 1, #stations do
        local station = stations[ index ]
        local s = station.name
        if lower then s = string.lower( s ) end
        if s == n then return station end
    end
    
    return nil
end


--------------------------------------------------------------------------------

function getTrainByName( trains, name, lower )
    if trains == nil or #trains == 0 then return nil end
    if name == nil or type( name ) ~= "string" or name == '' then return nil end
    if lower == nil or type( lower ) ~= "boolean" then lower = false end
    
    local n = name
    if lower then n = string.lower( n ) end
    
    for index = 1, #trains do
        local train = trains[ index ]
        local s = train.internalName
        if lower then s = string.lower( s ) end
        if s == n then return train end
    end
    
    return nil
end


--------------------------------------------------------------------------------

local function updateSelfDriving( train, selfDriving )
    while train.isSelfDriving ~= selfDriving do
        local request = train:setSelfDriving( selfDriving )
        if request ~= nil then
            request:await()
        else
            print( "updateSelfDriving() : Expected future return from train:setSelfDriving()" )
        end
    end
end


--------------------------------------------------------------------------------

function dumpTrainRuleSet( label, rules )
    print( "\n" .. label )
    if rules == nil then
        print( "\tnil\n" )
        return
    end
    
    print( "\tdefinition    : " .. tostring( rules.definition ) )
    print( "\tduration      : " .. tostring( rules.duration ) )
    print( "\tisDaR         : " .. tostring( rules.isDurationAndRule ) )
    print( "\t#loadFilters  : " .. tostring( table.countKeyValuePairs( rules.loadFilters ) ) )
    for k, v in pairs( rules.loadFilters ) do
        local n = "nil"
        if v ~= nil then n = v.name end
        print( "\t\t" .. k .. " = " .. v.name )
    end
    print( "\t#unloadFilters: " .. tostring( table.countKeyValuePairs( rules.unloadFilters ) ) )
    for k, v in pairs( rules.unloadFilters ) do
        local n = "nil"
        if v ~= nil then n = v.name end
        print( "\t\t" .. k .. " = " .. v.name )
    end
    
    print()
end


--------------------------------------------------------------------------------

function clearTimeTable( train, except )
    local timetable = train:getTimeTable()
    if timetable == nil then return end
    
    local trainstop, station, stationsettings
    
    while timetable.numStops > 0 do
        trainstop = timetable:getStop( 0 )
        if trainstop ~= nil then
            station = trainstop.station
            if station ~= nil and station ~= except then
                
                -- Remove any reservation from the station
                stationsettings = EEPROM.Settings.FromComponentNickname( station , false )
                stationsettings[ SS_Reserved ] = nil
                station.nick = EEPROM.Settings.ToString( stationsettings, false )
                
            end
            
            --dumpTrainRuleSet( "clearTimeTable()", trainstop:getRuleSet() )
            
        end
        
        timetable:removeStop( 0 )
    end
end


--------------------------------------------------------------------------------

local Settings_TrainParked = { [ TS_Status ] = TS_Status_Parked }
local TrainParked = EEPROM.Settings.ToString( Settings_TrainParked, false )
function parkTrain( train, at )
    --print( "parkTrain() : " .. train.internalName )
    updateSelfDriving( train, false )
    clearTimeTable( train, at )
    train:setName( TrainParked )
end


--------------------------------------------------------------------------------

function clearReservationsFor( train )
    
    local tname = train.internalName
    
    for index = 1, #stations do
        local station = stations[ index ]
        local settings = EEPROM.Settings.FromComponentNickname( station, false )
        local reservedby = settings[ SS_Reserved ]
        if reservedby == tname then
            settings[ SS_Reserved ] = nil
            EEPROM.Settings.ToComponentNickname( station, settings )
        end
    end
    
end



--------------------------------------------------------------------------------

function makeTrainDockingRuleSet( duration, definition, isDurationAndRule, loaditems, unloaditems )
    
    if duration == nil or type( duration ) ~= "number" or duration < 1 then duration = 1 end
    if definition == nil or type( definition ) ~= "number" or definition < 0 or definition > 1 then definition = 1 end
    if isDurationAndRule == nil or type( isDurationAndRule ) ~= "boolean" then isDurationAndRule = true end
    
    local loadFilters = {}
    if loaditems ~= nil and type( loaditems ) == "table" then
        for k, v in pairs( loaditems ) do
            if v ~= nil then loadFilters[ #loadFilters + 1 ] = v end
        end
    end
    
    local unloadFilters = {}
    if unloaditems ~= nil and type( unloaditems ) == "table" then
        for k, v in pairs( unloaditems ) do
            if v ~= nil then unloadFilters[ #unloadFilters + 1 ] = v end
        end
    end
    
    return {
        duration = duration,
        definition = definition,
        isDurationAndRule = isDurationAndRule,
        loadFilters = loadFilters,
        unloadFilters = unloadFilters,
    }
end

local DepotRules = makeTrainDockingRuleSet( 999999, 1, true, { findItem( "Alien Protein" ), findItem( "Power Shard" ) }, { findItem( "Beryl Nut" ) } )


--------------------------------------------------------------------------------

function routeTrainTo( train, station, rules )
    --print( "routeTrainTo() : " .. train.internalName .. " -> " .. station.name )
    clearTimeTable( train )
    
    local timetable = train:newTimeTable()
    if timetable == nil then
        print( "routeTrainTo() : Unable to create new TimeTable : " .. train.internalName .. " : " .. station.name )
        return
    end
    
    --dumpTrainRuleSet( "param: rules", rules )
    
    if not timetable:addStop( 0, station, rules ) then
        print( "routeTrainTo() : Unable to add station to TimeTable : " .. train.internalName .. " : " .. station.name )
        return
    end
    
    --dumpTrainRuleSet( "getRuleSet()", timetable:getStop( 0 ):getRuleSet() )
    
    local trainsettings = { [ TS_Status ] = TS_Status_Transit }
    
    local stationsettings = EEPROM.Settings.FromComponentNickname( station , false )
    stationsettings[ SS_Reserved ] = train.internalName
    
    train:setName( EEPROM.Settings.ToString( trainsettings, false ) )
    EEPROM.Settings.ToComponentNickname( station, stationsettings, false )
    updateSelfDriving( train, true )
    
end


--------------------------------------------------------------------------------

function getCurrentTrainStop( train )
    local timetable = train:getTimeTable()
    if timetable == nil then return nil end
    if timetable.numStops == 0 then return nil end
    local stopIndex = timetable:getCurrentStop()
    local trainstop = timetable:getStop( stopIndex )
    if trainstop == nil then return nil end
    return trainstop.station
end


--------------------------------------------------------------------------------
function getParkedTrainStop( train )
    local settings = EEPROM.Settings.FromString( train:getName(), false )
    local status = string.lower( settings[ TS_Status ] or '' )
    if status ~= TS_Status_Parked then return nil end
    
    local station = getClosestPhysicalStationToTrain( train, stations )
    if station == nil then return nil end
    
    local d = distanceBetween( train, station )
    if d > TrainManager.STATION_ACCEPTABLE_DISTANCE_MAX then return nil end
    
    return station
end


--------------------------------------------------------------------------------

function confirmReservations()
    -- Go through the stations and clear all the reservations
    for index = 1, #stations do
        local station = stations[ index ]
        local settings = EEPROM.Settings.FromComponentNickname( station, false )
        settings[ SS_Reserved ] = nil
        EEPROM.Settings.ToComponentNickname( station, settings, false )
    end
    
    -- Go through the trains and force all reservations again
    for index = 1, #trains do
        local train = trains[ index ]
        
        local station = getCurrentTrainStop( train ) or getParkedTrainStop( train )
        if station ~= nil then
            -- Train is travelling to or parked at the station, reserve it
            
            local settings = EEPROM.Settings.FromComponentNickname( station, false )
            settings[ SS_Reserved ] = train.internalName
            EEPROM.Settings.ToComponentNickname( station, settings, false )
            
        end
    end
end


--------------------------------------------------------------------------------

function renderText( x, y, t, f, b )
    
    if f ~= nil then
        gpu:setForeground( f.r, f.g, f.b, f.a )
    end
    if b ~= nil then
        gpu:setBackground( b.r, b.g, b.b, b.a )
    end
    gpu:setText( x, y, t )
    
end


-- Column resolvers

local function SC_StationName( station )
    local name = station.name
    return name, nil, nil, #name
end

local function SC_ReservedBy( station )
    local settings = EEPROM.Settings.FromComponentNickname( station, false )
    local reservedby = settings[ SS_Reserved ] or ''
    return reservedby, nil, nil, #reservedby
end

local function SC_Location( station )
    local v = Vector3f.ToString( station.location, LocationPattern )
    return v, nil, nil, #v
end

local function TC_TrainName( train )
    local name = train.internalName
    return name, nil, nil, #name
end

local function TC_Status( train )
    local settings = EEPROM.Settings.FromString( train:getName(), false )
    local status = string.lower( settings[ TS_Status ] or '' )
    return status, nil, nil, #status
end

local function TC_NextStop( train )
    local name = ''
    local station = getCurrentTrainStop( train ) or getParkedTrainStop( train )
    if station ~= nil then
        name = station.name
    end
    return name, nil, nil, #name
end

local function TC_Speed( train )
    local loco = train:getVehicles()[ 1 ]
    local movement = loco:getMovement()
    local speed = string.format( "%6.2f km/h", ( movement.speed / TrainManager.SPEED_CONSTANT ) )
    return speed, nil, nil, #speed
end

local function TC_Location( train )
    local loco = train:getVehicles()[ 1 ]
    local v = Vector3f.ToString( loco.location, LocationPattern )
    return v, nil, nil, #v
end

local function TC_Distance( train )
    local v = ''
    local station = getCurrentTrainStop( train ) or getParkedTrainStop( train )
    if station ~= nil then
        local d = distanceBetween( train, station )
        v = string.format( "%6.0f m", d )
    end
    return v, nil, nil, #v
end


function createStationCollimator()
    
    local c = {}
    c[ #c + 1 ] = _Column.new( { header = 'Station Name', width = 20, resolver = SC_StationName } )
    c[ #c + 1 ] = _Column.new( { header = 'Reserved By' , width = 24, resolver = SC_ReservedBy  } )
    --c[ #c + 1 ] = _Column.new( { header = 'Location'    , width = 22, resolver = SC_Location  } )
    
    local result, reason = _Collimator.new( {
        columns     = c,
        padding     = 1,
        drawText    = renderText,
     } )
    if result == nil then
        computer.panic( reason )
    end
    
    return result
end

function createTrainCollimator()
    
    local c = {}
    c[ #c + 1 ] = _Column.new( { header = 'Train ID'    , width = 24, resolver = TC_TrainName   } )
    c[ #c + 1 ] = _Column.new( { header = 'Status'      , width =  8, resolver = TC_Status      } )
    c[ #c + 1 ] = _Column.new( { header = 'Next Stop'   , width = 20, resolver = TC_NextStop    } )
    c[ #c + 1 ] = _Column.new( { header = 'Speed'       , width = 11, resolver = TC_Speed       } )
    c[ #c + 1 ] = _Column.new( { header = 'Distance'    , width =  8, resolver = TC_Distance    } )
    --c[ #c + 1 ] = _Column.new( { header = 'Location'    , width = 22, resolver = TC_Location    } )
    
    local result, reason = _Collimator.new( {
        columns     = c,
        padding     = 1,
        drawText    = renderText,
     } )
    if result == nil then
        computer.panic( reason )
    end
    
    return result
end

local stationCollimator = createStationCollimator()
local trainCollimator   = createTrainCollimator()

function drawData()
    local y = 0
    
    
    gpu:setBackground( 0.0, 0.0, 0.0, 1.0 )
    gpu:setForeground( 1.0, 1.0, 1.0, 1.0 )
    
    gpu:fill( 0, 0, screenX, screenY, ' ' )
    
    
    --gpu:setText( 0, y, "stations: " .. tostring( #stations ) )
    stationCollimator:drawHeaders( 0, y )
    y = y + 1
    for index = 1, #stations do
        local station = stations[ index ]
        stationCollimator:drawTable( 0, y, station )
        --[[
        local settings = EEPROM.Settings.FromComponentNickname( station, false )
        local reservedby = settings[ SS_Reserved ]
        
        gpu:setText( 1, y, station.name )
        if reservedby ~= nil then
            gpu:setText( 21, y, reservedby )
        end
        gpu:setText( 61, y, Vector3f.ToString( station.location, LocationPattern ) )
        ]]
        y = y + 1
    end
    y = y + 1
    
    
    --gpu:setText( 0, y, "trains: " .. tostring( #trains ) )
    trainCollimator:drawHeaders( 0, y )
    y = y + 1
    for index = 1, #trains do
        
        local train = trains[ index ]
        trainCollimator:drawTable( 0, y, train )
        
        --[[
        local settings = EEPROM.Settings.FromString( train:getName(), false )
        local status = string.lower( settings[ TS_Status ] or '' )
        local loco = train:getVehicles()[ 1 ]
        local movement = loco:getMovement()
        local station = nil
        
        gpu:setText( 1, y, train.internalName )
        y = y + 1
        
        gpu:setText( 1, y, "status: " .. status )
        y = y + 1
        
        gpu:setText( 2, y, string.format( "speed: %5.2fkm/h", ( movement.speed / TrainManager.SPEED_CONSTANT ) ) )
        y = y + 1
        
        gpu:setText( 2, y, Vector3f.ToString( loco.location, LocationPattern ) )
        y = y + 1
        
        if train.isSelfDriving then
            station = getCurrentTrainStop( train )
        else
            station = getClosestPhysicalStationToTrain( train, stations, true )
        end
        if station ~= nil then
            local d = distanceBetween( train, station )
            local t = string.format( "%5.2fm %s", d, station.name )
            gpu:setText( 2, y, t )
            y = y + 1
        end
        ]]
        
        y = y + 1
    end
    y = y + 1
    
    gpu:flush()
    
end


--------------------------------------------------------------------------------

function updateTrains()
    --print( "\nupdateTrains()" )
    
    for index = 1, #trains do
        
        local train = trains[ index ]
        --print( "\t", index, train.internalName )
        
        local settings = EEPROM.Settings.FromString( train:getName(), false )
        local status = string.lower( settings[ TS_Status ] or '' )
        local loco = train:getVehicles()[ 1 ]
        local movement = loco:getMovement()
        
        --[[
        print( string.format( "\t\tstatus: '%s'\n\t\tselfDrive: %s\n\t\tspeed: %5.2fkm/h",
            status,
            tostring( train.isSelfDriving ),
            ( movement.speed / TrainManager.SPEED_CONSTANT ) ) )
        ]]
        
        if status == nil or status == '' then
            -- Train is undefined, don't do anything with it yet
            
        elseif status == TS_Status_Player then
            -- Train is being used by a player, just do a runaway check on it
            
            if movement.isMoving then
                local s = TS_Status_Player
                if train.isPlayerDriven
                or train.isSelfDriving then
                    s = TS_Status_Player
                else
                    s = TS_Status_Runaway
                end
                settings[ TS_Status ] = s
                train:setName( EEPROM.Settings.ToString( settings, false ) )
            end
            
        elseif status == TS_Status_Ready then
            -- Train has just been marked ready by the player
            -- Route it to the closest depot
            
            local depot = getClosestPhysicalStationToTrain( train, stations, true )
            if depot == nil then
                print( "updateTrains() : Unable to find a depot to send train to : " .. train.internalName )
            else
                routeTrainTo( train, depot, DepotRules )
            end
            
        elseif status == TS_Status_Runaway then
            -- The train is rolling on it's own without guidance
            -- Route it to the closest depot after 30 seconds - give the player a chance to catch their train
            
            local routeontick = tonumber( settings[ "routeontick" ] )
            if routeontick == nil then
                routeontick = computer.millis() + TrainManager.RUNAWAY_TIMEOUT
                settings[ "routeontick" ] = routeontick
                train:setName( EEPROM.Settings.ToString( settings, false ) )
            end
            
            if computer.millis() >= routeontick then
                local depot = getClosestPhysicalStationToTrain( train, stations, true )
                if depot == nil then
                    print( "updateTrains() : Unable to find a depot to send train to : " .. train.internalName )
                else
                    routeTrainTo( train, depot, DepotRules )
                end
            end
            
        elseif status == TS_Status_Parked then
            -- Train is waiting for a job
            
            if movement.isMoving then
                
                local s = nil
                if train.isPlayerDriven then
                    s = TS_Status_Player
                elseif train.isSelfDriving then
                    s = TS_Status_Transit
                else
                    s = TS_Status_Runaway
                end
                settings[ TS_Status ] = s
                train:setName( EEPROM.Settings.ToString( settings, false ) )
                clearReservationsFor( train )
                
            else
                local depot = getClosestPhysicalStationToTrain( train, stations, true )
                if depot ~= nil then
                    local d = distanceBetween( train, depot )
                    if d > TrainManager.STATION_ACCEPTABLE_DISTANCE_MAX then
                        -- Send the train back to the depot
                        routeTrainTo( train, depot, DepotRules )
                    end
                end
            end
            
        elseif status == TS_Status_Transit then
            -- Train is on the job, check to see how it's doing
            
            if not movement.isMoving then
                -- Train is waiting somewhere, has it reached it's goal?
                local dest = getCurrentTrainStop( train )
                if dest == nil then
                    --print( "\t\ttrain is in transit to no destination???" )
                    local depot = getClosestPhysicalStationToTrain( train, stations, true )
                    if depot == nil then
                        print( "updateTrains() : Unable to find a depot to send train to : " .. train.internalName )
                    else
                        routeTrainTo( train, depot, DepotRules )
                    end
                else
                    
                    local d = distanceBetween( train, dest )
                    --local t = string.format( "%5.2fm %s", d, dest.name )
                    --print( "\t\tdestination: ", t )
                    
                    -- Has the train reached the destination?
                    if d <= TrainManager.STATION_ACCEPTABLE_DISTANCE_MAX then
                        if isDepot( dest ) then
                            -- Train is done it's job, park it at the depot
                            parkTrain( train, dest )
                        else
                            -- Advance the job
                        end
                    end
                    
                end
                
            else
                -- Train is moving, leave it be - we only make decisions when it's stopped
            end
        end
    end
    
end



--------------------------------------------------------------------------------

confirmReservations()

while true do
    drawData()
    updateTrains()
    event.pull( 0.25 )
end
