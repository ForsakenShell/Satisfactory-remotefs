-- UI class for dealing with dynamic elements of RSS Signs


local UIO = require( "/UIO/UIO.lua", EEPROM.Remote.CommonLib )
if UIO.UIOElements.RSSElement ~= nil then return UIO.UIOElements.RSSElement end


local ClassGroup = require( "/lib/classgroups.lua", EEPROM.Remote.CommonLib )




---@class RSSElement:UIOElement
local RSSElement = UIO.UIOElement.template(
    "RSSElement",
    ClassGroup.Displays.Signs.ReallySimpleSigns.All,
    {},
    {
        -- Class Constants
        TYPE_TEXT = 0,
        TYPE_IMAGE = 1,
        TYPE_INVALID = -1,
        JUSTIFY_LEFT = 0,
        JUSTIFY_CENTER = 1,
        JUSTIFY_RIGHT = 2,
        -- Instance data
        index = -1,
        zOffset = 0,                -- Applied to the index passed into setZIndex
        __elementType = -1,
    }
)
UIO.UIOElements.RSSElement = RSSElement




-- The core functions of a UIOElement this can handle
function RSSElement:setForeColor( color )
    if self.__elementType == RSSElement.TYPE_INVALID then return end
    --print( 'RSSElement:setForeColor() ' .. Color.ToString( color ) )
    self.target:Element_SetColor( color, self.index )
end


function RSSElement:setOpacity( opacity )
    if self.__elementType == RSSElement.TYPE_INVALID then return end
    self.target:Element_SetOpacity( opacity, self.index )
end


function RSSElement:setText( text )
    if self.__elementType ~= RSSElement.TYPE_TEXT then return end
    self.target:Element_SetText( text, self.index )
end


function RSSElement:setJustification( justification )
    if self.__elementType ~= RSSElement.TYPE_TEXT then return end
    if justification < RSSElement.JUSTIFY_LEFT or justification > RSSElement.JUSTIFY_RIGHT then return end
    self.target:Element_SetJustify( justification, self.index )
end


function RSSElement:setIsBold( isBold )
    if self.__elementType ~= RSSElement.TYPE_TEXT then return end
    self.target:Element_SetIsBold( isBold, self.index )
end


function RSSElement:setIsUppercase( isUppercase )
    if self.__elementType ~= RSSElement.TYPE_TEXT then return end
    self.target:Element_SetUppercase( isUppercase, self.index )
end


function RSSElement:setSize( size )
    if self.__elementType == RSSElement.TYPE_TEXT then
        self.target:Element_SetTextSize( size, self.index )
    elseif self.__elementType == RSSElement.TYPE_IMAGE then
        self.target:Element_SetImageSize( size, self.index )
    end
end


function RSSElement:setZIndex( index )
    if self.__elementType == RSSElement.TYPE_INVALID then return end
    if self.zOffset ~= nil and type( self.zOffset ) == "number" then
        index = index + self.zOffset
    end
    --print( tostring( self.index ) .. ' -> ' .. tostring( index ) )
    self.target:Element_SetZIndex( index, self.index )
end


function RSSElement:setPosition( position )
    if self.__elementType == RSSElement.TYPE_INVALID then return end
    self.target:Element_SetPosition( position, self.index )
end




---Create an UIO.UIOElement for an RSS Sign Element
---@param sign userdata The RSS Sign
---@param index number The element index, these are 0-based in the sign
---@return RSSElement The UIOElement or nil
function RSSElement.create( sign, index )
    -- have to validate the sign now so that we can validate the index
    if not UIO.UIOElement.validTarget( RSSElement, sign ) then
        return nil
    end
    
    -- Now validate the index
    if index == nil or type( index ) ~= "number" or index < 0 or index >= sign:GetNumOfElements() then
        return nil
    end
    
    return UIO.UIOElement.create(
        RSSElement,
        sign,
        {
            index = index,
            __elementType = sign:GetIndexType( index ),
        },
        true    -- Target is already validated
    )
end




return RSSElement