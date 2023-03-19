-- UI Combinator class - This treats multiple child elements as a single element
-- This is an extremely special case class that does things no other class should




local UIO = require( "/UIO/UIO.lua", ____RemoteCommonLib )
if UIO.UIOElements.Combinator ~= nil then return UIO.UIOElements.Combinator end




--[[
Combinator = UIO.UIOElement.template(
    {},
    {},
    {
        -- Class Constants
        -- Instance data
        ____elements = {}
    }
)]]
local function createCombinatorTemplate()
    local o = {
        CLASS_ID        = "Combinator",
        ____elements    = {},       -- The real stars of the show
    }
    setmetatable( o, { __index = UIO.UIOElement } )
    
    table.insert( UIO.UIOElements.Templates, o )
    return o
end

---@class Combinator:UIO.UIOElement
local Combinator = createCombinatorTemplate()
UIO.UIOElements.Combinator = Combinator



--------------------------------------------------------------------------------

-- This class does everything, it multicasts functions across all elements
-- Functions that have return values, the values are discarded
local function multicast( elements, func, filters, ... )
    --print( func )
    if elements == nil or type( elements ) ~= "table" or #elements == 0 then return end
    if filters ~= nil and type( filters ) ~= "table" then return end
    for _, element in pairs( elements ) do
        local include = true
        if filters ~= nil then
            if filters.uioclass ~= nil and element.CLASS_ID == filters.uioclass then include = false end
            if filters.zOffset ~= nil and element.zOffset ~= nil and element.zOffset ~= filters.zOffset then include = false end
        end
        if include then
            --print( "\t" .. element.target.internalName )
            local f = element[ func ]
            --print( "\t" .. tostring( f ) )
            if f ~= nil and type( f ) == "function" then
                f( element, ... )
            end
        end
    end
end




--------------------------------------------------------------------------------

-- Base class functions, do not override these - This class is the ONLY exception to this!

-- Register a callback signal handler for the UIOElement
function Combinator:setSignalHandler( signal, handler )
    if signal == nil then
        --computer.panic( "Combinator:setSignalHandler() - signal is nil\n" .. debug.traceback() )
        return false
    end
    if type( signal ) ~= "string" then
        --computer.panic( "Combinator:setSignalHandler() - signal is wrong type, expected 'string' got '" .. tostring( type( signal ) ) .. "'\n" .. debug.traceback() )
        return false
    end
    if signal == '' then
        --computer.panic( "Combinator:setSignalHandler() - signal is empty\n" .. debug.traceback() )
        return false
    end
    if handler == nil then
        --computer.panic( "Combinator:setSignalHandler() - handler is nil\n" .. debug.traceback() )
        return false
    end
    if type( handler ) ~= "function" then
        --computer.panic( "Combinator:setSignalHandler() - handler is wrong type, expected 'function' got '" .. tostring( type( handler ) ) .. "'\n" .. debug.traceback() )
        return false
    end
    
    local result = true
    
    -- Apply to elements
    for _, element in pairs( self.____elements ) do
        
        -- But only if the element supports the signal
        if element.____signals[ signal ] ~= nil then
            -- Set the handler
            element.____handlers[ signal ] = handler
            
            -- Start listening for signals on the target now that we have handlers
            event.listen( element.target )
            
            --print( "Listening for '" .. signal .. "' on " .. element.target.internalName )
            
            result = true
        end
    end
    
    return result
end




--------------------------------------------------------------------------------

-- All the core functions

function Combinator:setForeColor( color )
    --print( 'Combinator:setForeColor() ' .. tostring( color ) )
    multicast( self.____elements, "setForeColor", nil, color )
end
function Combinator:setBackColor( color )
    --print( 'Combinator:setBackColor() ' .. tostring( color ) )
    multicast( self.____elements, "setBackColor", nil, color )
end
function Combinator:setOpacity( opacity )
    multicast( self.____elements, "setOpacity", nil, opacity )
end
function Combinator:setText( text )
    multicast( self.____elements, "setText", nil, text )
end
function Combinator:setJustification( justification )
    multicast( self.____elements, "setJustification", nil, justification )
end
function Combinator:setIsBold( isBold )
    multicast( self.____elements, "setIsBold", nil, isBold )
end
function Combinator:setIsUppercase( isUppercase )
    multicast( self.____elements, "setIsUppercase", nil, isUppercase )
end
function Combinator:setSize( size )
    multicast( self.____elements, "setSize", nil, size )
end
function Combinator:setZIndex( index )
    multicast( self.____elements, "setZIndex", nil, index )
end
function Combinator:setPosition( position )
    multicast( self.____elements, "setPosition", nil, position )
end




--------------------------------------------------------------------------------

-- Expanded versions of the core functions
-- filters = {
--      uioclass: string?,  -- Must be this UIOElement subclass
--      zOffset: number?,   -- Must have a zOffset field that matches
-- }

function Combinator:setForeColorEx( color, filters )
    --print( 'Combinator:setForeColorEx() ' .. tostring( color ) )
    multicast( self.____elements, "setForeColor", filters, color )
end
function Combinator:setBackColorEx( color, filters )
    --print( 'Combinator:setBackColorEx() ' .. tostring( color ) )
    multicast( self.____elements, "setBackColor", filters, color )
end
function Combinator:setOpacityEx( opacity, filters )
    multicast( self.____elements, "setOpacity", filters, opacity )
end
function Combinator:setTextEx( text, filters )
    multicast( self.____elements, "setText", filters, text )
end
function Combinator:setJustificationEx( justification, filters )
    multicast( self.____elements, "setJustification", filters, justification )
end
function Combinator:setIsBoldEx( isBold, filters )
    multicast( self.____elements, "setIsBold", filters, isBold )
end
function Combinator:setIsUppercaseEx( isUppercase, filters )
    multicast( self.____elements, "setIsUppercase", filters, isUppercase )
end
function Combinator:setSizeEx( size, filters )
    multicast( self.____elements, "setSize", filters, size )
end
function Combinator:setZIndexEx( index, filters )
    multicast( self.____elements, "setZIndex", filters, index )
end
function Combinator:setPositionEx( position, filters )
    multicast( self.____elements, "setPosition", filters, position )
end




--------------------------------------------------------------------------------

---Create an UIO.UIOElement for an Element Combinator
---@param elements table: Table of UIOElements to be treated as a single entity
---@return Combinator?: The UIOElement or nil
function Combinator.create( elements )
    if elements ~= nil and type( elements ) ~= "table" then
        computer.panic( "Combinator.create() invalid children\n" .. debug.traceback() )
    end
    
    local o = {}
    
    local __elements = {}
    for _, element in pairs( elements ) do
        if element == nil or type( element ) ~= "table" or element.CLASS_ID == nil or type( element.CLASS_ID ) ~= "string" then
            computer.panic( "Combinator.create() - invalid elements" )
        end
        table.insert( __elements, element )
        element.____combinator = o
    end
    
    o.____elements    = __elements
    
    setmetatable( o, { __index = Combinator } )
    table.insert( UIO.UIOElements.Instances, o )
    return o
end




---Add an UIOElement to the Combinator
---@param element any
function Combinator:addCombinedElement( element )
    table.insert( self.____elements, element )
    element.____combinator = self
end


function Combinator:getCombinedElementsByUIOClass( classid )
    local results = {}
    for _, element in pairs( self.____elements ) do
        if element.CLASS_ID == classid then
            table.insert( results, element )
        end
    end
    return results
end




return Combinator