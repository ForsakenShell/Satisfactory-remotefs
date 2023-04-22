-- Component Network:
-- + Computer:
-- | + nickname settings: remotefs="testfs" bootloader="WiremodConveyorLimiter.lua"
-- | + 1 Lua CPU
-- | + 1 T1 RAM
-- | + 1 T1 GPU
-- | + 1 EEPROM with the remotefs boot loader script
-- + Large Screen (1x1)
-- + 1 Single Point Module Panel
-- | + 1 ModuleButton
-- + 1 Wiremod Constant Gate (Other, Unnamed)
--   + Bool: "Enable"
--   + Link the "Enable" Bool to the Wiremod Conveyor Limiter "Set Enabled" input

-- Additional structures:
-- 1 Wiremod Conveyor Limiter (Logistics, Sorting); see the Component Network above
-- 1 Storage
-- Connect the Storage and Limiter in a loop with conveyor belts

-- Put some items in the Storage.
-- Turn on the computer.
-- The screen will show a periodic tick counter at the bottom and the current limiter enable state at the top.
-- Push the button to toggle allowing items through the limiter.


local ClassGroup                = require( "/lib/classgroups.lua", EEPROM.Remote.CommonLib )
local GPUs                      = ClassGroup.Displays.GPUs
local Screens                   = ClassGroup.Displays.Screens

local WMGates                   = ClassGroup.Wiremod.Gates


function dumpWMObjectFuncs( wmobject )
    local wmFuncs = wmobject:getAllWiremodFuncs()
    for k, v in pairs( wmFuncs ) do
        print( k, v )
    end
end

function getBool( wmobject, bool )
    local result = wmobject:getWireBool( bool )
    print( bool .. " = " .. tostring( result ) )
end

function getNumber( wmobject, num )
    local result = wmobject:getWireNumber( num )
    print( num .. " = " .. tostring( result ) )
end

function setWMConstBool( wmobject, name, value )
    while wmobject:getWireBool( name ) ~= value do
        wmobject:setConstBoolValue( name, value )
    end
end

function getWMConstBool( wmobject, name )
    return wmobject:getWireBool( name )
end




local gpu = computer.getPCIDevicesByClass( GPUs )[ 1 ]
local screen = component.getComponentsByClass( Screens.Build_Screen_C )[ 1 ]
local screenWidth  = 30
local screenHeight = 15
gpu:bindScreen( screen )
gpu:setSize( screenWidth, screenHeight )

local finPanel = component.getComponentsByClass( { ClassGroup.ModulePanels.MCP_1Point_C, ClassGroup.ModulePanels.MCP_1Point_Center_C } )[ 1 ]
local finButton = finPanel:getModule( 0, 0 )



local wmConstant = component.getComponentsByClass( WMGates.Build_Const_C )[ 1 ]

local sENABLE = "Enable"

function drawScreen()
    
    local isEnabled = getWMConstBool( wmConstant, sENABLE )
    
    gpu:setBackground( 0.0, 0.0, 0.0, 1.0 )
    gpu:setForeground( 0.0, 0.0, 0.0, 1.0 )
    gpu:fill( 0, 0, screenWidth, screenHeight, 'X' )
    
    gpu:setForeground( 1.0, 1.0, 1.0, 1.0 )
    
    gpu:setText( 0, 0, sENABLE .. " = " .. tostring( isEnabled ) )
    
    gpu:setText( 0, screenHeight - 1, tostring( computer.millis() ) )
    gpu:flush()
end

event.clear()
event.listen( finButton )

while true do
    
    drawScreen()
    
    local edata = { event.pull( 1.0 ) }
    
    if edata ~= nil and #edata >= 2 and edata[ 2 ] == finButton then
        
        local newValue = not getWMConstBool( wmConstant, sENABLE )
        setWMConstBool( wmConstant, sENABLE, newValue )
        
    end
    
end
