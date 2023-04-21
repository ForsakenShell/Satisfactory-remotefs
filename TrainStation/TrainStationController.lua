---
--- Created by 1000101
--- DateTime: 23/03/2023 12:07 am
---




--------------------------------------------------------------------------------

TrainStationController          = {}
TrainStationController.__index  = TrainStationController






--------------------------------------------------------------------------------

local StorageMonitor            = require( "/lib/StorageMonitor.lua", EEPROM.Remote.CommonLib )
local PlatformController        = require( "/lib/PlatformController.lua" )
local ClassGroup                = require( "/lib/classgroups.lua", EEPROM.Remote.CommonLib )
local GPUs                      = ClassGroup.Displays.GPUs
local Screens                   = ClassGroup.Displays.Screens
local SolidStorage              = ClassGroup.Storage.Solids
local WidgetSigns               = ClassGroup.Displays.Signs.WidgetSigns




local MAIN_UPDATE_TIME          = 1.0
local DISPLAY_UPDATE_TIME       = 1000


local itemSettingsKey           = "item"


---StorageMonitors
local Monitors                  = {}
---PlatformControllers
local Platforms                 = {}
---Dispatch station
--local Dispatcher                = nil



function findCompWithSetting( comps, key, value )
    if comps == nil or type( comps ) ~= "table" then return nil end
    if key == nil or type( key ) ~= "string" or key == '' then return nil end
    if value == nil or type( value )  ~= "string" or value == '' then return nil end
    local lkey = string.lower( key  )
    for _, comp in pairs( comps ) do
        
        local settings = EEPROM.Settings.FromComponentNickname( comp, true )
        local setting = settings[ lkey ]
        if setting ~= nil and setting == value then return comp end
        
    end
    return nil
end






function createStorageMonitors()
    
    local storageContainers = component.getComponentsByClass( SolidStorage )
    local signage = component.getComponentsByClass( WidgetSigns.All )
    
    -- Go through the found storage containers and make monitors for them
    for _, storage in pairs( storageContainers ) do
        
        print( storage.internalName )
        
        local nick = storage.nick
        local settings = EEPROM.Settings.FromString( nick, true )
        
        local iname = settings[ string.lower( itemSettingsKey ) ]
        if iname == nil or iname == '' then
            computer.panic( debug.traceback( "Storage Container does not have a valid item key\n\t" .. storage.internalName .. "\n\t" .. nick ) )
        end
        
        local item = findItem( iname )
        if item == nil then
            computer.panic( debug.traceback( "Storage Container does not have a valid item key, could not resolve item\n\t" .. storage.internalName .. "\n\t" .. nick ) )
        end
        
        local monitor = StorageMonitor.new( {
            item = item,
            storage = storage,
            sign = findCompWithSetting( signage, itemSettingsKey, iname ),
        } )
        if monitor == nil then
            computer.panic( debug.traceback( "Could not create StorageMonitor for Storage Container\n\t" .. storage.internalName .. "\n\tnick='" .. nick .. "'" ) )
        end
        table.insert( Monitors, monitor )
        monitor:updateSigns()
        
    end
    
end

function createPlatformControllers()
    
    local stations = component.getComponentsByClass( ClassGroup.TrainStations.All )
    
    print( "#stations = ", #stations )
    
    -- Go through the found stations and make controllers for them
    for _, station in pairs( stations ) do
        
        print( station, station.name )
        
        local stationID = tonumber( EEPROM.Settings.FromComponentNickname( station )[ "station" ] )
        if stationID == nil or type( stationID ) ~= "number" then
            computer.panic( debug.traceback( "Invalid station ID, must be a positive integer uniquely identifying this platform amongst the other platforms for this station" ) )
        end
        
        --if stationID == 0 then
        --    print( "\tFound input dispatch station" )
        --    Dispatcher = station
        --    
        --elseif stationID > 0 then
        if stationID > 0 then
            local controller = PlatformController.new( station )
            if controller == nil then
                computer.panic( debug.traceback( "Could not create PlatformController for Train Station Platform\n\t" .. station.internalName .. "\n\tnick='" .. station.nick .. "'" ) )
            end
            table.insert( Platforms, controller )
        else
            computer.panic( debug.traceback( "Invalid station ID, must be a positive integer uniquely identifying this platform amongst the other platforms for this station" ) )
        end
        
    end
    
end




function getGPUScreen()
    
    local gpu = computer.getPCIDevicesByClass( GPUs.GPU_T1_C )[ 1 ]
    if gpu == nil then
        computer.panic( "No GPU" )
    end
    
    local w = 2
    local h = 2
    local screen = computer.getPCIDevicesByClass( Screens.ScreenDriver_C )[ 1 ]     -- Try PCI screen first
    if screen == nil then
        screen = component.getComponentsByClass( Screens.Build_Screen_C )[ 1 ]      -- Try Component screen second
        if screen ~= nil then w, h = screen:getSize() end
    end
    if screen == nil then
        computer.panic( debug.traceback( "No Screen" ) )
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


function updateDisplays()
    
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
        monitor:updateSigns()
        y = y + 1
    end
    
    y = 10
    for _, controller in pairs( Platforms ) do
        local ly = 0
        gpu:setText( 0, y + ly, "Station Status: " .. controller.station.name )
        ly = ly + 1
        gpu:setText( 3, y + ly, controller.status )
        ly = ly + 1
        
        local requests = controller.transfers
        if requests ~= nil then
            for _, request in pairs( requests ) do
                gpu:setText( 3, y + ly, "Platform " .. request.target .. " : " .. request:status() )
                ly = ly + 1
            end
        end
        
        y = y + ly
    end
    
    gpu:flush()
end


function listenToPlatforms()
    
    -- We don't actually care about the merger events, just need to get event.pull() to pump the loop at full belt speed
    for _, controller in pairs( Platforms ) do
        for _, merger in pairs( controller.mergers ) do
            event.listen( merger )
        end
    end
    
    -- We do want train arrival signals
    --for _, station in pairs( stations ) do   -- Well, we would but there aren't any, so we'll have to poll for it
    --    event.listen( station )
    --end
    
    -- Are there signals on the signals we can listen for?  If so, the entrance/exit signal for the station can be monitored
end


createStorageMonitors()
createPlatformControllers()

--if Dispatcher == nil then
--    computer.panic( "Unable to locate dispatch station (station ID 0) ")
--end


-- Prepare event handling
event.clear()
event.ignoreAll()
listenToPlatforms()

local nextUpdate = 0

while true do
    local timestamp = computer.millis()
    if timestamp > nextUpdate then
        -- Updating the screen too often tanks FPS, if we could get the player distance then we'd make it only update when they are right near it
        updateDisplays()
        nextUpdate = timestamp + DISPLAY_UPDATE_TIME
    end
    
    local edata = { event.pull( MAIN_UPDATE_TIME ) }
    if edata ~= nil and edata[ 1 ] ~= nil then
        --local e = edata[ 1 ]
        --local s = edata[ 2 ]
        --print( tostring( computer.millis() ), e, s )
        
        local handled = PlatformController.handleEvent( edata )
    end
    
    for _, controller in pairs( Platforms ) do
        controller:factoryTick()
    end
    
    --[[
    if true then
        local loco = Dispatcher:getDockedLocomotive()
        if loco ~= nil then
            local train = loco:getTrain()
            local t = string.format( "%9d : train : %d : %s", computer.millis(), train.dockState, tostring( train.isDocked ) )
            local vehicles = train:getVehicles()
            for index, vehicle in pairs( vehicles ) do
                local rt  = PlatformController.railcarType( vehicle )
                local rtn = PlatformController.railcarTypeName( rt )
                t = string.format( "%s\n\t%d : %d %s", 
                    t, index,
                    rt, rtn )
            end
        end
    end
    ]]
    
end
