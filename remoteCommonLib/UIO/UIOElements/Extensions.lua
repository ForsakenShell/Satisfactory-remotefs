local UIO = require( "/UIO/UIO.lua", EEPROM.Remote.CommonLib )
if UIO.UIOElements.Extensions ~= nil then return UIO.UIOElements.Extensions end




-- UIO Element extensions
local Extensions = {}
UIO.UIOElement.Extensions = Extensions


local Color = require( "/lib/Colors.lua", EEPROM.Remote.CommonLib )



local function updateElementForStateChange( element, state, block, blockState )
    if state == nil then
        state = element.____state
    end
    if state == nil then return end
    
    local stateColor = element.stateColor
    if stateColor == nil then return end
    
    -- Force false state if signal blocking
    if type( block ) ~= "boolean" then
        if element.____combinator ~= nil and element.____combinator.____signalBlockState ~= nil then
            block = element.____combinator.____signalBlockState
        elseif element.____signalBlockState ~= nil then
            block = element.____signalBlockState
        else
            block = false
        end
    end
    
    if block then state = blockState end
    
    local c = stateColor[ state ]
    if c ~= nil then
        element:setForeColor( c )
    end
    
end




----------------------------------------------------------------
---Signal Block Control


function Extensions.AddSignalBlockControl( element, initial, blockState )
    if not UIO.isUIOElement( element ) then
        computer.panic( debug.traceback( "Extensions.AddSignalBlockControl() - element must be a UIOElement" ) )
    end
    
    if initial == nil then
        initial = false
    end
    if type( initial ) ~= "boolean" then
        computer.panic( "Extensions.AddSignalBlockControl() - initial must be nil or boolean")
    end
    
    if element.____blockState ~= nil then blockState = element.____blockState end
    if blockState == nil then
        computer.panic( debug.traceback( "Extensions.AddSignalBlockControl() - blockState must be set by AddBoolStateControl(), AddIntStateControl() or, set explicitly by AddSignalBlockControl()" ) )
    end
    
    element.____signalBlockState = initial
    element.____blockState = blockState
    
    element.setSignalBlockState = function( this, state )
        this.____signalBlockState = state
        --print( tostring( computer.millis() ) )
        if element.CLASS_ID == UIO.UIOElements.Combinator.CLASS_ID then
            --print( element.CLASS_ID )
            
            local block = element.____signalBlockState
            for _, element in pairs( this.____elements ) do
                updateElementForStateChange( element, state, block, this.____blockState )
            end
            
        else
            --print( element.target.internalName )
            updateElementForStateChange( this )
            
        end
    end
    
    element.getSignalBlockState = function( this )
        return this.____signalBlockState
    end
    
end




----------------------------------------------------------------
---Bool state

function Extensions.AddBoolStateControl( element, initial, blockState )
    if not UIO.isUIOElement( element ) then
        computer.panic( debug.traceback( "Extensions.AddBoolStateControl() - element must be a UIOElement" ) )
    end
    if initial == nil then
        initial = false
    end
    if type( initial ) ~= "boolean" then
        computer.panic( debug.traceback( "Extensions.AddBoolStateControl() - initial must be nil or boolean" ) )
    end
    
    if blockState == nil then
        blockState = false
    end
    if type( blockState ) ~= "boolean" then
        computer.panic( debug.traceback( "Extensions.AddBoolStateControl() - blockState must be nil or boolean" ) )
    end
    
    element.____state = initial
    element.____blockState = blockState
    
    element.setState = function( this, state )
        if type( state ) ~= "boolean" then
            computer.panic( debug.traceback( "Extensions.AddBoolStateControl().setState() - state must be a boolean" ) )
        end
        this.____state = state
        
        if element.CLASS_ID == UIO.UIOElements.Combinator.CLASS_ID then
            
            local block = element.____signalBlockState
            for _, element in pairs( this.____elements ) do
                updateElementForStateChange( element, state, block, this.____blockState )
            end
            
        else
            
            updateElementForStateChange( this )
            
        end
        
    end
    
    ---Return the current boolean State of the UIOElement
    ---@param this UIOElement
    ---@return boolean Current boolean state
    element.getState = function( this )
        return this.____state
    end
    
end


function Extensions.AddBoolStateColours( element, ctrue, cfalse )
    if not UIO.isUIOElement( element ) then
        computer.panic( debug.traceback( "Extensions.AddBoolStateColours() - element must be a UIOElement" ) )
    end
    if not Color.isColor( ctrue ) then
        computer.panic( debug.traceback( "Extensions.AddBoolStateColours() - ctrue must be a Color" ) )
    end
    if not Color.isColor( cfalse ) then
        computer.panic( debug.traceback( "Extensions.AddBoolStateColours() - ctrue must be a Color" ) )
    end
    element.stateColor = {}
    element.stateColor[ true  ] = ctrue
    element.stateColor[ false ] = cfalse
end




----------------------------------------------------------------
---Integer state


function Extensions.AddIntStateControl( element, initial, blockState )
    if not UIO.isUIOElement( element ) then
        computer.panic( debug.traceback( "Extensions.AddIntStateControl() - element must be a UIOElement" ) )
    end
    if initial == nil then
        initial = 1
    end
    if type( initial ) ~= "number" then
        computer.panic( debug.traceback( "Extensions.AddIntStateControl() - initial must be nil or a positive integer" ) )
    end
    
    if blockState == nil then
        blockState = 1
    end
    if type( blockState ) ~= "number" then
        computer.panic( debug.traceback( "Extensions.AddIntStateControl() - blockState must be nil or a positive integer" ) )
    end
    
    element.____state = initial
    element.____blockState = blockState
    
    element.setState = function( this, state )
        if type( state ) ~= "number" then
            computer.panic( debug.traceback( "Extensions.AddIntStateControl().setState() - state must be a positive integer" ) )
        end
        this.____state = state
        
        if element.CLASS_ID == UIO.UIOElements.Combinator.CLASS_ID then
            
            local block = element.____signalBlockState
            for _, element in pairs( this.____elements ) do
                updateElementForStateChange( element, state, block, this.____blockState )
            end
            
        else
            
            updateElementForStateChange( this )
            
        end
        
    end
    
    ---Return the current integer State of the UIOElement
    ---@param this UIOElement
    ---@return integer Current integer state
    element.getState = function( this )
        return this.____state
    end
    
end


function Extensions.AddIntStateColours( element, states )
    if not UIO.isUIOElement( element ) then
        computer.panic( debug.traceback( "Extensions.AddIntStateColours() - element must be a UIOElement" ) )
    end
    if states == nil or type( states ) ~= "table" or #states == 0 then
        computer.panic( debug.traceback( "Extensions.AddIntStateColours() - states must an array of colors" ) )
    end
    if table.countKeyValuePairs( states ) ~= #states then
        computer.panic( debug.traceback( "Extensions.AddIntStateColours() - states must an array of colors" ) )
    end
    local sc = element.stateColor or {}
    for state, color in pairs( states ) do
        if type( state ) ~= "number" or state < 1 then
            computer.panic( debug.traceback( "Extensions.AddIntStateColours() - state must be a positive integer" ) )
        end
        if not Color.isColor( color ) then
            computer.panic( debug.traceback( "Extensions.AddIntStateColours() - color must be a Color" ) )
        end
        sc[ state ] = color
    end
    element.stateColor = sc
end



function Extensions.AddIntStateColour( element, state, color )
    if not UIO.isUIOElement( element ) then
        computer.panic( debug.traceback( "Extensions.AddIntStateColour() - element must be a UIOElement" ) )
    end
    if state == nil or type( state ) ~= "number" or state < 1 then
        computer.panic( debug.traceback( "Extensions.AddIntStateColour() - state must be a positive integer" ) )
    end
    if not Color.isColor( color ) then
        computer.panic( debug.traceback( "Extensions.AddIntStateControl() - color must be a Color" ) )
    end
    local sc = element.stateColor or {}
    sc[ state ] = color
    element.stateColor = sc
end



return Extensions