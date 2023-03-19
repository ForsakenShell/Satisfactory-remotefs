-- UI class for dealing with Buttom Modules


local UIO = require( "/UIO/UIO.lua", ____RemoteCommonLib )
if UIO.UIOElements.ButtonModule ~= nil then return UIO.UIOElements.ButtonModule end


local ClassGroup = require( "/lib/classgroups.lua", ____RemoteCommonLib )




---@class ButtonModule:UIO.UIOElement
local ButtonModule = UIO.UIOElement.template(
    "ButtonModule",
    ClassGroup.Modules.Buttons.All,
    { "Trigger" },
    {
        -- Class Constants
        -- Instance data
    }
)
UIO.UIOElements.ButtonModule = ButtonModule




-- The core functions of a UIOElement this can handle
function ButtonModule:setForeColor( color )
    --print( debug.traceback() )
    --print( tostring( computer.millis() ) )
    self.target:setColor( color.r, color.g, color.b, color.a )
end




---Create an UIO.UIOElement for a Panel Button Module
---@param button userdata: The button
---@return ButtonModule?: The UIOElement or nil
function ButtonModule.create( button )
    return UIO.UIOElement.create(
        ButtonModule,
        button,
        {
        }
    )
end




return ButtonModule