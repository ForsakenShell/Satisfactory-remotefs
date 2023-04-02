--[[
    Basic UIO Test
    Setup:
        One Component Network Pole (wall plug, etc)
        One or more Really Simple Sign (RSS) each with a Text element at index 0
        One or more Module Panel (any)
        One Button Module on each Module Panel at { 0, 0 }
        One Computer with:
            One Lua CPU
            One RAM
            One InternetCard
            One EEPROM loaded with EEPROM.lua
            One Floppy (until FIN fixes the tmpfs bug)
            Nickname: remotefs="testfs" bootloader="UIOTest2.lua"
        Component Network them all together, of course
    Expectations:
        Run the program, push one of the buttons, watch the text elementa on the signs change from true/false
]]


require( "/UIO/UIOElements/RSSElement.lua", EEPROM.Remote.CommonLib )
require( "/UIO/UIOElements/ButtonModule.lua", EEPROM.Remote.CommonLib )
require( "/UIO/UIOElements/Combinator.lua", EEPROM.Remote.CommonLib )




-- Program vars
local state = true

local uioCombinator = nil
local uioCombined = {}




-- Get the RSS Sign
local signs = component.getComponentsByClass( ClassGroup.Displays.Signs.ReallySimpleSigns.All )
if signs == nil or #signs == 0 then
    computer.panic( "No Really Simple Signs" )
end

for _, sign in pairs( signs ) do
    print( "Sign : " .. sign.id )
    local uio = UIO.UIOElements.RSSElement.create( sign, 0 )
    if uio == nil then
        computer.panic( "Unable to create UIO.UIOElements.RSSElement for sign element 0!" )
    end
    table.insert( uioCombined, uio )
end




-- Get the Module Panels
local panels = component.getComponentsByClass( ClassGroup.ModulePanels.All )
if panels == nil or #panels == 0 then
    computer.panic( "No Module Panel!" )
end

for _, panel in pairs( panels ) do
    print( "Panel : " .. panel.id )
    
    -- Get the Button on the Panel
    local button = panel:getModule( 0, 0 )
    if button == nil then
        computer.panic( "No Button Module on Panel at { 0, 0 }!" )
    end
    print( "\tButton : " .. button.internalName )

    local uio = UIO.UIOElements.ButtonModule.create( button )
    if uio == nil then
        computer.panic( "Unable to create UIO.UIOElements.ButtonModule for panel module at { 0, 0 }!" )
    end
    
    table.insert( uioCombined, uio )
end



-- Create a Combinator to control them all as one
uioCombinator = UIO.UIOElements.Combinator.create( uioCombined )
if uioCombinator == nil then
    computer.panic( "Unable to create UIO.UIOElements.Combinator for to rule them all!" )
end




-- Set the Combinator "Trigger" handler
local triggerCallback = function( edata )
    -- hard coded globals, eww
    state = not state
    
    -- Set the text on all of them as the entire group
    uioCombinator:setText( tostring( state ) )
    
    -- Get the Combinator from the event data, notice the sender is the Combinator and not the Button Module OR the individual button that was triggered.
    local sender = edata[ 2 ]
    
    -- Set the color of the elements by their type so we can set different intensities
    local fState = 0.25
    if state then fState = 1.0 end
    sender:setForeColorEx( { r = 1.0, g = 1.0, b = 1.0, a = fState * 1.0  }, "UIO.UIOElements.RSSElement" )
    sender:setForeColorEx( { r = 1.0, g = 1.0, b = 1.0, a = fState * 0.25 }, "UIO.UIOElements.ButtonModule" )
end

if not uioCombinator:setSignalHandler( "Trigger", triggerCallback ) then
    computer.panic( "Unable to set signal handler for UIO.UIOElements.Combinator!" )
end







-- Now the basic loop
while true do
    local edata = { event.pull() }
    UIO.UIOElements:eventHandler( edata )
end