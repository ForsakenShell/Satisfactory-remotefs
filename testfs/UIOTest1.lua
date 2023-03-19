--[[
    Basic UIO Test
    Setup:
        One Component Network Pole (wall plug, etc)
        One Really Simple Sign (RSS) with a Text element at index 0
        One Module Panel (any)
        One Button Module on the Module Panel at { 0, 0 }
        One Computer with:
            One Lua CPU
            One RAM
            One InternetCard
            One EEPROM loaded with EEPROM.lua
            One Floppy (until FIN fixes the tmpfs bug)
            Nickname: remotefs="testfs" bootloader="UIOTest1.lua"
        Component Network them all together, of course
    Expectations:
        Run the program, push the button, watch the text element on the sign change from true/false
]]


require( "/UIO/UIOElements/RSSElement.lua", ____RemoteCommonLib )
require( "/UIO/UIOElements/ButtonModule.lua", ____RemoteCommonLib )




-- Program vars
local state = true  -- Gotta show something on the sign, right?




-- Get the RSS Sign
local signs = component.getComponentsByClass( ClassGroup.Displays.Signs.ReallySimpleSigns.All )
if signs == nil or #signs == 0 then
    computer.panic( "No Really Simple Sign" )
end
local sign = signs[ 1 ]
print( "Sign : " .. sign.id )

local uioRSSElement = UIO.UIOElements.RSSElement.create( sign, 0 )
if uioRSSElement == nil then
    computer.panic( "Unable to create UIO.UIOElements.RSSElement for sign element 0!" )
end




-- Get the Module Panel
local panels = component.getComponentsByClass( ClassGroup.ModulePanels.All )
if panels == nil or #panels == 0 then
    computer.panic( "No Module Panel!" )
end
local panel = panels[ 1 ]
print( "Panel : " .. panel.id )




-- Get the Button on the Panel
local button = panel:getModule( 0, 0 )
if button == nil then
    computer.panic( "No Button Module!" )
end
print( "Button : " .. button.internalName )

local uioButtonModule = UIO.UIOElements.ButtonModule.create( button )
if uioButtonModule == nil then
    computer.panic( "Unable to create UIO.UIOElements.ButtonModule for panel module at { 0, 0 }!" )
end



-- Set the Button "Trigger" handler
local triggerCallback = function( edata )
    -- hard coded globals, eww
    state = not state
    uioRSSElement:setText( tostring( state ) )
    
    -- Get the button from the event data, notice the sender is the UIOElement not the button itself.  The button (if needed) can be obtained by sender.target
    local sender = edata[ 2 ]
    
    -- Set the color intensities
    local fState = 0.0
    if state then fState = 1.0 end
    uioRSSElement:setForeColor( { r = 1.0, g = 1.0, b = 1.0, a = fState * 1.0  } )
    sender:setForeColor( { r = 1.0, g = 1.0, b = 1.0, a = fState * 0.25 } )
end


if not uioButtonModule:setSignalHandler( "Trigger", triggerCallback ) then
    computer.panic( "Unable to set signal handler for UIO.UIOElements.ButtonModule!" )
end







-- Now the basic loop
while true do
    local edata = { event.pull() }
    UIO.UIOElements:eventHandler( edata )
end