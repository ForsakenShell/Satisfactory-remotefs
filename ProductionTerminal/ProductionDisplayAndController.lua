____VERSION_FULL = { 1, 3, 10, 'b' }
-- This will get updated with each new script release Major.Minor.Revision.Hotfix
-- Revision/Hotfix should be incremented every change and can be used as an "absolute version" for checking against
-- Do not move from the topline of this file as it is checked remotely
-- Also be sure to update ProductionDisplayAndController.lua.version to match

--[[ Production Display and Controller

This script will control a "bank" of "Machines" (Manufacturers or Extractors) power via a CircuitSwitch, valves
(for fluids) and, codeable mergers (for solids).

This monitors the inventory levels of an FGBuildableStorage or PipeReservoir (ie, Storage Container, Fluid Buffer,
etc) and sets the CircuitSwitch on/off state depending on the inventory level and the programmable thresholds.

All RSS Buildable Signs (optimized for 2:1) connected to the network will have the "pretty format" display for
monitoring at a distance.

Detailed monitoring of individual machines performance and will be output all the Screen (Build_Screen_C only)
on the network.  At least one GPU and Screen is required, additional are optional.

Network Setup:
|
+- Computer:
|   1   T1-CPU (Lua)
|   1   T1-RAM
|   0+  T1-GPU
|   1   EEPROM with remotefs bootloader
|   nickname settings: remotefs="ProductionTerminal" bootloader="ProductionDisplayAndController.lua"
|
+- "Screen":
|   0+  2x? "panel" Build_Screen_C - Serves as the primary way to display detailed information of the
|       Machines, Storage, thresholds, power status, etc.  All screens will display the same information.
|       The computer will tell you the screen size required to fit all the information, typically as 2x2 or a
|       2x3 configuration is sufficient for most situations but large storage/production machine arrays may
|       require more.
|       NOTE:  Each Screen requires it's own GPU in the Computer to drive it.
|       NOTE:  You do not need a screen+GPU or any RSS Signs for this script to function, you will just
|           get no feedback beyond the controlled behaviour of the switch and machines.
|
+- "CircuitSwitch":
|   1   Power Switch (or compatible) connected for controlling power flow to the Machines.  This can control
|       exactly one or no switches, more than one doesn't make sense for the purpose of this script.
|
+- "Manufacturer" or "FGBuildableResourceExtractorBase" class "Machines"
|   1+  As many as you want, however they must be the same class and producing the same recipe/extracting the
|       same resource.
|       See the Reflection Viewer for class details and subclasses of said classes.
|
+- "FGBuildableStorage" OR "PipeReservoir":
|   1+  This is the "Storage" for this controller.  This script monitors the Storage levels and turns the bank
|       of Machines on/off as needed.  The type of Storage must match the Recipe "main result" - the first
|       "primary" in the array returned from recipe:getProducts().  That is, if the Recipe produces a Liquid then
|       the Storage must be PipeReservoir, otherwise it must be FBBuildableStorage.
|
+- RSS Signs (optional):
|   0+  Any RSS Sign with a 2:1 display ratio will work.  Intended for billboards and large wall signs to be seen
|       at a distance containing less information but with "pretty formatting".  Displays the machine icon, primary
|       icon, recipe name, storage level (current and max), storage flow rate and, power status of the machine
|       bank.  Currently there is no way to add or remove elements from the sign so templates that can be applied
|       have been provided along-side this script for each 2:1 sign (2x1, 8x4, 16x8).  Additionally, the user (you)
|       must set the icons on the sign as at the moment there is no way to do so from Lua.  Well, there is but there
|       is no way to get the texture to set.
|
+- "PipelinePump" (optional):
|   0+  Only for Fluid primary outputs, can open and close the valve when the Machines are turned on and off,
|       respectively.


]]--


-- Versioning --
local versionString = getVersionString( ____VERSION_FULL )
--[[ version history
1.0.0
 + Initial release
1.0.1 - Bugfix?
 + Can't remember, didn't start versioning until after I fixed this and I forgot what I fixed
1.0.2
 + Fixed fluid scaling, 1m3 is reported as 1000 so we need to divide fluid amount by 1000
1.1.3
 + Adds optional output PipelinePump (valve) control
 + Changes the CircuitSwitch from required to optional
 + Fixes columnation of the input/output units
1.1.4 - Last EEPROM only version
 + Fixes not actually getting the valves that are controlled
1.2.5
 + Moved to remotefs, removed redundant functions
 + Increases default loop update time from 0.25s to 1.0s to reduce system lag
 + Moves the Online/Offline status to the upper-left corner
 + Adds a new storage area to the bottom for when no RSS Sign is being used for pretty printing
1.2.6
 + Extractors now listen for their factory connector outputs to send an item to determine what they produce
1.3.7
 + Overhaul of the guts
1.3.7a
 + Extractors now set the main title bar
1.3.8
 + New sexy fill bar and online/offline indicator
 + Codeable Merger in-flow support; will only let items through and only while the system is turned on;
   this is basically valves for solids
1.3.9
 + Adds support for optional single module panel with a button at {0,0} to reflash the EEPROM and reboot the terminal
 + Script can now be completely headless for use before unlocking GPUs, Large Screens and/or RSS Signs
 + Major overhaul of how the machine and storage data is gathered and displayed making them give more information and more readable at the same time
1.3.10
 + Remote versioning support, Terminal and EEPROM software version numbers will change color based on version difference:
    green = version is current
    yellow = version is old
    grey = can't check - current EEPROM is too old and does not support required functionality
    white = system has not yet checked
    red = error - see console output
]]



if ____Disk_UUID ~= nil and ____Disk_UUID ~= '' then
    -- A disk in the Production Terminal computer means the player is doing some
    -- maintainence on the network and will want a full log of events.
    require( "/lib/ConsoleToFile.lua", ____RemoteCommonLib )
end





-- requires --
local utf8                      = require( "/lib/utf8.lua", ____RemoteCommonLib )
local ClassGroup                = require( "/lib/classgroups.lua", ____RemoteCommonLib )
local GPUs                      = ClassGroup.Displays.GPUs
local Screens                   = ClassGroup.Displays.Screens
local SolidStorage              = ClassGroup.Storage.Solids
local FluidStorage              = ClassGroup.Storage.Fluids
local RSSSigns                  = ClassGroup.Displays.Signs.ReallySimpleSigns
local UIO                       = require( "/lib/UIOElements.lua" )
local Collimator                = require( "/lib/Collimator.lua", ____RemoteCommonLib )
local RSSBuilder                = nil -- We will require this as needed
--RSSBuilder = require( "/lib/RSSBuilder.lua", ____RemoteCommonLib )



-- Operational Controls --

local programAllMachines = true         -- Program all the machines with the first recipe found (so you can be lazy and only set one machine)

local timesliceSeconds = 0.125          -- Place nice and timeslice!  0.125s between internal timeslices
local cycleUpdateMS = 100               -- Update the signs every X ms, default is 100 (0.1 seconds); regardless of events, this is how often the control logic is updated
local signUpdateMS = 1000               -- Update the signs every X ms, default is 1000 (1 second); faster updates just lag the game, if there was player proximity detection then we might consider making this variable but there isn't so we won't
local throughputUpdateMS = 10000        -- Update the throughput rate monitoring every X ms, default is 10000 (10 seconds); more time = more accurate but less frequent display updates of the "rate"
local softwareUpdateMS = 60000          -- Only check for software updates once every 10 minutes, we don't need to hammer this and if we're smarter then we have .version files on the remote so we only need to transmit a few bytes an hour instead of several hundreds of kilobytes

local triggerOnThreshold = 0.25         -- 0.00 to 1.00 as a percent - TODO:  Convert to a potentiometer
local triggerOffThreshold = 1.00        -- 0.00 to 1.00 as a percent - TODO:  Convert to a potentiometer



-- Control Constants - Don't mess with these --
local panelsWide = 2                    -- Consant because magic numbers are bad, never change as things ARE coded for this width
local screenCCPP = 30                   -- Screen Width in Character Columns Per Panel
local screenCRPP = 15                   -- Screen Height in Character Rows Per Panel



-- String constants --
local prodOverallTitle = "Overall"
local storOverallTitle = "Storage"


-- Storage constants --
local INV_STORAGE   = 'StorageInventory'
local INV_INPUT     = 'InputInventory'
local INV_OUTPUT    = 'OutputInventory'
local INV_SHARD     = 'InventoryPotential'

function getInventoryByName( proxy, inventory )
    local inventories = proxy:getInventories()
    for _, inv in pairs( inventories ) do
        if inv.internalName == inventory then return inv end
    end
    return nil
end

local INV_STATUS     = { "○", "◒", "●" } -- { "\u{25CB}", "\u{25D2}", "\u{25CF}" } -- empty circle, half full circle, full circle
local PWR_STATUS_OFF = "☼" -- "\u{263C}" -- Sub With Rays
local PWR_STATUS_ON = { "", "", "", "", "", "" } -- { "\u{EE06}", "\u{EE07}", "\u{EE08}", "\u{EE09}", "\u{EE0A}", "\u{EE0B}" } -- Spiny circle


-- Some Colors for the RSS Signs and Screens --
local cRed    = { r = 1.0 , g = 0.0 , b = 0.0 , a = 1.0  }
local cYellow = { r = 1.0 , g = 1.0 , b = 0.0 , a = 1.0  }
local cGreen  = { r = 0.0 , g = 1.0 , b = 0.0 , a = 1.0  }
local cBlue   = { r = 0.0 , g = 0.0 , b = 1.0 , a = 1.0  }
local cCyan   = { r = 0.25, g = 1.0 , b = 1.0 , a = 1.0  }
local cWhite  = { r = 1.0 , g = 1.0 , b = 1.0 , a = 1.0  }
local cGrey   = { r = 0.25, g = 0.25, b = 0.25, a = 1.0  }
local cBlack  = { r = 0.0 , g = 0.0 , b = 0.0 , a = 1.0  }

local cTitle  = { r = 0.98, g = 0.58, b = 0.28, a = 0.25 } -- A close approximation to Ficsit Orange without being too saturated


-- Initial version colors
local vcTerminal = cWhite
local vcEEPROM = cWhite


local nextVersionCheck = -1
function versionCheck()
    local newTimestamp = computer.millis()
    if newTimestamp < nextVersionCheck then return end
    
    nextVersionCheck = newTimestamp + softwareUpdateMS
    
    -- Requires EEPROM version 7a or later
    if ____EEPROM_VERSION_FULL == nil then
        vcTerminal = cGrey
        vcEEPROM = cGrey
        return end
    local cRevision = getVersionCheckVersion( ____EEPROM_VERSION_FULL )
    if cRevision < 7.01 then
        vcTerminal = cGrey
        vcEEPROM = cGrey
        return end
    
    -- Check for an EEPROM update
    local version, reason = getRemoteEEPROMVersion()
    if version == nil then
        print( "Unable to check remote EEPROM version:\n" .. reason )
        vcEEPROM = cRed
    else
        local rRevision = getVersionCheckVersion( version )
        if cRevision < rRevision then
            vcEEPROM = cYellow
            print( "New EEPROM version available: " .. getVersionString( version ) )
        else--if cRevision >= rRevision then
            vcEEPROM = cGreen
        end
    end
    
    -- Check for a Terminal (boot loader) update
    local version, reason = getRemoteBootLoaderVersion()
    if version == nil then
        print( "Unable to check remote boot loader version:\n" .. reason )
        vcTerminal = cRed
    else
        cRevision = getVersionCheckVersion( ____VERSION_FULL )
        local rRevision = getVersionCheckVersion( version )
        if cRevision < rRevision then
            vcTerminal = cYellow
            print( "New boot loader version available: " .. getVersionString( version ) )
        else--if cRevision >= rRevision then
            vcTerminal = cGreen
        end
    end
    
end



-- Utility Functions --


function formatNumber( n, leader, decimals, prefixPositive )
    local result = string.format( '%' .. ( leader or 0 ) .. '.' .. ( decimals or 0 ) .. 'f', n )
    prefixPositive = prefixPositive or false
    if prefixPositive and n > 0 then
        result = '+' .. result
    end
    return result
end


function round( a )
    return math.floor( a + 0.5 )
end


function unitsForItem( item )
    if item.isFluid then
        return "m³/m"
    end
    return "p/m"
end


function listProxiesAs( label, proxies, panicIfNone, panicIfDifferentTypes )
    if proxies == nil or #proxies == 0 then
        if panicIfNone ~= nil and panicIfNone then
            computer.panic( "No " .. label .. " detected!" )
        end
        print( "WARNING:  No " .. label .. " detected." )
        return
    end
    
    if #proxies > 1 and panicIfDifferentTypes ~= nil and panicIfDifferentTypes then
        -- Exclusive, all results must be the same class
        -- Create a table of all the classes, it's length should be 1
        
        local classes = {}
        for _, proxy in pairs( proxies ) do
            local class = tostring( proxy )
            if not table.hasValue( classes, class ) then
                table.insert( classes, #classes + 1, class )
            end
        end
        
        if #classes ~= 1 then
            local message = "Class mismatch, all " .. label .. " must be the same Class\n" .. #classes .. " different classes were found.\nThe following classes of " .. label .. " were found:"
            for _,class in pairs( classes ) do
                message = message .. "\n\t" .. class
            end
            computer.panic( message )
        end
        
    end
    
    print( label .. ": " .. #proxies )
    for _, proxy in pairs( proxies ) do
        print( ' ' .. proxy.id .. ' ' .. proxy.internalName .. ' (Class: ' .. tostring( proxy ) .. ')' )
    end
end


function listPCIDevicesAs( label, devices, panicIfNone, panicIfDifferentTypes )
    if #devices == 0 then
        if panicIfNone ~= nil and panicIfNone then
            computer.panic( "No " .. label .. " detected!" )
        end
        print( "WARNING:  No " .. label .. " detected." )
        return
    end
    
    if #devices > 1 and panicIfDifferentTypes ~= nil and panicIfDifferentTypes then
        -- Exclusive, all results must be the same class
        -- Create a table of all the classes, it's length should be 1
        
        local classes = {}
        for _, device in pairs( devices ) do
            local class = tostring( device )
            if not table.hasValue( classes, class ) then
                table.insert( classes, #classes + 1, class )
            end
        end
        
        if #classes ~= 1 then
            local message = "Class mismatch, all " .. label .. " must be the same Class\n" .. #classes .. " different classes were found.\nThe following classes of " .. label .. " were found:"
            for _,class in pairs( classes ) do
                message = message .. "\n\t" .. class
            end
            computer.panic( message )
        end
        
    end
    
    print( label .. ": " .. #devices )
    for _, dev in pairs( devices ) do
        print( ' ' .. dev.internalName .. ' (Class: ' .. tostring( dev ) .. ')' )
    end
end



-- GPU --
local gpus = {}


function getGPUs()
    -- Find the GPUs
    gpus = computer.getPCIDevicesByClass( GPUs )
    listPCIDevicesAs( "GPUs", gpus )
end




-- Screens --
local screens = {}


function getScreens()
    -- Find all the Screens
    screens = component.getComponentsByClass( Screens.Build_Screen_C )
    listProxiesAs( "Screens", screens )
    
    -- Final test, all Screens require a GPU, make sure we have GPUs to match!
    if #gpus ~= #screens then
        computer.panic( "Screens and GPUs mismatch!  There must be one GPU per screen and one Screen per GPU!  I mean, c'mon man?" )
    end
    
    -- Now bind the Screens to the GPUs, which doesn't matter, they will all be fed the same data
    if #gpus > 0 then
        for i = 1, #gpus do
            local screen = screens[ i ]
            local pX, pY = screen:getSize()
            gpus[ i ]:bindScreen( screen )
            gpus[ i ]:setSize( pX * screenCCPP, pY * screenCRPP )
        end
        
        -- Clear all the screens of any garbage that may be left over
        screensClear( true )
    end
end


function screensClear( commit )
    
    for _, gpu in pairs( gpus ) do
        
        local screenWidth, screenHeight = gpu:getSize()
        
        gpu:setBackground( 0.0, 0.0, 0.0, 1.0 )
        gpu:setForeground( 0.0, 0.0, 0.0, 1.0 )
        gpu:fill( 0, 0, screenWidth, screenHeight, 'X' )
        
        if commit ~= nil and commit then
            gpu:flush()
        end
    end
    
end


function screensCommit()
    for _, gpu in pairs( gpus ) do
        gpu:flush()
    end
end


function screensFill( x, y, w, h, c, f, b )
    
    for _, gpu in pairs( gpus ) do
        
        if f ~= nil then
            gpu:setForeground( f.r, f.g, f.b, f.a )
        end
        if b ~= nil then
            gpu:setBackground( b.r, b.g, b.b, b.a )
        end
        gpu:fill( x, y, w, h, c )
        
    end
    
end


function screensSetText( x, y, t, f, b )
    
    for _, gpu in pairs( gpus ) do
        
        if f ~= nil then
            gpu:setForeground( f.r, f.g, f.b, f.a )
        end
        if b ~= nil then
            gpu:setBackground( b.r, b.g, b.b, b.a )
        end
        gpu:setText( x, y, t )
        
    end
    
end


function screensSetForeground( f )
    for _, gpu in pairs( gpus ) do
        gpu:setForeground( f.r, f.g, f.b, f.a )
    end
end


function screensSetBackground( b )
    for _, gpu in pairs( gpus ) do
        gpu:setBackground( b.r, b.g, b.b, b.a )
    end
end


function updateScreens()
    if #gpus == 0 then return end
    
    local x = 0
    local y = 0
    
    -- Erase everything
    screensClear( false )
    
    
    local screenWidth = panelsWide * screenCCPP
    
    -- Draw Top Bar Title
    screensFill( 0, 0, screenWidth, 1, ' ', cWhite, cTitle )
    screensSetText( 1, 0, getStatusString() )
    x = formatNumber( ( screenWidth - #mainTitle ) / 2 )
    screensSetText( x, 0, mainTitle )
    x = formatNumber( screenWidth - #versionString - 1 )
    screensSetText( x, 0, versionString, vcTerminal )
    y = y + 1
    
    -- Data to record for overall machine data
    local totalRate = 0
    local totalPower = 0
    
    -- Go through and draw each MachineData
    
    MachineData.Collimator:drawHeaders( 1, y )
    y = y + 1
    
    for _, data in pairs( machineData ) do
        MachineData.Collimator:drawTable( 1, y, data )
        totalRate  = totalRate  + data.rate
        totalPower = totalPower + data.power
        y = y + 1
    end
    
    -- Draw Overall Production Title
    y = y + 1
    screensFill( 0, y, screenWidth, 1, ' ', cWhite, cTitle )
    x = formatNumber( ( screenWidth - #prodOverallTitle ) / 2 )
    screensSetText( x, y, prodOverallTitle )
    y = y + 1
    
    
    -- Show how quickly all the machines are eating the inputs
    y = drawCycleData( y, "Input:", inputCycle )
    
    -- Show how slowly all the machines are creating the outputs
    y = drawCycleData( y, "Output:", outputCycle )
    
    
    -- Show the average production rate
    totalRate = totalRate / #machines
    screensSetText( 1, y, "Average Rate: " .. formatNumber( totalRate * 100, 3, 1 ) .. "%" )
    y = y + 1
    
    -- Show the overall power consumption
    screensSetText( 1, y, "Total Power: " .. formatNumber( totalPower, 0, 1 ) .. " MW" )
    
    
    -- Draw Storage Title
    y = y + 2
    screensFill( 0, y, screenWidth, 1, ' ', cWhite, cTitle )
    x = formatNumber( ( screenWidth - #storOverallTitle ) / 2 )
    screensSetText( x, y, storOverallTitle )
    
    -- Go through each Storage, draw it's current, max as well as a neat little bar graph
    for _, data in pairs( storageData ) do
        y = y + 1
        drawStorageLine( y, data.name, data.current, data.max, screenWidth )
    end
    
    -- Draw a storage line for the total storage
    y = y + 2
    drawStorageLine( y, "All Storage:", storageCurrent, storageMax, screenWidth )
    y = y + 1
    drawStorageLine( y, "Thresholds:", thresholdLow, thresholdHigh, screenWidth, storageMax )
    y = y + 1
    drawThroughput( y, 19, 5, 2 )
    
    -- Very bottom row of each screen, draw the the EEPROM version
    drawEEPROMVersion()
    
    -- Commit all GPU buffers to their Screens
    screensCommit()
end

function drawEEPROMVersion()
    
    local t = nil
    if ____EEPROM_VERSION == nil then
        t = 'Unknown EEPROM'
    else
        t = 'EEPROM ' .. ____EEPROM_VERSION
    end
    local w = #t + 1
    
    for _, gpu in pairs( gpus ) do
        local screenWidth, screenHeight = gpu:getSize()
        local y = screenHeight - 1
        local x = screenWidth - w
        
        gpu:setForeground( vcEEPROM.r, vcEEPROM.g, vcEEPROM.b, vcEEPROM.a )
        gpu:setBackground( cTitle.r, cTitle.g, cTitle.b, cTitle.a )
        gpu:fill( 0, y, screenWidth, 1, ' ' )
        gpu:setText( x, y, t )
    end
    
end

function drawCycleData( y, label, dataCycle )
    if dataCycle == nil or #dataCycle == 0 then return y end
    screensSetText( 1, y, label, nil, cBlack )
    y = y + 1
    for _, datum in pairs( dataCycle ) do
        
        local t = "+ " .. datum.name
        local ipm = formatNumber( datum.amount, 0, 2 )
        local tpm = formatNumber( datum.total, 0, 2 )
        
        local pmt = ipm .. '/' .. tpm .. datum.units
        local fill = 49 - utf8.len( t ) - utf8.len( pmt )
        t = t .. string.rep( ' ', fill ) .. pmt
        
        screensSetText( 1, y, t )
        y = y + 1
    end
    return y + 1
end

-- Fira Code Font is fun
local barChars          = { "\u{258F}", "\u{258E}", "\u{258D}", "\u{258C}", "\u{258B}", "\u{258A}", "\u{2589}", "\u{2588}" }
local barFillChar       = "\u{2588}"

function getFillBar( value, max, maxChars )
    local p = ( value / max ) * maxChars
    local b = math.floor( p )
    local r = p - b
    local e = round( r * 8.0 )
    local result = string.rep( barFillChar, b )
    if e > 0 then
        result = result .. barChars[ e ]
        b = b + 1
    end
    return result .. string.rep( " ", maxChars - b )
end

function drawStorageLine( y, name, current, max, ... )
    local varargs = { ... }
    local nmax = 19
    local lname = utf8.len( name )
    if lname > nmax then
        name = utf8.sub( name, 1, nmax )
    else
        name = name .. string.rep( ' ', nmax - lname )
    end
    
    
    -- Draw the status
    local t = string.format( "%s %s/%s", name, formatNumber( current, 5 ), formatNumber( max, 5 ) )
    screensSetText( 1, y, t, cWhite, cBlack )
    
    -- Common fill bar stuff
    local lenT = #t
    
    if #varargs == 1 and type( varargs[ 1 ] ) == "number" then
        -- Draw the fill bar
        local screenWidth = varargs[ 1 ]
        local full = screenWidth - ( lenT + 3 )
        
        --local percent = current / max
        --local fill = round( full * percent )
        --print( screenWidth, full, fill, current, max, percent )
        --t = string.rep( '█', fill ) .. string.rep( ' ', full - fill )
        
        local t = getFillBar( current, max, full )
        screensSetText( lenT + 2, y, t, cGreen, cRed )
    end
    
    if #varargs == 2 and type( varargs[ 1 ] ) == "number" and type( varargs[ 2 ] ) == "number" then
        -- Draw the threshold markers
        local screenWidth = varargs[ 1 ]
        local sMax = varargs[ 2 ]
        
        local full = screenWidth - ( lenT + 3 )
        local low = current / sMax
        local col = lenT + 1 + round( full * low )
        screensSetText( col, y, '^', cRed )
        --print( col )
        
        local high = max / sMax
        col = lenT + 1 + round( full * high )
        screensSetText( col, y, '^', cGreen )
        --print( col )
    end
end

function drawThroughput( y, colX, colL, colD )
    local t = "Net Flow:"
    local colW = 1 + colX + colL + colD
    t = t .. string.rep( ' ', colW - #t ) .. ' ' .. primaryUnits
    screensSetText( 1, y, t, cWhite )
    
    t = formatNumber( throughput.rate, colL, colD, true )
    local c = cWhite
    if throughput.rate < 0.0 then
        c = cRed
    elseif throughput.rate > 0.0 then
        c = cGreen
    end
    screensSetText( 1 + colW - #t, y, t, c )
end




-- CircuitSwitch --
local switch = nil


function getSwitch()
    -- Find the power switch
    local switches = component.getComponentsByClass( ClassGroup.CircuitSwitches.All )
    listProxiesAs( "Switches", switches, true )
    if #switches > 1 then
        computer.panic( "More than one Switch detected!  There should be EXACTLY one!" )
    end
    -- Pull the first (and only) switch from the array
    switch = switches[ 1 ]
end

function updateSwitch()
    -- Only flip the switch if there is a switch to flip
    if switch == nil then
        return
    end
    switch.isSwitchOn = onState
end




-- Item Datums --
function createItemDatumFromItem( item )
    local result = {}
    result.name = item.type.name
    result.isFluid = item.type.form == 2
    
    result.stackSize = item.type.max
    if item[ "amount" ] ~= nil then
        result.amount = item.amount
        if result.isFluid then
            result.amount = result.amount / 1000
        end
    else
        result.amount = 1
    end
    
    return result
end

function getItemDatumsFromItemAmounts( items )
    
    local results = {}
    
    for i, item in ipairs( items ) do
        results[ i ] = createItemDatumFromItem( item )
    end
    
    return results
end


function createPowerShardSlotReference()
    local shard = { amount = 1, type = findItem( "Power Shard" ) }
    local results = {
        createItemDatumFromItem( shard ),
        createItemDatumFromItem( shard ),
        createItemDatumFromItem( shard ),
    }
    -- Overide the stack size for the power shard slots
    for _, slot in pairs( results ) do
        slot.stackSize = 1
    end
    
    return results
end




-- Machines --
MT_INVALID = 0
MT_Manufacturer = 1
MT_Extractor = 2

machineType = MT_INVALID
machines = {}
machineProgress = {}


function getMachines()
    -- Find all the machines
    machines = component.getComponentsByClass( { ClassGroup.ProductionMachines.Manufacturer, ClassGroup.ProductionMachines.FGBuildableResourceExtractorBase } )
    listProxiesAs( "Machines", machines, true, true )
end


function listenToAllFactoryConnectorsByDirection( actors, direction, onlyConnected )
    if onlyConnected == nil or type( onlyConnected ) ~= "boolean" then onlyConnected = true end
    local count = 0
    for _, actor in pairs( actors ) do
        
        local connectors = actor:getFactoryConnectors()
        for _, connector in pairs( connectors ) do
            if connector.direction == direction then
                if not onlyConnected or connector.isConnected then
                    event.listen( connector )
                    count = count + 1
                end
            end
        end
        
    end
    return count
end

function ignoreAllFactoryConnectorsByDirection( actors, direction, onlyConnected )
    if onlyConnected == nil or type( onlyConnected ) ~= "boolean" then onlyConnected = false end
    local count = 0
    for _, actor in pairs( actors ) do
        
        local connectors = actor:getFactoryConnectors()
        for _, connector in pairs( connectors ) do
            if connector.direction == direction then
                if not onlyConnected or connector.isConnected then
                    event.ignore( connector )
                    count = count + 1
                end
            end
        end
        
    end
    return count
end

function handleItemTransfer( edata )
    if edata == nil or type( edata[ 1 ] ) ~= "string" or edata[ 1 ] ~= "ItemTransfer" then return nil, nil end
    
    local connector = edata[ 2 ]
    local item = edata[ 3 ]
    local machine = connector.owner
    
    return machine, item
end

function getMachineOutputItem()
    for _, machine in pairs( machines ) do
        
        local inv = machine:getInventories()[ 1 ]   -- Extractors inventory 1 is their output
        
        local stack = inv:getStack( 0 )             -- Get the primary output
        if stack.item ~= nil and stack.item.type ~= nil then
            return machine, stack.item
        end
    end
    return nil, nil
end

function findMachineWithRecipeOrExtractedItem()
    if #machines == 0 then
        return nil
    end
    
    local m = machines[ 1 ]
    if m[ "getRecipe" ] == nil then
        machineType = MT_Extractor
        print( "Machine Type: Extractor")
    else
        machineType = MT_Manufacturer
        print( "Machine Type: Manufacturer")
    end
    
    local rachine = nil
    local recit = nil
    
    if machineType == MT_Manufacturer then
        for _, machine in pairs( machines ) do
            local recipe = machine:getRecipe()
            if recipe ~= nil then
                print( "Manufacturer: Got recipe by machine" )
                rachine = machine
                recit = recipe
                break
            end
        end
    end
    
    if machineType == MT_Extractor then
        -- Need something to be output by the extractor to it's output
        -- inventory or connector to determine what it extracts
        
        -- See if any machine has an item in an output inventory
        rachine, recit = getMachineOutputItem()
        if rachine ~= nil and recit ~= nil then
            print( "Extractor: Got item by initial output scan" )
        else
            -- Listen to (connected) output connectors (if any) as the item may be removed from the inventory before this script catches it
            if listenToAllFactoryConnectorsByDirection( machines, 1 ) > 0 then-- Output connector
                
                event.clear()
                switch.isSwitchOn = true
                
                local edata = { event.pull( 10.0 ) }    -- Wait for an event, but timeout after 10s
                
                rachine, recit = handleItemTransfer( edata )
                if rachine ~= nil and recit ~= nil then
                    print( "Extractor: Got item by primary event" )
                end
            end
        end
        
        if rachine == nil or recit == nil then
            -- Poop, no event (yet) or no connected connectors, turn machines on and hammer the scanner
            switch.isSwitchOn = true                                    -- Pump it!
            local timeout = computer.millis() + 10000                   -- 10s timeout on hardcore scanner
            while computer.millis() < timeout do
                
                local edata = { event.pull( 0 ) }               -- GO HARD!
                
                rachine, recit = handleItemTransfer( edata )       -- Try an catch an event first
                if rachine ~= nil and recit ~= nil then
                    print( "Extractor: Got item by secondary event" )
                    break
                end
                
                rachine, recit = getMachineOutputItem()                  -- Output scanner fallback
                if rachine ~= nil and recit ~= nil then
                    print( "Extractor: Got item by output inventory" )
                    break
                end
            end
        end
        
        switch.isSwitchOn = false
        ignoreAllFactoryConnectorsByDirection( machines, 1 )
    end
    
    return rachine, recit
end




-- Production Cycle Data --
machineData = {}
MachineData = {}
MachineData.__index = MachineData

local INV_SHARD_SLOTS = createPowerShardSlotReference()
local INV_SHARD_UNUSED = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 }


local function MD_Collimate_Cycle( md )
    local t = formatNumber( md.progress * 100.0, 3, 0 ) .. '%'
    return t, cWhite, cBlack
end

local function MD_Collimate_Rate( md )
    local t = formatNumber( md.rate * 100.0, 3, 0 ) .. '%'
    return t, cWhite, cBlack
end

local function MD_Collimate_Output( md )
    local ot, oc = md:getInventoryStatus( INV_OUTPUT, 0 )
    local output = primary.amount * ( 60 / md.cycleTime ) * md.rate
    local t = {
        formatNumber( output, 9, 2 ), primaryUnits, ot
    }
    local c = { cWhite, cWhite, oc }
    return t, c, cBlack
end

local function MD_Collimate_Potential( md )
    local t = { formatNumber( md.potential * 100.0, 3, 0 ) .. '% ' }
    local c = { cWhite }
    
    local refItems = INV_SHARD_SLOTS
    for idx, item in pairs( refItems ) do
        local it, ic = md:getInventoryStatus( INV_SHARD, idx - 1 ) -- refItems is 1, ...; getStack() is 0, ...
        if it ~= nil and ic ~= nil then
            t[ #t + 1 ] = it
            c[ #c + 1 ] = ic
        end
    end
    
    return t, c, cBlack
end

local function MD_Collimate_Inputs( md )
    local refItems = inputItems
    if refItems == nil or #refItems == 0 then return '', cWhite, cBlack end
    
    local t = {}
    local c = {}
    
    for idx, item in pairs( refItems ) do
        local it, ic = md:getInventoryStatus( INV_INPUT, idx - 1 ) -- refItems is 1, ...; getStack() is 0, ...
        if it ~= nil and ic ~= nil then
            t[ #t + 1 ] = it
            c[ #c + 1 ] = ic
        end
    end
    
    return t, c, cBlack
end

local nextPowerStatusChar = 1
local function MD_Collimate_Power( md )
    local t = PWR_STATUS_OFF
    local c = cRed
    if md.power > 0 then
        local npsc = nextPowerStatusChar
        t = PWR_STATUS_ON[ npsc ]
        npsc = npsc + 1
        if npsc > #PWR_STATUS_ON then npsc = 1 end
        nextPowerStatusChar = npsc
        c = cGreen
    end
    return ' ' .. t, c, cBlack
end

local function createMachineDataCollimator()
    local Column = Collimator.Column
    
    local c = {}
    c[ #c + 1 ] = Column.new( { header = 'Cycle'      , width =  5, resolver = MD_Collimate_Cycle     } )
    c[ #c + 1 ] = Column.new( { header = 'Rate'       , width =  5, resolver = MD_Collimate_Rate      } )
    c[ #c + 1 ] = Column.new( { header = 'Potential'  , width =  9, resolver = MD_Collimate_Potential, sep = '' } )
    c[ #c + 1 ] = Column.new( { header = 'Output'     , width = 16, resolver = MD_Collimate_Output    } )
    if machineType == MT_Manufacturer then
        c[ #c + 1 ] = Column.new( { header = 'Inputs' , width =  6, resolver = MD_Collimate_Inputs   , sep = '' } )
    end
    c[ #c + 1 ] = Column.new( { header = 'Pwr'        , width =  3, resolver = MD_Collimate_Power     } )
    
    local result, reason = Collimator.new( {
        columns     = c,
        padding     = 1,
        drawText    = screensSetText,
    })
    if result == nil then
        computer.panic( reason )
    end
    return result
end
MachineData.Collimator = nil



function MachineData.tostring()
    return MachineData.Collimator:headersToString()
end

function initMachineData()
    local function createMachineData( machine )
        local result = {}
        result.machine = machine
        result.lastProgress = machine.progress
        setmetatable( result, MachineData )
        result:update()
        return result
    end
    
    for _, machine in pairs( machines ) do
        machineData[ machine.hash ] = createMachineData( machine )
    end
    
end

function MachineData:update()
    local machine = self.machine
    self.potential = machine.potential
    self.progress = machine.progress
    self.rate = machine.productivity
    self.cycleTime = machine.cycleTime
    self.power = machine.powerConsumProducing or 0
    if machine.standby or self.lastProgress == self.progress then
        self.power = 0
    end
    self.lastProgress = self.progress
end

function MachineData:toString()
    return MachineData.Collimator:tableToString( self )
end

function MachineData:getInventoryStatus( inventory, stack )
    if inventory == nil or type( inventory ) ~= "string" or inventory == '' then
        computer.panic( debug.traceback( "bad inventory", 2 ) )
        return nil, nil end
    if stack == nil or type( stack ) ~= "number" or stack < 0 then
        computer.panic( debug.traceback( "bad stack", 2 ) )
        return nil, nil end
    
    local refItems = nil
    if inventory == INV_INPUT then
        refItems = inputItems
    elseif inventory == INV_OUTPUT then
        refItems = outputItems
    elseif inventory == INV_SHARD then
        refItems = INV_SHARD_SLOTS
    else
        computer.panic( debug.traceback( "really bad inventory", 2 ) )
        return nil, nil
    end
    
    if refItems ~= nil and stack >= #refItems then
        computer.panic( debug.traceback( "refItems", 2 ) )
        return nil, nil end
    
    local machine = self.machine
    local inv = getInventoryByName( machine, inventory )
    if inv == nil then
        computer.panic( debug.traceback( "can't get inventory", 2 ) )
        return nil, nil end
    local stk = inv:getStack( stack )
    if stk == nil then
        computer.panic( debug.traceback( "get get stack", 2 ) )
        return nil, nil end
    
    local refItem = refItems[ 1 + stack ] -- refItems is 1, ...; getStack() is 0, ...
    local refAmount = refItem.amount
    local dblAmount = refAmount * 2
    local stkCount = stk.count
    
    if inventory == INV_INPUT then
        
        if stkCount < refAmount then
            return INV_STATUS[ 1 ], cRed
        elseif stkCount < dblAmount then
            return INV_STATUS[ 2 ], cYellow
        end
        return INV_STATUS[ 3 ], cGreen
        
    elseif inventory == INV_OUTPUT then
        
        local sMax = refItem.stackSize
        dblAmount = sMax - refAmount * 2
        if dblAmount < 0 then dblAmount = 0 end
        refAmount = sMax - refAmount
        if refAmount < 0 then refAmount = 0 end
        
        if stkCount > refAmount then
            return INV_STATUS[ 3 ], cRed
        elseif stkCount > dblAmount then
            return INV_STATUS[ 2 ], cYellow
        end
        return INV_STATUS[ 1 ], cGreen
        
    elseif inventory == INV_SHARD then
        
        local potential = self.potential
        
        local char = INV_STATUS[ 1 ] -- empty
        if stkCount > 0 then char = INV_STATUS[ 3 ] end -- full
        
        local col = INV_SHARD_UNUSED
        -- Color depends on whether it's required
        if( stack == 0 and potential > 1.0 )
        or( stack == 1 and potential > 1.5 )
        or( stack == 2 and potential > 2.0 )then
            col = cGreen
        end
        
        return char, col
    end
    
    computer.panic( debug.traceback( "wtf?", 2 ) )
    return nil, nil
end




inputCycle = {}
outputCycle = {}

function updateCycleData()
    local function resetCycleData()
        local function resetCycleData( data, items )
            for idx, item in pairs( items ) do
                
                local datum = data[ idx ]
                if datum == nil then
                    datum = { name = item.name, units = unitsForItem( item ) }
                    data[ idx ] = datum
                end
                
                datum.total  = 0
                datum.amount = 0
                
            end
        end
        resetCycleData( inputCycle, inputItems )
        resetCycleData( outputCycle, outputItems )
    end
    
    local function updateCycleData( data, items, cycleTime, rate )
        for idx, item in pairs( items ) do
            
            local datum = data[ idx ]
            if datum == nil then
                datum = {
                    name = item.name,
                    amount = 0,
                    total = 0,
                }
                data[ idx ] = datum
            end
            
            local t = item.amount * ( 60 / cycleTime )
            datum.total = datum.total + t
            datum.amount = datum.amount + t * rate
            
        end
    end
    
    resetCycleData()
    
    for _, data in pairs( machineData ) do
        data:update()
        if inputItems ~= nil and #inputItems > 0 then
            updateCycleData( inputCycle, inputItems, data.cycleTime, data.rate )
        end
        if outputItems ~= nil and #outputItems > 0 then
            updateCycleData( outputCycle, outputItems, data.cycleTime, data.rate )
        end
    end
end




-- Recipe and Main Product --
mainTitle = ''
recipe = nil
inputItems = nil
outputItems = nil
primary = nil
primaryUnits = nil


function getRecipeAndProduct()
    
    -- Find a machine with a recipe
    local machine, recit = findMachineWithRecipeOrExtractedItem()
    if machine == nil then
        if machineType == MT_Manufacturer then
            computer.panic( "No machine with a recipe set (yet)" )
        elseif machineType == MT_Extractor then
            computer.panic( "Could not prime extractor to get produced item" )
        else
            computer.panic( "What the hell are these machines?  machineType is invalid" )
        end
        return
    end
    
    if machineType == MT_Manufacturer then
        -- Get the recipe and main primary
        recipe      = machine:getRecipe()
        mainTitle  = recipe.name
        print( "Recipe: " .. mainTitle )
        
        inputItems  = getItemDatumsFromItemAmounts( recipe:getIngredients() )
        outputItems = getItemDatumsFromItemAmounts( recipe:getProducts() )
        primary     = outputItems[ 1 ]
        if primary == nil then
            computer.panic( "Unable to get products of recipe!" )
        end
    end
    
    if machineType == MT_Extractor then
        inputItems  = {}
        local prod  = createItemDatumFromItem( recit )
        outputItems = { prod }
        primary     = prod
        mainTitle  = prod.name -- So we have something in the top title bar
    end
    
    primaryUnits = unitsForItem( primary )
    
    print( "Primary: " .. primary.name )
    print( " isFluid: " .. tostring( primary.isFluid ) )
    
    -- Program all other machines with the same recipe
    if machineType == MT_Manufacturer and programAllMachines then
        for _, machine in pairs( machines ) do
            machine:setRecipe( recipe )
        end
    end
    
end




-- Storage --
storageMax = 0
storageCurrent = 0

storageData = {}
StorageData = {
    storage = nil,
    name = '',
    current = 0,
    max = 0,
}
StorageData.__index = StorageData

function StorageData:update()
    local storage = self.storage
    local current = 0
    if primary.isFluid then
        current = storage.fluidContent
    else
        local inv = getInventoryByName( storage, INV_STORAGE )
        current = inv.itemCount
    end
    self.current = current
    return current, self.max
end


function getStorage()
    if primary == nil then
        return
    end
    
    local stores = nil
    if primary.isFluid then
        stores = component.getComponentsByClass( FluidStorage.All )
    else
        stores = component.getComponentsByClass( SolidStorage.All )
    end
    
    listProxiesAs( "Storage", stores, true )
    
    storageMax = 0
    storageCurrent = 0
    
    local function createStorageData( storage )
        local result = {}
        result.storage = storage
        local name = storage.nick
        if name == nil or name == '' then
            name = storage.id
        end
        result.name = name
        local max = 0
        if primary.isFluid then
            max =  storage.maxFluidContent
        else
            local inv = getInventoryByName( storage, INV_STORAGE )
            max = inv.size * primary.stackSize
        end
        result.max = max
        setmetatable( result, StorageData )
        return result
    end
    
    for _, store in pairs( stores ) do
        storageData[ store.hash ] = createStorageData( store )
    end
    
    updateStorage()
    
    print( " Max Capacity: " .. tostring( storageMax ) )
end

function updateStorage()
    local current = 0
    local max = 0
    
    for _, sd in pairs( storageData ) do
        local c, m = sd:update()
        current = current + c
        max = max + m
    end
    
    storageCurrent = current
    storageMax = max
end




-- Valves --
valves = {}


function getValves()
    -- Find all the valves
    valves = component.getComponentsByClass( ClassGroup.FluidPumps.All )
    listProxiesAs( "Valves", valves )
end

function updateValves()
    if #valves == 0 then
        return
    end
    
    local mult = 0.0
    if onState then
        mult = 1.0
    end
    
    for _, valve in pairs( valves ) do
        local maxLimit = valve.flowLimit / valve.flowLimitPct
        valve.userFlowLimit = mult * maxLimit
    end
    
end




-- Mergers --
local listeningToMergers = false
mergers = {}


function getMergers()
    -- Find all the mergers
    mergers = component.getComponentsByClass( ClassGroup.CodeableMergers.All )
    listProxiesAs( "Mergers", mergers )
end


---Start listening to events from the mergers
function listenToMergers()
    listeningToMergers = true
    for _, merger in pairs( mergers ) do
        event.listen( merger )
    end
    tryTransferItems()
end

---Stop listening for events from the mergers
function stopListeningToMergers()
    listeningToMergers = false
    for _, merger in pairs( mergers ) do
        event.ignore( merger )
    end
end

function updateMergers()
    if #mergers == 0 then
        return
    end
    
    if onState and not listeningToMergers then
        listenToMergers()
    elseif not onState and listeningToMergers then
        stopListeningToMergers()
    end
    
    if onState then
        -- Events may not be enough to pump the queue?  Try force a transfer
        tryTransferItems()
    end
end




---Signal: ItemRequest
---@param merger userdata
---@param input integer
---@param item userdata
---@param return boolean
function handleSignalItemRequest( merger, input, item )
    if merger == nil then return false end
    if input == nil or type( input ) ~= "number" then return false end
    if item == nil or type( item ) ~= "userdata" then return false end
    
    tryTransferItem( merger, input, item )
    return true -- Transfered or not, we still consumed the event
end


---Signal: ItemOutputted
---@param merger userdata
---@param item userdata
---@param return boolean
function handleSignalItemOutputted( merger, item )
    if merger == nil then return false end
    
    tryPumpMerger( merger )
    return true -- Transfered or not, we still consumed the event
end


---Merger event dispatcher.
---@param edata table table {event.pull()}
---@return boolean true, event was handled, false otherwise
function handleMergerEvent( edata )
    if edata == nil or edata[ 1 ] == nil then return false end
    
    local signal = edata[ 1 ]
    
    if signal == "ItemRequest" then
        return handleSignalItemRequest( edata[ 2 ], edata[ 3 ], edata[ 4 ] )
    end
    
    if signal == "ItemOutputted" then
        return handleSignalItemOutputted( edata[ 2 ], edata[ 3 ] )
    end
    
    return false    -- Unknown signal
end


---Try and transfer an item in the mergers input to the output
---@param merger userdata
---@param input integer
---@param item userdata
---@return boolean Was the item transfered?
function tryTransferItem( merger, input, item )
    
    if item == nil then
        item = merger:getInput( input )
    end
    if item == nil or item.type == nil then return false end
    
    return merger:transferItem( input )
end


---Look for an input with the request item and transfer it, triggering the event queue for future transfers
---@param merger userdata
---@return boolean Was any item transfered?
function tryPumpMerger( merger )
    if merger.canOutput then
        for i = 0, 2 do
            if tryTransferItem( merger, i ) then
                return true
            end
        end
    end
    return false
end


---Pump all the mergers for this request.
---@return boolean Was any item transfered?
function tryTransferItems()
    local result = false
    for _, merger in pairs( mergers ) do
        result = result or tryPumpMerger( merger )
    end
    return result
end




-- "Admin" Panel --
local AB_ReflashAndReboot = { 0, 0 }
local adminPanels = nil
local adminUIOReflashAndReboot = nil

---Event UIO callback
local function triggerReflashAndReboot( edata )
    print( "Trigger: ResetTerminal" )
    adminUIOReflashAndReboot:setState( false )
    
    local result, reason = updateEEPROM()
    if not result then
        print( "could not update EEPROM:\n" .. reason )
        return
    end
    
    -- Reboot the computer
    computer.beep()
    computer.reset()
end


function getAdminPanels()
    adminPanels = component.getComponentsByClass( { ClassGroup.ModulePanels.MCP_1Point_C, ClassGroup.ModulePanels.MCP_1Point_Center_C } )
    listProxiesAs( "Single Module Panels", adminPanels )
    
    if adminPanels == nil or #adminPanels == 0 then
        print( "Warning: No module panels found, manual reflashing and reboots are required.")
        return
    end
    
    -- Create the combinator or panic
    adminUIOReflashAndReboot = UIO.createButtonCombinator( adminPanels, AB_ReflashAndReboot, triggerReflashAndReboot, { r = 1.0, g = 0.0, b = 0.0, a = 1.0 }, { r = 1.0, g = 0.0, b = 0.0, a = 0.0 } )
    if adminUIOReflashAndReboot == nil then
        computer.panic( debug.traceback( "Could not create EEPROM Flash and Reboot UIO Combinator" ) )
    end
    
    -- Set the state to false until we are done booting
    adminUIOReflashAndReboot:setState( false )
end



-- RSS Panels --
local rssStaticElementsSet = false
local rssElements = {}
local rssPanels = {}


function getRSSPanels()
    -- Find all the RSS Panels for "pretty formatting"
    rssPanels = component.getComponentsByClass( RSSSigns.All )
    listProxiesAs( "RSS Panels", rssPanels )
end

function setRSSTextElement( index, text, color )
    local element = rssElements[ index ] or {}
    element.text = text
    element.color = color
    rssElements[ index ] = element
end

function setRSSPanelElement( panel, index, element )
    if panel == nil or element == nil then
        return
    end
    panel:Element_SetText( element.text, index )
    panel:Element_SetColor( element.color, index )
end

function updateRSSPanels()
    if #rssPanels == 0 then return end
    
    -- Update the elements for the Panels
    updateRSSElements()
    
    for _, panel in pairs( rssPanels ) do
        for j,element in  pairs( rssElements ) do
            setRSSPanelElement( panel, j, element )
        end
    end
    
end

function updateRSSElements()
    -- No panels means no need to update the elements
    if #rssPanels == 0 then
        return
    end
    
    if not rssStaticElementsSet then
        setRSSTextElement( 0, recipe.name, cWhite )
        setRSSTextElement( 2, formatNumber( storageMax ), cWhite )
        
        if primary.isFluid then
            setRSSTextElement( 7, "Volume (m³)", cWhite )
        else
            setRSSTextElement( 7, "Inventory", cWhite )
        end
        
        rssStaticElementsSet = true
    end
    
    setRSSTextElement( 1, formatNumber( storageCurrent ), cWhite )
    setRSSTextElement( 3, formatNumber( throughput.rate, 0, 2, true ), cWhite )
    setRSSTextElement( 4, getStatusString(), cWhite )
    
end



-- Screen size calculator for Component Network config --

function getTotalDisplayLines()
    local t = 6 -- Update with fixed lines on the display (titles, headers, etc)
    local function addToT( base, able )
        local c = table.countKeyValuePairs( able )
        --print( c, t )
        if c > 0 then
            t = t + base + c
        end
    end
    addToT( 1, machines )
    addToT( 2, inputItems )
    addToT( 2, outputItems )
    addToT( 5, storageData )
    return t
end

function getRecommendedScreenSize()
    local tL = getTotalDisplayLines()
    local pW = panelsWide
    local pH = math.max( 1, math.ceil( tL / screenCRPP ) )
    local cC = pW * screenCCPP
    local cR = pH * screenCRPP
    return pW, pH, cC, cR
end




-- Runtime Variables --
thresholdLow  = -1
thresholdHigh = -1

onState = false

local statusCharIndex = 0
local statusChars = PWR_STATUS_ON   -- Using the same characters for the spiny circle
function getStatusString()
    statusCharIndex = ( statusCharIndex + 1 )
    if statusCharIndex > #statusChars then statusCharIndex = 1 end -- Would do modulus but Lua arrays aren't zero based
    if onState then
        return statusChars[ statusCharIndex ] .. 'nline'
    end
    return statusChars[ statusCharIndex ] .. 'ffline'
end



throughput = {}
throughUpdateTimeToMinute = 60000 / throughputUpdateMS  -- Scalar to get the per minute rate


function initThroughput()
    throughput = {}
    throughput.rate          = 0.0
    throughput.items         = 0
    throughput.deltaTime     = 0
    throughput.lastCount     = storageCurrent
    throughput.lastTimestamp = computer.millis()
end

function updateThroughput()
    -- Update the throughput rate as monitored on the Storage
    
    local newCount = storageCurrent
    local newTimestamp = computer.millis()
    
    local deltaCount = ( newCount     - throughput.lastCount     )
    local deltaTime  = ( newTimestamp - throughput.lastTimestamp )
    
    throughput.items     = throughput.items     + deltaCount
    throughput.deltaTime = throughput.deltaTime + deltaTime
    
    if throughput.deltaTime > throughputUpdateMS then
        throughput.rate = ( throughput.items * ( throughput.deltaTime / throughputUpdateMS ) ) * throughUpdateTimeToMinute
        throughput.items = 0
        throughput.deltaTime = 0
    end
    
    throughput.lastCount     = newCount
    throughput.lastTimestamp = newTimestamp
end


function updateState()
    if onState and storageCurrent >= thresholdHigh then
        onState = false
    elseif not onState and storageCurrent <= thresholdLow then
        onState = true
    end
end


local nextSignUpdate = -1
function updateDisplays()
    local newTimestamp = computer.millis()
    if newTimestamp < nextSignUpdate then return end
    
    nextSignUpdate = newTimestamp + signUpdateMS
    
    updateScreens()
    updateRSSPanels()
    
end



local nextCycleUpdate = -1
function handleProductionCycle()
    local newTimestamp = computer.millis()
    if newTimestamp < nextCycleUpdate then return end
    
    nextCycleUpdate = newTimestamp + cycleUpdateMS
    
    -- Update the data to work with
    updateStorage()
    updateThroughput()
    updateState()
    updateCycleData()
    
    -- Change the physical state of the system
    updateSwitch()
    updateValves()
    updateMergers()
    
end




-- Event handler --
function handleEvent( edata )
    -- The if .. or doesn't do anything other than stop trying after the first handler consumes it
    if UIO.UIOElements:eventHandler( edata )
    or handleMergerEvent( edata )
    then end
end




-- Init --
function Init()
    
    -- Sanity checks against the user being a big derpy head
    if triggerOffThreshold > 1.0 then
        computer.panic( "triggerOffThreshold > 1.0" )
    end
    if triggerOnThreshold < 0.0 then
        computer.panic( "triggerOnThreshold < 0.0" )
    end
    if triggerOnThreshold >= triggerOffThreshold then
        computer.panic( "triggerOnThreshold >= triggerOffThreshold" )
    end
    
    
    -- Get the "admin panels"
    getAdminPanels()
    
    
    -- Get the one and only power switch
    getSwitch()
    
    -- Get all the machines
    getMachines()
    
    -- Get the recipe from the machine
    getRecipeAndProduct()
    
    -- We've got the machines and the recipe, now check for compatible storage
    getStorage()
    
    -- Get any valves controlling fluid in-flow
    getValves()
    
    -- Get any codeable mergers controlling item in-flow
    getMergers()
    
    
    -- Init constant runtime variables
    thresholdLow  = storageMax * triggerOnThreshold
    thresholdHigh = storageMax * triggerOffThreshold
    
    print( "thresholdLow : " .. tostring( thresholdLow  ) )
    print( "thresholdHigh: " .. tostring( thresholdHigh ) )
    
    MachineData.Collimator = createMachineDataCollimator()
    
    -- Compute the recommended screen size
    print( string.format( "Recommended screen size:\n\tPanels: %d x %x\n\tCharacters: %d x %d", getRecommendedScreenSize() ) )
    
    -- Get GPUs to drive Screens
    getGPUs()
    
    -- Get Screens to be driven by GPUs
    getScreens()
    
    -- Find the RSS Panels for "pretty formatting"
    getRSSPanels()
    
    -- Flow rate monitoring setup
    initThroughput()
    
    -- Setup the machine data
    initMachineData()
    
    -- Reset RSS Signs
    updateRSSPanels()
    
    -- Change the state of the reboot button last as it is our final indicator the system is truly done booting up
    if adminUIOReflashAndReboot ~= nil then
        adminUIOReflashAndReboot:setState( true )
    end
end




-- Main --
function Main()
    
    -- Game loop
    while true do
        
        -- Play nice and timeslice!
        local edata = { event.pull( timesliceSeconds ) }
        
        
        -- Handle events
        handleEvent( edata )
        
        
        -- Update the control logic
        handleProductionCycle()
        
        
        -- Periodic check for software updates, does not apply them just informs the player this terminal can be updated
        versionCheck()
        
        
        -- Let the player know what's going on
        updateDisplays()
        
        
    end
    
end


Init()
Main()