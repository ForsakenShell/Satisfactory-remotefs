local UIO = require( "/UIO/UIO.lua", ____RemoteCommonLib )




-- UIO Element extensions
local Extensions = {}
UIO.UIOElement.Extensions = Extensions




local function updateElementForStateChange( element, state, block )
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
    
    if block then state = false end
    
    local c = stateColor[ state ]
    if c ~= nil then
        element:setForeColor( c )
    end
    
end




function Extensions.AddSignalBlockControl( element, initial )
    if initial == nil then
        initial = false
    end
    if type( initial ) ~= "boolean" then
        computer.panic( "Extensions.AddSignalBlockControl() - initial must be nil or boolean")
    end
    
    element.____signalBlockState = initial
    
    element.setSignalBlockState = function( this, state )
        this.____signalBlockState = state
        --print( tostring( computer.millis() ) )
        if element.CLASS_ID == UIO.UIOElements.Combinator.CLASS_ID then
            --print( element.CLASS_ID )
            
            local block = element.____signalBlockState
            for _, element in pairs( this.____elements ) do
                updateElementForStateChange( element, state, block )
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


function Extensions.AddBoolStateControl( element, initial )
    if initial == nil then
        initial = false
    end
    if type( initial ) ~= "boolean" then
        computer.panic( "Extensions.AddBoolStateControl() - initial must be nil or boolean")
    end
    
    element.____state = initial
    
    element.setState = function( this, state )
        this.____state = state
        
        if element.CLASS_ID == UIO.UIOElements.Combinator.CLASS_ID then
            
            local block = element.____signalBlockState
            for _, element in pairs( this.____elements ) do
                updateElementForStateChange( element, state, block )
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
    element.stateColor = {}
    element.stateColor[ true  ] = ctrue
    element.stateColor[ false ] = cfalse
end




return Extensions