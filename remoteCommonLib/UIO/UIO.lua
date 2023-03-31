--- Root namespace for all UIO classes and code
---@class UIO:table
---@field UIOElement table Base Element class
---@field UIOElements table Table of Element classes
local UIO = _G[ "____UIO" ]
if UIO ~= nil then return UIO end
UIO = {}
_G[ "____UIO" ] = UIO




---Base class of all UIOElements, see /UIO/UIOElements/ for specific implementations
---@class UIOElement:table
local UIOElement = {
    target = nil,           -- The object this UIOElement abstracts
    CLASS_ID = '',          -- UIOElement class
    ____classes = {},       -- Table of network component classes this UIOElement is compatable with
    ____signals = {},       -- Table of signals for this UIOElement
    ____handlers = {},      -- Table of event handler entries
}
UIOElement.__index = UIOElement
UIO.UIOElement = UIOElement




--- Used to store all UIOElement Templates and provide global functions for UIOElements that are not specific to a single UIOElement.
---@class UIOElements:table
local UIOElements = {}
UIOElements.Templates = {}
UIOElements.Instances = {}
UIO.UIOElements = UIOElements


function UIOElements:eventHandler( edata )
    if edata == nil or type( edata ) ~= "table" or #edata < 2 then return false end
    local name = edata[ 1 ]
    local sender = edata[ 2 ]
    
    for _, element in pairs( UIOElements.Instances ) do
        
        if sender == element.target then
            
            local handler = element.____handlers[ name ]
            if handler ~= nil then
                
                local targ = element                    -- Send the triggering element
                if element.____combinator ~= nil then
                    targ = element.____combinator       -- Promote the event to the Combinator
                end
                
                local blocked = targ.____signalBlockState ~= nil and targ.____signalBlockState
                if not blocked then
                    
                    edata[ 2 ] = targ
                    --print( "Sending event to " .. targ.CLASS_ID )
                    handler( edata )
                    
                end
                
                return true                         -- Regardless of whether the signal was blocked, the Element would have consumed the event
            end
            
        end
        
    end
    
    edata[ 2 ] = sender                             -- Replace the sender as we didn't process this
    return false                                    -- No elements handled the event
end




--------------------------------------------------------------------------------

-- Base class functions, do not override these

-- Register a callback signal handler for the UIOElement
function UIOElement:setSignalHandler( signal, handler )
    --print( signal )
    --print( "\t" .. tostring( handler ) )
    if signal == nil then
        --computer.panic( "UIOElement:setSignalHandler() - signal is nil\n" .. debug.traceback() )
        return false
    end
    if type( signal ) ~= "string" then
        --computer.panic( "UIOElement:setSignalHandler() - signal is wrong type, expected 'string' got '" .. tostring( type( signal ) ) .. "'\n" .. debug.traceback() )
        return false
    end
    if signal == '' then
        --computer.panic( "UIOElement:setSignalHandler() - signal is empty\n" .. debug.traceback() )
        return false
    end
    if handler == nil then
        --computer.panic( "UIOElement:setSignalHandler() - handler is nil\n" .. debug.traceback() )
        return false
    end
    if type( handler ) ~= "function" then
        --computer.panic( "UIOElement:setSignalHandler() - handler is wrong type, expected 'function' got '" .. tostring( type( handler ) ) .. "'\n" .. debug.traceback() )
        return false
    end
    
    -- Check the signal validity
    if self.____signals[ signal ] == nil then
        --computer.panic( "UIOElement:setSignalHandler() - Invalid signal '" .. signal .. "'\n" .. debug.traceback() )
        return false
    end
    
    -- Set the handler
    self.____handlers[ signal ] = handler
    
    
    -- Start listening for signals on the target now that we have handlers
    event.listen( self.target )
    
    return true
end




--------------------------------------------------------------------------------

-- Template Class and Instance Instantiation
-- THESE ARE NOT A USERCODE FUNCTIONS!  Use the proper create() function on the Template Class itself


local function uioElementWithNameExists( name )
    for _, template in pairs( UIOElements.Templates ) do
        if template.CLASS_ID == name then
            return true
        end
    end
    return false
end

---Create a Template Class that actual Instances can be created from
---@param classes table: Array of strings of valid target object classes
---@param signals table: Array of strings of the signals the target object classes can receive
---@param o table: Template fields to build the Template Class around
---@return UIOElement?: Resulting Template Class or nil if any error occured
function UIOElement.template( name, classes, signals, o )
    if name == nil or type( name ) ~= "string" or name == '' or uioElementWithNameExists( name ) then
        computer.panic( "UIOElement.template() invalid name\n" .. debug.traceback() )
    end
    if classes == nil or type( classes ) ~= "table" or table.countKeyValuePairs( classes ) == 0 then
        computer.panic( "UIOElement.template() invalid classes\n" .. debug.traceback() )
    end
    
    if signals == nil or type( signals ) ~= "table" then
        computer.panic( "UIOElement.template() invalid signals\n" .. debug.traceback() )
    end
    
    if o == nil or type( o ) ~= "table" then
        computer.panic( "UIOElement.template() invalid template object (o) - must be a valid table\n" .. debug.traceback() )
    end
    
    -- Clone the table so that the usercode cannot change it after the template is created
    local __classes = {}
    for _, c in pairs( classes ) do
        if c == nil or type( c ) ~= "string" or c == '' then
            computer.panic( "UIOElement.template() invalid class\n" .. debug.traceback() )
        end
        table.insert( __classes, c )
    end
    
    -- Create the table of event handler entry points
    local __signals = {}
    for _, s in pairs( signals ) do
        if s == nil or type( s ) ~= "string" or s == '' then
            computer.panic( "UIOElement.template() invalid signal\n" .. debug.traceback() )
        end
        __signals[ s ] = s
    end
    
    -- Finalize the inheritence
    o.CLASS_ID      = name
    o.____classes   = __classes
    o.____signals   = __signals
    o.____handlers  = {}        -- This should never be added to and remain nil
    setmetatable( o, { __index = UIOElement } )
    
    table.insert( UIOElements.Templates, o )
    
    return o
end



---Validate that the Template and Target are compatible
---@param template UIOElement: Template Class
---@param target userdata: tostring( target ) must match one of template.____classes
---@return boolean: true is everything checks out, false for any other reason
function UIOElement.validTarget( template, target )
    if template == nil then
        computer.panic( "UIOElement.validTarget() - template is nil\n" .. debug.traceback() )
        return false
    end
    if type( template ) ~= "table" then
        computer.panic( "UIOElement.validTarget() - invalid template type, expected 'table' - '" .. tostring( type( template ) ) .. "'\n" .. debug.traceback() )
        return false
    end
    if template.____classes == nil then
        computer.panic( "UIOElement.validTarget() - template classes is nil" .. debug.traceback() )
        return false
    end
    if type( template.____classes ) ~= "table" then
        computer.panic( "UIOElement.validTarget() - invalid template classes type, expected 'table' - '" .. tostring( type( template.____classes ) ) .. "'\n" .. debug.traceback() )
        return false
    end
    if #template.____classes == 0 then
        computer.panic( "UIOElement.validTarget() - invalid template classes, array is empty" .. debug.traceback() )
        return false
    end
    
    
    if target == nil then
        computer.panic( "UIOElement.validTarget() - target is nil\n" .. debug.traceback() )
        return false
    end
    if type( target ) ~= "userdata" then
        computer.panic( "UIOElement.validTarget() - invalid target type, expected 'userdata' - '" .. tostring( type( target ) ) .. "'\n" .. debug.traceback() )
        return false
    end
    if not table.hasValue( template.____classes, tostring( target ) ) then
        local t = "UIOElement.validTarget() - invalid target class - '" .. tostring( target ) .. "' - expected:"
        for _, c in pairs( template.____classes ) do
            t = t .. "\n\t" .. c
        end
        t = t .. "\n" .. debug.traceback()
        computer.panic( t )
        return false
    end
    
    return true
end



---Create the core Instance Class for the target component/module/etc
---@param template UIOElement: Template Class we want an instance of
---@param target userdata: Target this instance is for
---@param o table: Instance fields
---@param targetOk boolean?: Template and Target have been pretested and are valid
---@return UIOElement?: Resulting Instance of Template Class or nil if any error occured
function UIOElement.create( template, target, o, targetOk )
    if targetOk == nil or type( targetOk ) ~= "boolean" or not targetOk then
        if not UIOElement.validTarget( template, target ) then return nil end
    end
    
    o = o or {}
    o.target = target
    o.____handlers = {}         -- Table of signal handlers for the instance
    setmetatable( o, { __index = template } )
    
    table.insert( UIOElements.Instances, o )
    return o
end






-------------------------------------------------------------------------------

-- The interface that needs to be implemented in actual UI element class templates


function UIOElement:setForeColor( color ) end
function UIOElement:setBackColor( color ) end
function UIOElement:setOpacity( opacity ) end
function UIOElement:setText( text ) end
function UIOElement:setJustification( justification ) end
function UIOElement:setIsBold( isBold ) end
function UIOElement:setIsUppercase( isUppercase ) end
function UIOElement:setSize( size ) end
function UIOElement:setZIndex( index ) end
function UIOElement:setPosition( position ) end

function UIOElement:update() end




return UIO