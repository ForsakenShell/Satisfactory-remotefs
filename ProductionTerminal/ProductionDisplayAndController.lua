Module = { Version = { full = { 1, 6, 14, '' } } }
-- This will get updated with each new script release Major.Minor.Revision.Hotfix
-- Revision/Hotfix should be incremented every change and can be used as an "absolute version" for checking against
-- Do not move from the topline of this file as it is checked remotely
-- Also be sure to update ProductionDisplayAndController.lua.version to match

--[[ Production Display and Controller

Required boot settngs:
    remotefs="ProductionTerminal"
    bootloader="ProductionDisplayAndController.lua"

Optional control values:
    triggeronthreshold="integer"        -- Percent 0..99, default: 25; must be smaller than triggeroffthreshold
    triggeroffthreshold="integer"       -- Percent 1..100, default: 100; must be larger then triggeronthreshold
    autoupdate="boolean"                -- true or false, default: false; automatically reflash the EEPROM and reboot the computer when a new remote version is detected

This script will control a "bank" of "Machines" (Manufacturers or Extractors) power via switches (power), input valves
(fluids) and, input codeable mergers (solid items).

This monitors the inventory levels of an FGBuildableStorage or PipeReservoir (ie, Storage Container, Fluid Buffer,
etc) and sets the Switches on/off states depending on the inventory level and the programmable thresholds.

All RSS Buildable Signs (optimized for 2:1) connected to the network will have the "pretty format" display for
monitoring at a distance.
TODO:  Generate RSSBuilder.Layout from existing template

Detailed monitoring of individual machines performance and will be output all the Screen (Build_Screen_C only)
on the network.

GPUs, Screens and Signs are optional, the terminal can run headless - no signs, no screens, nothing but console
messages if so desired.


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
|       require bigger.
|       NOTE:  Each Screen requires it's own GPU in the Computer to drive it.
|       NOTE:  You do not need a screen+GPU or any RSS Signs for this script to function, you will just
|           get no feedback beyond the controlled behaviour of the switches and machines.
|       NOTE:  Only Screens require a GPU to drive it, RSS Signs do not.
|
+- "CircuitSwitch":
|   1+  Power Switch[es] (or compatible) connected for controlling power flow to the Machines.  This can control
|       one or more switches.
|
+- "Manufacturer" or "FGBuildableResourceExtractorBase" class "Machines"
|   1+  As many as you want, however they must be the same class and producing the same recipe/extracting the
|       same resource.
|       See the Reflection Viewer for class details and subclasses of said classes.
|
+- "FGBuildableStorage" and/or "PipeReservoir":
|   1+  This is the "Storage" for this controller.  This script monitors the Storage levels and turns the bank
|       of Machines on/off as needed.  The type of Storage must match the machines outputs.  Machines with multiple
|       outputs will require multiple storage arrays.  Storage must be appropriate for the output item type.
|
+- RSS Signs (optional):
|   0+  Any RSS Sign with a 2:1 display ratio will work.  Intended for billboards and large wall signs to be seen
|       at a distance containing less information but with "pretty formatting".  Displays the machine icon, primary
|       icon, recipe name, storage level (current and max), storage flow rate and, power status of the machine
|       bank.  Currently there is no way to add or remove elements from the sign so templates that can be applied
|       have been provided along-side this script for each 2:1 sign (2x1, 8x4, 16x8).  Additionally, the user (you)
|       must set the icons on the sign as at the moment there is no way to do so from Lua.  Well, there is but there
|       is no way to get the texture to set.
|       NOTE: RSS Signs do not need a GPU to operate.
|
+- "CodeableMerger" (optional):
|   0+  Only for solid inputs, will pass through recipe items when the Machines are turned on and off, respectively.
|       Recommended: Use Wiremods Constant Gate and Conveyor Limiters as valves instead of Codeable Mergers as they require
|         no active processing by the FIN computer and are handled much more efficiently by the game engine.
|
+- Wiremod "Build_Const_C" (optional):
|   1   Only for solid inputs, will pass through recipe items when the Machines are turned on and off, respectively.
|       Used as the single interface to a group of Conveyor Limiters used to gate the solid inputs.
|       Recommended: Use this method instead of CodeableMergers which require active processing.
|
+- "PipelinePump" (optional):
|   0+  Only for Fluid inputs, can open and close the valve when the Machines are turned on and off, respectively.
|
+- "Single Point Module Panel" (optional):
|   0+  Used to hold a single button to trigger the computer to download the latest version of the EEPROM and reboot.
|       Recommended: Illuminable Pushbutton Module which will be illuminated when the system boots up and dimmed
|       when [re]booting.
|
+- "Sizeable Module Panel" (optional):
|   0+  1x3 or 1x4 - Laid out as follows:
|             (0,3) (optional) A button to toggle "full" and "minimal" display modes - recommended: Illuminable Pushbutton Module
|             (0,2) A button to override system on/off - recommended: Illuminable Mushroom Button
|             (0,1) "Potentiometer with Readout" for threshold max - readout is percent of storage volume
|             (0,0) "Potentiometer with Readout" for threshold min - readout is percent of storage volume

]]--


if EEPROM == nil then
    panic( "EEPROM is out of date!\nRequired: EEPROM v1.3.8 or later")
end

-- Versioning --
Module.Version.pretty = EEPROM.Version.ToString( Module.Version.full )
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
1.4.11
 + Update for EEPROM v1.3.8
 + Control logic update for multi-output recipes:
    + Storage for all outputs must be provided
    + Screen output has been adjusted to accomodate a column for the second output
1.4.12
 + Support for multiple CircuitSwitches, all switches will be treated the same, who am I to put restrictions on your factory design?
 + System On/Off override no longer has no lock out and can properly override in all situations
 + System On/Off override will revert back to automatic mode 10 seconds after pushing the button while inside the threshold range; outside the range it will remain as selected
 + Threshold Potentiometers (with readout) have their intensity increased so they are actually visible
1.5.13
 + Fixes fluid throughputs reading 1/1000th their values
 + System will now turn on if it detect an output rate from storage that exceeds the production output, even if it has not reached the low-end threshold
 + Removed some old code not used
1.6.14
 + New optional button in the user panel to toggle "full" and "minimal" display modes; if this button is present then the display will remain in "full" mode after
 | booting and after the button is pressed for 60 seconds and then go into "minimal" mode; this is to save CPU time as rendering the full display can take a long time
 + Modified timeslicing logic
 + Removed some redundant code
 + Fixes machine standby states
]]



if EEPROM.Boot.Disk ~= nil and EEPROM.Boot.Disk ~= '' then
    -- A disk in the Production Terminal computer means the player is doing some
    -- maintainence on the network and will want a full log of events.
    require( "/lib/ConsoleToFile.lua", EEPROM.Remote.CommonLib )
end





-- requires --
local utf8                      = require( "/lib/utf8.lua", EEPROM.Remote.CommonLib )

local ClassGroup                = require( "/lib/classgroups.lua", EEPROM.Remote.CommonLib )
local GPUs                      = ClassGroup.Displays.GPUs
local Screens                   = ClassGroup.Displays.Screens
local SolidStorage              = ClassGroup.Storage.Solids
local FluidStorage              = ClassGroup.Storage.Fluids
local RSSSigns                  = ClassGroup.Displays.Signs.ReallySimpleSigns

local Color                     = require( "/lib/Colors.lua", EEPROM.Remote.CommonLib )

local UIO                       = require( "/lib/UIOElements.lua" )

local ItemDatum                 = require( "/lib/ItemDatum.lua", EEPROM.Remote.CommonLib )
local MachineDatum              = require( "/lib/MachineDatum.lua", EEPROM.Remote.CommonLib )
local StorageArray              = require( "/lib/StorageArray.lua", EEPROM.Remote.CommonLib )

local RSSBuilder                = nil -- We will require this as needed
--RSSBuilder = require( "/lib/RSSBuilder.lua", EEPROM.Remote.CommonLib )



-- Operational Controls --

local programAllMachines = true         -- Program all the machines with the first recipe found (so you can be lazy and only set one machine)

local cycleUpdateMS = 1000              -- Update the signs every X ms, default is 1000 (1.0 seconds); regardless of events, this is how often the control logic is updated
local signUpdateMIN = 250               -- Minimum screen update interval
local signUpdateMAX = 2500              -- Maximum screen update interval
local signUpdateMS = signUpdateMIN      -- Update the signs every X ms, this is the initial update value, it will be auto-adjusted to be faster/slower depending on how long it takes to draw the screens
local cpuSaverTimeout = 60000           -- Switch to "minimal" dispay mode after this amount of time (in ms)
local RESET_OVERRIDE_MS = 10000         -- Keep the current override state and clear the override status after this many milliseconds
local softwareUpdateMS = 10 * 60 * 1000 -- Only check for software updates once every 10 minutes, we don't need to hammer this and if we're smart then we have .version files on the remote so we only need to transmit a few bytes an hour instead of several hundreds of kilobytes
local timesliceSeconds = math.min( cycleUpdateMS, signUpdateMIN, cpuSaverTimeout, RESET_OVERRIDE_MS, softwareUpdateMS ) / 1000 -- Play nice and timeslice!  Use the smallest required update interval

triggerOnThreshold  = tonumber( EEPROM.Boot.ComputerSettings[ "triggeronthreshold"  ] or  25 ) / 100.0  -- 0.00 to 1.00 as a percent
triggerOffThreshold = tonumber( EEPROM.Boot.ComputerSettings[ "triggeroffthreshold" ] or 100 ) / 100.0  -- 0.00 to 1.00 as a percent
autoupdate          = toboolean( EEPROM.Boot.ComputerSettings[ "autoupdate" ] ) or false


-- Control Constants - Don't mess with these --
local panelsWide = 2                    -- Consant because magic numbers are bad, never change as things ARE coded for this width
local screenCCPP = 30                   -- Screen Width in Character Columns Per Panel
local screenCRPP = 15                   -- Screen Height in Character Rows Per Panel
local screenWidth = panelsWide * screenCCPP


-- String constants --
local prodOverallTitle = "Overall"
local storOverallTitle = "Storage"



local INV_STATUS     = { "○", "◒", "●" } -- { "\u{25CB}", "\u{25D2}", "\u{25CF}" } -- empty circle, half full circle, full circle
local ACT_STATUS_OFF = "☼" -- "\u{263C}" -- Sun With Rays
local ACT_STATUS_ON = { "", "", "", "", "", "" } -- { "\u{EE06}", "\u{EE07}", "\u{EE08}", "\u{EE09}", "\u{EE0A}", "\u{EE0B}" } -- Spiny circle


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


function rebootTerminal()
    adminUIOReflashAndReboot:setState( false )
    drawBootScreens( ____RebootMessage, ____RebootMessageLen )
    
    updateSwitches( false, SYS_STATE_OVER_OFF )
    
    local result, reason = EEPROM.Remote.Update()
    if not result then
        print( "could not update EEPROM:\n" .. reason )
        return
    end
    
    -- Reboot the computer
    computer.beep()
    computer.reset()
end


function versionCompare( name, a, b )
    local result = cWhite
    local vc = a
    local vr, reason = b()
    if vr == nil then
        print( "Could not get remote " .. name .. " version:\n" .. reason )
        result = cGrey
    else
        local comp = EEPROM.Version.Compare( vc, vr )
        if comp < 0 then
            print( "New " .. name .. " version available: " .. EEPROM.Version.ToString( vr ) )
            result = cYellow
            if autoupdate then
                print( "Automatically rebooting on version update" )
            end
        else--if result >= 0 then
            result =  cGreen
        end
    end
    return result
end

nextVersionCheck = -1
function versionCheck()
    local newTimestamp = computer.millis()
    if nextVersionCheck > newTimestamp + softwareUpdateMS then nextVersionCheck = -1 end
    if newTimestamp < nextVersionCheck then return end
    
    nextVersionCheck = newTimestamp + softwareUpdateMS
    
    vcEEPROM   = versionCompare( "EEPROM"    , EEPROM.Version.full, EEPROM.Version.GetRemoteEEPROM )
    vcTerminal = versionCompare( "bootloader", Module.Version.full, EEPROM.Version.GetRemoteBootLoader )
    
end



-- Utility Functions --


function formatNumber( n, leader, decimals, prefixPositive )
    -- This function may not be very fast, need to revisit it
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


function listProxiesAs( label, proxies, panicIfNone, panicIfDifferentTypes )
    if proxies == nil or #proxies == 0 then
        if panicIfNone ~= nil and panicIfNone then
            panic( "No " .. label .. " detected!" )
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
            panic( message )
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
            panic( "No " .. label .. " detected!" )
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
            panic( message )
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
local canDraw = false
local cpuSaverMode = false
local cpuSaverOffTime = -1


local ____BootMessage = "Booting Production Terminal"
local ____BootMessageLen = utf8.len( ____BootMessage )
function drawBootScreen( gpu, msg, msgLen, extra, extraLen )
    if not canDraw then return end
    if msgLen == nil then msgLen = utf8.len( msg ) end
    
    local screenWidth, screenHeight = gpu:getSize()
    
    gpu:setBackground( 0.0, 0.0, 0.0, 1.0 )
    gpu:setForeground( 0.0, 0.0, 0.0, 1.0 )
    gpu:fill( 0, 0, screenWidth, screenHeight, 'X' )
    
    local x = round( ( screenWidth - msgLen ) * 0.5 )
    local y = screenHeight >> 1
    if extra ~= nil then y = y - 1 end
    gpu:setForeground( 1.0, 1.0, 1.0, 1.0 )
    gpu:setText( x, y, msg )
    
    if extra ~= nil then
        y = y + 2
        local l = extraLen
        if l == nil then l = utf8.len( extra ) end
        x = round( ( screenWidth - l ) * 0.5 )
        gpu:setText( x, y, extra )
    end
    
    gpu:flush()
    
    firstDraw = true
end
function drawBootScreens( msg, msgLen, extra, extraLen )
    if not canDraw then return end
    if msgLen == nil then msgLen = utf8.len( msg ) end
    for i = 1, #gpus do
        local gpu = gpus[ i ]
        drawBootScreen( gpu, msg, msgLen, extra, extraLen )
    end
end

function getScreens()
    -- Find all the Screens
    screens = component.getComponentsByClass( Screens.Build_Screen_C )
    listProxiesAs( "Screens", screens )
    
    -- Final test, all Screens require a GPU, make sure we have GPUs to match!
    canDraw = #gpus == #screens
    if not canDraw then
        panic( "Screens and GPUs mismatch!  There must be one GPU per screen and one Screen per GPU!  I mean, c'mon man?" )
    end
    
    -- Now bind the Screens to the GPUs, which doesn't matter, they will all be fed the same data
    if #gpus > 0 then
        for i = 1, #gpus do
            local gpu = gpus[ i ]
            local screen = screens[ i ]
            local pX, pY = screen:getSize()
            gpu:bindScreen( screen )
            gpu:setSize( pX * screenCCPP, pY * screenCRPP )
            
            -- Make sure the player isn't left wondering
            drawBootScreen( gpu, ____BootMessage, ____BootMessageLen, Module.Version.pretty )
        end
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


local stringLenCache = {}
local function slC( i, s )
    local v = stringLenCache[ i ]
    if v ~= nil then return v end
    v = utf8.len( s )
    stringLenCache[ i ] = v
    return v
end

local stringTrimCache = {}
local function stC( i, s, l )
    local v = stringTrimCache[ i ]
    if v ~= nil then return v end
    v = utf8.sub( s, 1, l )
    stringTrimCache[ i ] = v
    return v
end

local usTPretty = Module.Version.pretty
local usTPrettyX = screenWidth - ( utf8.len( usTPretty ) + 1 )
local prodOverallTitleX = round( ( screenWidth - ( utf8.len( prodOverallTitle ) + 1 ) ) / 2 )
local storOverallTitleX = round( ( screenWidth - ( utf8.len( storOverallTitle ) + 1 ) ) / 2 )
function updateScreens( fulldraw )
    if #gpus == 0 then return end
    local start = computer.millis()
    
    fulldraw = fulldraw or false
    local x = 0
    local y = 0
    
    -- Erase everything
    if fulldraw then
        screensClear( false )
    end
    
    
    -- Draw Top Bar Title
    if fulldraw then
        screensFill( 0, 0, screenWidth, 1, ' ', cWhite, cTitle )
        screensSetText( mainTitleX, 0, mainTitle )
        screensSetText( 1, 0, getStatusString() )
        screensSetText( usTPrettyX, 0, usTPretty, vcTerminal )
    else
        screensSetText( 1, 0, getStatusString(), cWhite, cTitle )
        screensSetText( usTPrettyX, 0, usTPretty, vcTerminal )
    end
    y = y + 1
    
    if cpuSaverMode then
        
        -- Go through each Storage Array and draw it's total and throughput
        for _, sa in pairs( storageArrays ) do
            
            y = y + 1
            screensSetText( 0, y, sa.name, cWhite, cBlack )
            y = y + 1
            drawStorageLine( y, "Total:", sa.current, sa.max, fulldraw, screenWidth )
            y = y + 1
            drawStorageLine( y, "Thresholds:", sa.thresholdLow, sa.thresholdHigh, fulldraw or thresholdChanged, screenWidth, sa.max )
            y = y + 1
            drawThroughput( y, sa.rate, sa.units, sa.unitsLen, 21, 5, 2 )
            
            y = y + 1
        end
        
    else
        
        -- Data to record for overall machine data
        local totalProd = 0
        local totalPower = 0
        
        -- Go through and draw each MachineDatum
        
        if fulldraw then
            machineCollimator:drawHeaders( 0, y )
        end
        y = y + 1
        
        for _, data in pairs( machineDatums ) do
            --computer.skip()
            machineCollimator:drawTable( 0, y, data )
            totalProd  = totalProd  + data.productivity
            totalPower = totalPower + data.currentPowerConsumption
            y = y + 1
        end
        computer.skip()
        
        -- Draw Overall Production Title
        y = y + 1
        if fulldraw then
            screensFill( 0, y, screenWidth, 1, ' ', cWhite, cTitle )
            screensSetText( prodOverallTitleX, y, prodOverallTitle )
        else
            screensSetForeground( cWhite )
        end
        y = y + 1
        
        
        -- Show how quickly all the machines are eating the inputs
        y = drawCycleData( y, "Input:", inputCycles, fulldraw )
        
        -- Show how slowly all the machines are creating the outputs
        y = drawCycleData( y, "Output:", outputCycles, fulldraw )
        
        
        -- Show the average production productivity
        totalProd = totalProd / #machineDatums
        screensSetText( 0, y, string.format( "Productivity: %5.1f%%", totalProd * 100.0 ) )
        y = y + 1
        
        -- Show the overall power consumption
        screensSetText( 0, y, string.format( "Power: %12.1f MW", totalPower ) )
        
        
        -- Draw Storage Title
        y = y + 2
        if fulldraw then
            screensFill( 0, y, screenWidth, 1, ' ', cWhite, cTitle )
            screensSetText( storOverallTitleX, y, storOverallTitle )
        end
        
        -- Go through each Storage Array and draw it's details
        for _, sa in pairs( storageArrays ) do
            
            y = y + 1
            screensSetText( 0, y, sa.name, cWhite, cBlack )
            
            -- Go through each Storage container in the array, draw it's current, max as well as a neat little bar graph
            for idx = 1, sa.count do
                computer.skip()
                y = y + 1
                local name, current, max = sa:storeUsefulData( idx )
                drawStorageLine( y, name, current, max, fulldraw, screenWidth )
            end
            
            -- Draw a storage line for the total storage
            y = y + 2
            drawStorageLine( y, "Total:", sa.current, sa.max, fulldraw, screenWidth )
            y = y + 1
            drawStorageLine( y, "Thresholds:", sa.thresholdLow, sa.thresholdHigh, fulldraw or thresholdChanged, screenWidth, sa.max )
            y = y + 1
            drawThroughput( y, sa.rate, sa.units, sa.unitsLen, 21, 5, 2 )
            
            y = y + 1
        end
        
    end
    
    -- Very bottom row of each screen, draw the the EEPROM version and total draw time
    local finish = computer.millis()
    local delta = finish - start
    drawScreenFooter( string.format( "%12d | %5d ms | %5d ms", finish, signUpdateMS, delta ), fulldraw )
    -- If it takes a long time to draw the screen, spread out how often we do it,
    -- also speed it back up if it starts taking less time
    if delta > ( signUpdateMS * 0.25 ) then signUpdateMS = round( signUpdateMS * 1.25 )
    elseif delta < ( signUpdateMS * 0.10 ) then signUpdateMS = round( signUpdateMS * 0.9 ) end
    if signUpdateMS < signUpdateMIN then signUpdateMS = signUpdateMIN end
    if signUpdateMS > signUpdateMAX and signUpdateMS > delta then signUpdateMS = signUpdateMAX end
    
    -- Commit all GPU buffers to their Screens
    screensCommit()
    
    thresholdChanged = false -- No longer dirty
end

local devPretty = "EEPROM " .. EEPROM.Version.pretty
local devPrettyL = slC( 10, devPretty ) + 1
function drawScreenFooter( drawtime, fulldraw )
    
    for _, gpu in pairs( gpus ) do
        local screenWidth, screenHeight = gpu:getSize()
        local y = screenHeight - 1
        local x = screenWidth - devPrettyL
        
        gpu:setBackground( cTitle.r, cTitle.g, cTitle.b, cTitle.a )
        if fulldraw then
            gpu:fill( 0, y, screenWidth, 1, ' ' )
        end
        
        if drawtime ~= nil then
            gpu:setForeground( cWhite.r, cWhite.g, cWhite.b, cWhite.a )
            gpu:setText( 1, y, drawtime )
        end
        
        gpu:setForeground( vcEEPROM.r, vcEEPROM.g, vcEEPROM.b, vcEEPROM.a )
        gpu:setText( x, y, devPretty )
    end
    
    --print( drawtime )
end

function drawCycleData( y, label, cycleDatums, fulldraw )
    if cycleDatums == nil or #cycleDatums == 0 then return y end
    if fulldraw then
        screensSetText( 0, y, label, nil, cBlack )
    end
    local x = screenWidth - 25
    y = y + 1
    for _, cycleDatum in pairs( cycleDatums ) do
        
        local t = string.format( '+ %s', cycleDatum.name )
        screensSetText( 1, y, t )
        
        local t = string.format( '%9.2f/%9.2f %s/m', cycleDatum.amount, cycleDatum.total, cycleDatum.units )
        screensSetText( x, y, t )
        y = y + 1
    end
    return y + 1
end

-- Fira Code Font is fun
local barChars          = { "\u{258F}", "\u{258E}", "\u{258D}", "\u{258C}", "\u{258B}", "\u{258A}", "\u{2589}", "\u{2588}" }
local barFillChar       = "\u{2588}"

function getFillBar( value, max, maxChars )
    local v = math.max( 0.0, math.min( value, max ) ) -- limit value to 0..max to prevent oddities
    local p = ( v / max ) * maxChars
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

function drawStorageLine( y, name, current, max, fulldraw, ... )
    local varargs = { ... }
    local nmax = math.floor( screenWidth * 0.5 ) - 13
    local lname = slC( 200 + y, name )
    if lname > nmax then
        --name = utf8.sub( name, 1, nmax )
        name = stC( 200 + y, name, nmax )
    else
        name = name .. string.rep( ' ', nmax - lname )
    end
    
    if fulldraw then
        for _, gpu in pairs( gpus ) do
            local wid, hei = gpu:getSize()
            local t = string.rep( ' ', wid )
            gpu:setForeground( 0.0, 0.0, 0.0, 1.0 )
            gpu:setBackground( 0.0, 0.0, 0.0, 1.0 )
            gpu:setText( 0, y, t )
        end
    end
    
    -- Draw the status
    local t = string.format( "%s %5.0f/%5.0f", name, current, max )
    screensSetText( 1, y, t, cWhite, cBlack )
    
    -- Common fill bar stuff
    local barX = math.floor( screenWidth * 0.5 ) + 1
    
    if #varargs == 1 and type( varargs[ 1 ] ) == "number" then
        -- Draw the fill bar
        local screenWidth = varargs[ 1 ]
        local full = screenWidth - ( barX + 1 )
        
        local t = getFillBar( current, max, full )
        screensSetText( barX, y, t, cGreen, cRed )
    end
    
    if #varargs == 2 and type( varargs[ 1 ] ) == "number" and type( varargs[ 2 ] ) == "number" then
        -- Draw the threshold markers
        local screenWidth = varargs[ 1 ]
        local sMax = varargs[ 2 ]
        
        local full = screenWidth - ( barX + 2 )
        local low = current / sMax
        local colL = barX + round( full * low )
        screensSetText( colL, y, '^', cRed )
        
        local high = max / sMax
        local colH = barX + round( full * high )
        screensSetText( colH, y, '^', cGreen )
    end
end

local dtpNetFlow = "Net Flow:"
local dtpNewFlowLen = slC( 75, dtpNetFlow )
function drawThroughput( y, rate, units, unitsLen, colX, colL, colD )
    local colW = 1 + colX + colL + colD
    local t = string.format( "%s%s %s/m", dtpNetFlow, string.rep( ' ', colW - dtpNewFlowLen ), units )
    screensSetText( 1, y, t, cWhite )
    
    t = formatNumber( rate, colL, colD, true )
    local c = cWhite
    if rate < 0.0 then
        c = cRed
    elseif rate > 0.0 then
        c = cGreen
    end
    screensSetText( 1 + colW - #t, y, t, c )
end




-- Terminal panic --

function panic( msg, len, extra, extraLen )
    
    if canDraw then
        drawBootScreens( "TERMINAL PANIC", 14, msg, len )
    end
    
    local t = msg
    if extra ~= nil then t = t .. '\n' .. extra end
    
    computer.panic( debug.traceback( t, 2 ) )
    
end




-- CircuitSwitch --
switches = nil


function getSwitches()
    -- Find the power switches
    switches = component.getComponentsByClass( ClassGroup.CircuitSwitches.All )
    listProxiesAs( "Switches", switches, true )
end

function setSwitchState( state )
    if switches ~= nil then
        -- Only flip the switches if there are switches to flip
        for _, switch in pairs( switches ) do
            switch.isSwitchOn = state
        end
    end
end

function updateSwitches( state, uioState )
    setSwitchState( state )
    if userUIOSystemOnOff ~= nil then
        if uioState == nil then
            -- Set the on/off button state color based on override/automatic mode states
            if state then
                if overrideState ~= nil then
                    state = SYS_STATE_OVER_ON
                else
                    state = SYS_STATE_AUTO_ON
                end
            else
                if overrideState ~= nil then
                    state = SYS_STATE_OVER_OFF
                else
                    state = SYS_STATE_AUTO_OFF
                end
            end
            userUIOSystemOnOff:setState( state )
        else
            -- Set the on/off button state color based on explicit state
            userUIOSystemOnOff:setState( uioState )
        end
    end
    -- Set the standby state of each machine, this will preserve the long-term
    -- productivity on the machine making feedback more accurate
    setMachineStandby( not state )
end




-- Machines --
machineCollimator = nil
machineType = MachineDatum.MT_INVALID
machineDatums = {}


function getMachines()
    -- Find all the machines
    local machines = component.getComponentsByClass( { ClassGroup.ProductionMachines.Manufacturer, ClassGroup.ProductionMachines.FGBuildableResourceExtractorBase } )
    listProxiesAs( "Machines", machines, true, true )
    
    for idx, machine in pairs( machines ) do
        machineDatums[ idx ] = MachineDatum.new( machine )
    end
    
    -- They will all be the same, get the type from the first one
    machineType = machineDatums[ 1 ].mt
end


function listenToAllMachineDatumFactoryConnectorsByDirection( direction, onlyConnected )
    if onlyConnected == nil or type( onlyConnected ) ~= "boolean" then onlyConnected = true end
    local count = 0
    for _, md in pairs( machineDatums ) do
        
        local actor = md.machine
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

function ignoreAllMachineDatumFactoryConnectorsByDirection( direction, onlyConnected )
    if onlyConnected == nil or type( onlyConnected ) ~= "boolean" then onlyConnected = false end
    local count = 0
    for _, md in pairs( machineDatums ) do
        
        local actor = md.machine
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
    for _, datum in pairs( machineDatums ) do
        local machine = datum.machine
        local inv = component.getInventoryByName( machine, component.INV_OUTPUT )
        
        local stack = inv:getStack( 0 )             -- Get the output
        if stack.item ~= nil and stack.item.type ~= nil then
            return machine, stack.item
        end
    end
    return nil, nil
end

function findMachineWithRecipeOrExtractedItem()
    if #machineDatums == 0 then
        return nil
    end
    
    local rachine = nil
    local recit = nil
    
    if machineType == MachineDatum.MT_MANUFACTURER then
        print( "Machine Type: Manufacturer")
        
        for _, md in pairs( machineDatums ) do
            local machine = md.machine
            local recipe = machine:getRecipe()
            if recipe ~= nil then
                print( "Manufacturer: Got recipe by machine" )
                return machine, recipe
            end
        end
        
        panic( "No machine with a recipe set (yet)" )
        
    elseif machineType == MachineDatum.MT_EXTRACTOR then
        print( "Machine Type: Extractor")
        
        -- Need something to be output by the extractor to it's output
        -- inventory or connector to determine what it extracts
        print( "\nPriming extractors to determine extracted resource.\nPlease wait up to 30 seconds before resetting or turning off the computer as it may take time for the extractors to start up.\n" )
        
        -- See if any machine has an item in an output inventory
        rachine, recit = getMachineOutputItem()
        if rachine ~= nil and recit ~= nil then
            print( "Extractor: Got item by initial output scan" )
        else
            -- Listen to (connected) output connectors (if any) as the item may be removed from the inventory before this script catches it
            if listenToAllMachineDatumFactoryConnectorsByDirection( 1 ) > 0 then-- Output connector
                
                event.clear()
                updateSwitches( true )
                
                print( "10s wait for primary output event..." )
                local edata = { event.pull( 10.0 ) }            -- Wait for an event, but timeout after 10s
                
                rachine, recit = handleItemTransfer( edata )
                if rachine ~= nil and recit ~= nil then
                    print( "Extractor: Got item by primary event" )
                end
            end
        end
        
        if rachine == nil or recit == nil then
            -- Poop, no event (yet) or no connected connectors, turn machines on and hammer the scanner
            print( "20s wait for secondary output event..." )
            updateSwitches( true )                               -- Pump it!
            local timeout = computer.millis() + 20000                   -- 20s timeout on hardcore scanner
            while computer.millis() < timeout do
                
                local edata = { event.pull( 0 ) }              -- GO HARD!
                
                rachine, recit = handleItemTransfer( edata )     -- Try an catch an event first
                if rachine ~= nil and recit ~= nil then
                    print( "Extractor: Got item by secondary event" )
                    break
                end
                
                rachine, recit = getMachineOutputItem()                 -- Output scanner fallback
                if rachine ~= nil and recit ~= nil then
                    print( "Extractor: Got item by output inventory" )
                    break
                end
            end
        end
        
        updateSwitches( false )
        ignoreAllMachineDatumFactoryConnectorsByDirection( 1 )
        
        if rachine == nil then
            panic( "Could not prime extractor to get produced item" )
        end
        
    else
        panic( "Machine is wrong type" )
        
    end
    
    return rachine, recit
end

function setMachineStandby( standby )
    for _, datum in pairs( machineDatums ) do
        datum.machine.standby = standby
    end
end




-- Production Cycle Data --
inputCycles = {}
outputCycles = {}

function findCycleDatumFromItemType( cycles, datums, item )
    if cycles == nil or type( cycles ) ~= "table" then return nil end
    if datums == nil or type( datums ) ~= "table" or #datums == 0 then return nil end
    if #cycles == 0 or #cycles ~= #datums then return nil end
    if item == nil or tostring( item ) ~= "ItemType-Class" then return false end
    for idx, datum in pairs( datums ) do
        if ItemDatum.isItemDatum( datum ) then
            if datum.item == item then return cycles[ idx ] end
        end
    end
    return nil
end

function updateCycleData()
    local function resetCycleDatums()
        local function resetCycleDatum( itemCycles, itemDatums )
            if itemDatums == nil then return end
            for idx, itemDatum in pairs( itemDatums ) do
                
                local cycleDatum = itemCycles[ idx ]
                if cycleDatum == nil then
                    cycleDatum = {
                        name = itemDatum.name,
                        nameLen = itemDatum.nameLen,
                        units = itemDatum.units,
                        unitsLen = itemDatum.unitsLen
                    }
                    itemCycles[ idx ] = cycleDatum
                end
                
                cycleDatum.total  = 0
                cycleDatum.amount = 0
                
            end
        end
        resetCycleDatum( inputCycles, inputItems )
        resetCycleDatum( outputCycles, outputItems )
    end
    
    local function updateCycleDatums( machineDatum, itemCycles, itemDatums )
        local cycleTime = machineDatum.cycleTime
        local productivity = machineDatum.productivity
        
        for idx, item in pairs( itemDatums ) do
            
            local cycleDatum = itemCycles[ idx ]
            local total = item.amount * ( 60 / cycleTime )
            cycleDatum.total = cycleDatum.total  + total
            cycleDatum.amount = cycleDatum.amount + total * productivity
            
        end
    end
    
    resetCycleDatums()
    
    for _, machineDatum in pairs( machineDatums ) do
        machineDatum:update( baseProductionTime )   -- Feed the base production time as machines down don't update their cycleTime until they have power - this forces a computed value for the MachineDatum from their set potential
        if inputItems ~= nil and #inputItems > 0 then
            updateCycleDatums( machineDatum, inputCycles, inputItems )
        end
        if outputItems ~= nil and #outputItems > 0 then
            updateCycleDatums( machineDatum, outputCycles, outputItems )
        end
    end
end




-- Recipe and Main Product --
mainTitle = ''
mainTitleX = nil
recipe = nil
baseProductionTime = nil
inputItems = nil
outputItems = nil


function getRecipeAndProduct()
    
    -- Find a machine with a recipe
    local machine, recit = findMachineWithRecipeOrExtractedItem()
    
    if machineType == MachineDatum.MT_MANUFACTURER then
        -- Get the recipe and main primary
        recipe      = machine:getRecipe()
        baseProductionTime  = recipe.duration
        mainTitle   = recipe.name
        print( "Recipe: " .. mainTitle )
        
        inputItems  = ItemDatum.FromItemAmounts( recipe:getIngredients() )
        outputItems = ItemDatum.FromItemAmounts( recipe:getProducts() )
        
        -- Program all other machines with the same recipe
        if programAllMachines then
            for _, md in pairs( machineDatums ) do
                md.machine:setRecipe( recipe )
            end
        end
        
    elseif machineType == MachineDatum.MT_EXTRACTOR then
        inputItems  = nil
        local prod, reason  = ItemDatum.new( recit, 1 )
        if prod == nil then panic( reason ) end
        
        outputItems = { prod }
        mainTitle   = prod.name -- So we have something in the top title bar
        baseProductionTime  = machine.cycleTime * machine.potential
        
    end
    
    mainTitleX = round( ( screenWidth - utf8.len( mainTitle ) ) / 2 )
    
end




-- Storage --
storageArrays = nil
automaticState = nil
overrideState = nil
overrideStateCount = nil
overrideStateNilOnTick = nil

function getStorage()
    if outputItems == nil then
        return
    end
    
    storageArrays = {}
    
    for idx, item in pairs( outputItems ) do
        
        local sl = nil
        local sc = nil
        
        if item.isFluid then
            sc = StorageArray.ST_FLUID
            sl = "Fluid Storage"
        else
            sc = StorageArray.ST_SOLID
            sl = "Solid Storage"
        end
        
        -- Get all the storage proxies of the appropriate class for the output item
        local stores = component.proxy( component.findComponent( sc ) )
        listProxiesAs( sl, stores, idx == 1 )  -- Only panic on the first (primary) item storage being missing, secondaries may not be monitored as they may be waste product going to a centralized mass-storage
        
        if stores ~= nil and #stores > 0 then
            
            local sa, reason = StorageArray.new( item, stores )
            if sa == nil then panic( reason ) end
            
            -- Init constant runtime variables
            sa.thresholdLow  = sa.max * triggerOnThreshold
            sa.thresholdHigh = sa.max * triggerOffThreshold
            
            storageArrays[ idx ] = sa
            print( " Storage Item  : " .. sa.name)
            print( " Max Capacity  : " .. tostring( sa.max ) )
            print( " Threshold Low : " .. tostring( sa.thresholdLow ) )
            print( " Threshold High: " .. tostring( sa.thresholdHigh ) )
            
        end
    end
    
end

function setStorageThresholdHigh( p )
    for _, sa in pairs( storageArrays ) do
        sa.thresholdHigh = sa.max * p
    end
end

function setStorageThresholdLow( p )
    for _, sa in pairs( storageArrays ) do
        sa.thresholdLow = sa.max * p
    end
end

function updateStorage()
    local newState = nil
    local current
    for _, sa in pairs( storageArrays ) do
        sa:update()
        current = sa.current
        -- Check state based on threshold levels
        if current <  sa.thresholdLow  then newState = true end
        if current >= sa.thresholdHigh then newState = false end
        -- Check state based on throughput; if consuming faster than can be produced, turn on regardless of thresholds
        local rate = -sa.rate
        if rate > 0.0 then
            local item = sa.item.item
            local datum = findCycleDatumFromItemType( outputCycles, outputItems, item )
            if rate >= datum.total then newState = true end
        end
        -- If the storage array is full, then turn it off no matter what
        if current >= sa.max then newState = false end
    end
    automaticState = newState
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




-- Wiremod: Constant Gate --
local WM_CONSTANTGATE_ENABLE = "Enable"
wmConstantGate = nil


function getConstantGate()
    -- Find all the Constant Gates
    local gates = component.getComponentsByClass( ClassGroup.Wiremod.Gates.Build_Const_C )
    listProxiesAs( "Wiremod Constant Gates", gates )
    if gates == nil or #gates == 0 then return end
    if #gates ~= 1 then
        panic( "There should be only one Wiremod: Constant Gate" )
    end
    wmConstantGate = gates[ 1 ]
end

function updateConstantGate()
    if wmConstantGate == nil then
        return
    end
    
    function setWMConstBool( wmobject, name, value )
        while wmobject:getWireBool( name ) ~= value do
            wmobject:setConstBoolValue( name, value )
        end
    end
    
    function getWMConstBool( wmobject, name )
        return wmobject:getWireBool( name )
    end
    
    setWMConstBool( wmConstantGate, WM_CONSTANTGATE_ENABLE, onState )
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
local AP_ReflashAndReboot = { 0, 0 }
local adminPanels = nil
adminUIOReflashAndReboot = nil
____RebootMessage = "Reflash and Reboot"
____RebootMessageLen = utf8.len( ____RebootMessage )

---Event UIO callback
local function triggerReflashAndReboot( edata )
    --print( "Trigger: ResetTerminal" )
    rebootTerminal()
end


function getAdminPanels()
    adminPanels = component.getComponentsByClass( { ClassGroup.ModulePanels.MCP_1Point_C, ClassGroup.ModulePanels.MCP_1Point_Center_C } )
    listProxiesAs( "Single Module Panels", adminPanels )
    
    if adminPanels == nil or #adminPanels == 0 then
        print( "Warning: No single module panels found, manual reflashing and reboots are required.")
        return
    end
    
    -- Create the combinator or panic
    local ctrue  = Color.new( 1.0, 0.0, 0.0, 1.0 )
    local cfalse = Color.new( 1.0, 0.0, 0.0, 0.0 )
    adminUIOReflashAndReboot = UIO.createBoolButtonCombinator( adminPanels, AP_ReflashAndReboot, triggerReflashAndReboot, ctrue, cfalse )
    if adminUIOReflashAndReboot == nil then
        panic( "Could not create EEPROM Flash and Reboot Button Combinator" )
    end
    
    -- Set the state to false until we are done booting
    adminUIOReflashAndReboot:setState( false )
end




-- "User" Panel --
SYS_STATE_AUTO_OFF = 1
SYS_STATE_AUTO_ON  = 2
SYS_STATE_OVER_OFF = 3
SYS_STATE_OVER_ON  = 4
local UP_btnDisplayMode = { 0, 3 }
local UP_btnSystemOnOff = { 0, 2 }
local UP_potMax   = { 0, 1 }
local UP_potMin   = { 0, 0 }
local userPanels = nil
userUIODisplayMode = nil
userUIOSystemOnOff = nil
local userUIOThresholdMax = nil
local userUIOThresholdMin = nil

--triggerOnThreshold  = tonumber( EEPROM.Boot.ComputerSettings[ "triggerOnThreshold"  ] ) or 0.25 -- 0.00 to 1.00 as a percent
--triggerOffThreshold = tonumber( EEPROM.Boot.ComputerSettings[ "triggerOffThreshold" ] ) or 1.00 -- 0.00 to 1.00 as a percent

---Event UIO callbacks
local function triggerDisplayMode( edata )
    --print( "Trigger: Display Mode" )
    cpuSaverMode = not cpuSaverMode
    firstDraw = true
    if not cpuSaverMode then
        cpuSaverOffTime = computer.millis() + cpuSaverTimeout
    end
    userUIODisplayMode:setState( not cpuSaverMode )
end
local function triggerSystemOnOff( edata )
    --print( "Trigger: System On/Off" )
    if overrideState == nil then            -- No override, opposite current state
        overrideState = not onState
        overrideStateCount = 1
        overrideStateNilOnTick = computer.millis() + RESET_OVERRIDE_MS
    else                                    -- Override on
        overrideStateCount = overrideStateCount + 1
        if overrideStateCount > 2 then      -- Cycled through override states, disable override
            overrideState = nil
            overrideStateCount = nil
            overrideStateNilOnTick = nil
        else                                -- Opposite current override
            overrideState = not overrideState
            overrideStateNilOnTick = computer.millis() + RESET_OVERRIDE_MS
        end
    end
end
local function valueChangedThresholdMax( edata )
    --print( "valueChanged: ThresholdMax" )
    local v = edata[ 3 ]
    local p = v / 100.0
    setStorageThresholdHigh( p )
    triggerOffThreshold = p
    userUIOThresholdMin:setMax( v - 1 )
    thresholdChanged = true
    EEPROM.Boot.ComputerSettings[ "triggeroffthreshold"  ] = tostring( v )
    EEPROM.Settings.ToComputer()
end
local function valueChangedThresholdMin( edata )
    --print( "valueChanged: ThresholdMin" )
    local v = edata[ 3 ]
    local p = v / 100.0
    triggerOnThreshold = p
    setStorageThresholdLow( p )
    userUIOThresholdMax:setMin( v + 1 )
    thresholdChanged = true
    EEPROM.Boot.ComputerSettings[ "triggeronthreshold"  ] = tostring( v )
    EEPROM.Settings.ToComputer()
end


function getUserPanels()
    userPanels = component.getComponentsByClass( ClassGroup.ModulePanels.SizeableModulePanel )
    listProxiesAs( "Sizeable Module Panels", userPanels )
    
    if userPanels == nil or #userPanels == 0 then
        print( "Warning: No sizeable module panels found, thresholds and system overrides must be done manually.")
        return
    end
    
    -- Create the combinators or panic
    local states = {
        Color.new( 0.0, 1.0, 0.0, 0.0 ),    -- Auto off
        Color.new( 0.0, 1.0, 0.0, 1.0 ),    -- Auto on
        Color.new( 1.0, 1.0, 0.0, 0.0 ),    -- Force off
        Color.new( 1.0, 1.0, 0.0, 1.0 ),    -- Force on
    }
    userUIOSystemOnOff = UIO.createIntButtonCombinator( userPanels, UP_btnSystemOnOff, triggerSystemOnOff, states )
    if userUIOSystemOnOff == nil then
        panic( "Could not create System On/Off Button Combinator" )
    end
    
    -- Set the state to false until we are done booting
    adminUIOReflashAndReboot:setState( false )
    
    -- Get the threshold potentiometers
    local iOn = math.floor( triggerOnThreshold * 100.0 )
    local iOff = math.floor( triggerOffThreshold * 100.0 )
    
    userUIOThresholdMax = UIO.createPotentiometerCombinator( userPanels, UP_potMax, valueChangedThresholdMax, iOff, iOn + 1, 100 )
    if userUIOThresholdMax == nil then
        panic( "Could not create Threshold Max Potentiometer Combinator" )
    end
    
    userUIOThresholdMin = UIO.createPotentiometerCombinator( userPanels, UP_potMin, valueChangedThresholdMin, iOn, 0, iOff - 1 )
    if userUIOThresholdMin == nil then
        panic( "Could not create Threshold Min Potentiometer Combinator" )
    end
    
    userUIOThresholdMax:setForeColor( Color.WHITE )
    userUIOThresholdMin:setForeColor( Color.WHITE )
    
    -- Get the optional screen on/off button
    local ctrue  = Color.new( 0.0, 1.0, 1.0, 1.0 )
    local cfalse = Color.new( 0.0, 1.0, 1.0, 0.0 )
    userUIODisplayMode = UIO.createBoolButtonCombinator( userPanels, UP_btnDisplayMode, triggerDisplayMode, ctrue, cfalse, true )
    if userUIODisplayMode ~= nil then
        userUIODisplayMode:setState( not cpuSaverMode )
        cpuSaverOffTime = computer.millis() + cpuSaverTimeout
    end
    
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
        setRSSTextElement( 2, tostring( storageMax ), cWhite )
        
        if outputItems[ 1 ].isFluid then
            setRSSTextElement( 7, "Volume (m³)", cWhite )
        else
            setRSSTextElement( 7, "Inventory", cWhite )
        end
        
        rssStaticElementsSet = true
    end
    
    setRSSTextElement( 1, tostring( storageCurrent ), cWhite )
    setRSSTextElement( 3, tostring( throughput.rate, 0, 2, true ), cWhite )
    setRSSTextElement( 4, getStatusString(), cWhite )
    
end



-- Screen size calculator for Component Network config --

function getTotalDisplayLines()
    local t = 7 -- Update with fixed lines on the display (titles, headers, etc)
    local function addToT( base, able )
        local c = table.countKeyValuePairs( able )
        --print( c, t )
        if c > 0 then
            t = t + base + c
        end
    end
    addToT( 2, machineDatums )
    addToT( 2, inputItems )
    addToT( 2, outputItems )
    for _, sa in pairs( storageArrays ) do
        t = t + 5 + sa.count
    end
    t = t + ( #storageArrays - 1 ) -- Add one blank line for each output after the first
    return t
end

function getRecommendedScreenSize()
    local tL = getTotalDisplayLines()
    print( "Estimated lines: " .. tostring( tL ) )
    local pW = panelsWide
    local pH = math.max( 1, math.ceil( tL / screenCRPP ) )
    local cC = screenWidth
    local cR = pH * screenCRPP
    return pW, pH, cC, cR
end




-- Runtime Variables --
thresholdLow  = -1
thresholdHigh = -1
thresholdChanged = false    -- Dirty rect

onState = false

local statusCharIndex = 0
local statusChars = ACT_STATUS_ON   -- Using the same characters for the spiny circle
function getStatusString()
    statusCharIndex = ( statusCharIndex + 1 )
    if statusCharIndex > #statusChars then statusCharIndex = 1 end -- Would do modulus but Lua arrays aren't zero based
    if onState then
        return statusChars[ statusCharIndex ] .. 'nline '
    end
    return statusChars[ statusCharIndex ] .. 'ffline'
end


function updateState()
    -- Update state by preference order
    if overrideStateNilOnTick ~= nil and computer.millis() >= overrideStateNilOnTick then
        -- Clear the override state without changing the current state
        if automaticState == nil or overrideState == automaticState then
            -- But only if we aren't overriding the automatic control
            overrideState = nil
            overrideStateCount = nil
            overrideStateNilOnTick = nil
        else
            -- Otherwise wait until automatic on/off is nil
            overrideStateNilOnTick = computer.millis() + RESET_OVERRIDE_MS
        end
    end
    -- Update the system state with the override/automatic state
    if overrideState ~= nil then
        onState = overrideState
    elseif automaticState ~= nil then
        onState = automaticState
    end
end


nextSignUpdate = -1
firstDraw = true
function updateDisplays()
    local newTimestamp = computer.millis()
    if nextSignUpdate > newTimestamp + signUpdateMS then nextSignUpdate = -1 end
    if newTimestamp < nextSignUpdate then return end
    
    nextSignUpdate = newTimestamp + signUpdateMS
    
    if userUIODisplayMode ~= nil
    and not cpuSaverMode
    and newTimestamp >= cpuSaverOffTime then
        cpuSaverMode = true
        firstDraw = true
        userUIODisplayMode:setState( not cpuSaverMode )
    end
    
    updateScreens( firstDraw )
    updateRSSPanels()
    
    firstDraw = false
end



nextCycleUpdate = -1
function handleProductionCycle()
    local newTimestamp = computer.millis()
    if nextCycleUpdate > newTimestamp + cycleUpdateMS then nextCycleUpdate = -1 end
    if newTimestamp < nextCycleUpdate then return end
    
    nextCycleUpdate = newTimestamp + cycleUpdateMS
    
    -- Update the data to work with
    updateStorage()
    updateState()
    updateCycleData()
    
    -- Change the physical state of the system
    updateSwitches( onState )
    updateValves()
    updateMergers()
    updateConstantGate()
    
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
        panic( "triggerOffThreshold > 1.0" )
    end
    if triggerOnThreshold < 0.0 then
        panic( "triggerOnThreshold < 0.0" )
    end
    if triggerOnThreshold >= triggerOffThreshold then
        panic( "triggerOnThreshold >= triggerOffThreshold" )
    end
    
    
    -- Get GPUs to drive Screens
    getGPUs()
    
    -- Get Screens to be driven by GPUs
    getScreens()
    
    -- Get the "admin panels"
    getAdminPanels()
    
    -- Get the "user panels"
    getUserPanels()
    
    -- Get the power switches
    getSwitches()
    
    -- Get all the machines
    getMachines()
    
    -- Get the recipe from the machine
    getRecipeAndProduct()
    
    -- We've got the machines and the product[s], now check for compatible storage
    getStorage()
    
    -- Get any valves controlling fluid in-flow
    getValves()
    
    -- Get any codeable mergers controlling item in-flow
    getMergers()
    
    -- Get any Wiremod Constant Gate controlling item in-flow
    getConstantGate()
    
    
    local result, reason = MachineDatum.Collimator.new( machineType, outputItems, inputItems, screenWidth, baseProductionTime, screensSetText )
    if result == nil then panic( reason ) end
    machineCollimator = result
    
    -- Compute the recommended screen size
    print( string.format( "Recommended screen size:\n\tPanels: %d x %x\n\tCharacters: %d x %d", getRecommendedScreenSize() ) )
    
    -- Find the RSS Panels for "pretty formatting"
    getRSSPanels()
    
    -- Reset RSS Signs
    updateRSSPanels()
    
    -- Data gathering complete, now set the system to the initial state
    
    -- Update the control logic
    handleProductionCycle()
    
    -- Redraw all the screens and panels to the initial state
    updateDisplays()
    
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