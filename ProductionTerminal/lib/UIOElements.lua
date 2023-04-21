local UIO = require( "/UIO/UIO.lua", EEPROM.Remote.CommonLib )

require( "/UIO/UIOElements/Combinator.lua", EEPROM.Remote.CommonLib )
require( "/UIO/UIOElements/ButtonModule.lua", EEPROM.Remote.CommonLib )
require( "/UIO/UIOElements/RSSElement.lua", EEPROM.Remote.CommonLib )
require( "/UIO/UIOElements/PotentiometerComplexModule.lua", EEPROM.Remote.CommonLib )
require( "/UIO/UIOElements/Extensions.lua", EEPROM.Remote.CommonLib )


---Create a Bool State combinator for buttons at the same position on multiple panels
---@param panels table The ModulePanels holding the Button Modules
---@param position array The [x,y] position of the Button Module on a panel
---@param handler function Handler for the "Trigger" signal
---@param ctrue? Color Color for the Button Module "true" state
---@param cfalse? Color Color for the Button Module "false" state
---@param skipMissingButtonOnPanel? boolean Just ignore a missing button (true) or panic the computer (default: false)
function UIO.createBoolButtonCombinator( panels, position, handler, ctrue, cfalse, skipMissingButtonOnPanel )
    if panels == nil or #panels == 0 then return nil end
    if skipMissingButtonOnPanel == nil or type( skipMissingButtonOnPanel ) ~= "boolean" then skipMissingButtonOnPanel = false end
    
    local combined = {}
    
    for _, panel in pairs( panels ) do
        local button = panel:getModule( position[ 1 ], position[ 2 ] )
        if button == nil then
            if not skipMissingButtonOnPanel then
                computer.panic( debug.traceback( string.format( "Cannot find button\n\tPosition = { %d, %d }\n\tPanel = %2", position[ 1 ], position[ 2 ], panel.id ), 2 ) )
            end
        else
            local uio = UIO.UIOElements.ButtonModule.create( button )
            if uio == nil then
                computer.panic( debug.traceback( string.format( "Cannot create UIO.Button for button\n\tPosition = { %d, %d }\n\tPanel = %2", position[ 1 ], position[ 2 ], panel.id ), 2 ) )
            end
            UIO.UIOElement.Extensions.AddBoolStateColours( uio, ctrue, cfalse )
            table.insert( combined, uio )
        end
    end
    
    --print( tostring( #combined ) .. " UIOElements to be combined!\n" .. debug.traceback() )
    
    local combinator = UIO.UIOElements.Combinator.create( combined )
    if combinator == nil then
        computer.panic( debug.traceback( "Cannot create UIO.Combinator" , 2 ) )
    end
    UIO.UIOElement.Extensions.AddBoolStateControl( combinator )
    UIO.UIOElement.Extensions.AddSignalBlockControl( combinator )
    
    if not combinator:setSignalHandler( "Trigger", handler ) then
        computer.panic( debug.traceback( "Could not register for 'Trigger' signal" , 2 ) )
    end
    
    return combinator
end

---Create an Int State combinator for buttons at the same position on multiple panels
---@param panels table The ModulePanels holding the Button Modules
---@param position array The [x,y] position of the Button Module on a panel
---@param handler function Handler for the "Trigger" signal
---@param states array Array of Colors for the Button Module state
---@param skipMissingButtonOnPanel? boolean Just ignore a missing button (true) or panic the computer (default: false)
function UIO.createIntButtonCombinator( panels, position, handler, states, skipMissingButtonOnPanel )
    if panels == nil or #panels == 0 then return nil end
    if skipMissingButtonOnPanel == nil or type( skipMissingButtonOnPanel ) ~= "boolean" then skipMissingButtonOnPanel = false end
    
    local combined = {}
    
    for _, panel in pairs( panels ) do
        local button = panel:getModule( position[ 1 ], position[ 2 ] )
        if button == nil then
            if not skipMissingButtonOnPanel then
                computer.panic( debug.traceback( string.format( "Cannot find button\n\tPosition = { %d, %d }\n\tPanel = %2", position[ 1 ], position[ 2 ], panel.id ), 2 ) )
            end
        else
            local uio = UIO.UIOElements.ButtonModule.create( button )
            if uio == nil then
                computer.panic( debug.traceback( string.format( "Cannot create UIO.Button for button\n\tPosition = { %d, %d }\n\tPanel = %2", position[ 1 ], position[ 2 ], panel.id ), 2 ) )
            end
            UIO.UIOElement.Extensions.AddIntStateColours( uio, states )
            table.insert( combined, uio )
        end
    end
    
    --print( tostring( #combined ) .. " UIOElements to be combined!\n" .. debug.traceback() )
    
    local combinator = UIO.UIOElements.Combinator.create( combined )
    if combinator == nil then
        computer.panic( debug.traceback( "Cannot create UIO.Combinator" , 2 ) )
    end
    UIO.UIOElement.Extensions.AddIntStateControl( combinator )
    UIO.UIOElement.Extensions.AddSignalBlockControl( combinator )
    
    if not combinator:setSignalHandler( "Trigger", handler ) then
        computer.panic( debug.traceback( "Could not register for 'Trigger' signal" , 2 ) )
    end
    
    return combinator
end

---Create a combinator for potentiometers at the same position on multiple panels
---@param panels table The ModulePanels holding the Potentiometer Modules
---@param position array The [x,y] position of the Potentiometer Module on a panel
---@param handler function Handler for the "valueChanged" signal
---@param skipMissingPotentiometerOnPanel? boolean Just ignore a missing potentiometer (true) or panic the computer (default: false)
function UIO.createPotentiometerCombinator( panels, position, handler, value, min, max, skipMissingPotentiometerOnPanel )
    if panels == nil or #panels == 0 then return nil end
    if skipMissingPotentiometerOnPanel == nil or type( skipMissingPotentiometerOnPanel ) ~= "boolean" then skipMissingPotentiometerOnPanel = false end
    
    local combined = {}
    
    for _, panel in pairs( panels ) do
        local potentiometer = panel:getModule( position[ 1 ], position[ 2 ] )
        if potentiometer == nil then
            if not skipMissingPotentiometerOnPanel then
                computer.panic( debug.traceback( string.format( "Cannot find potentiometer\n\tPosition = { %d, %d }\n\tPanel = %2", position[ 1 ], position[ 2 ], panel.id ), 2 ) )
            end
        else
            local uio = UIO.UIOElements.PotentiometerComplexModule.create( potentiometer )
            if uio == nil then
                computer.panic( debug.traceback( string.format( "Cannot create UIO.Potentiometer for potentiometer\n\tPosition = { %d, %d }\n\tPanel = %2", position[ 1 ], position[ 2 ], panel.id ), 2 ) )
            end
            uio:setValue( value )
            uio:setMin( min )
            uio:setMax( max )
            table.insert( combined, uio )
        end
    end
    
    --print( tostring( #combined ) .. " UIOElements to be combined!\n" .. debug.traceback() )
    
    local combinator = UIO.UIOElements.Combinator.create( combined )
    if combinator == nil then
        computer.panic( debug.traceback( "Cannot create UIO.Combinator" , 2 ) )
    end
    
    if not combinator:setSignalHandler( "valueChanged", handler ) then
        computer.panic( debug.traceback( "Could not register for 'valueChanged' signal" , 2 ) )
    end
    
    return combinator
end




return UIO