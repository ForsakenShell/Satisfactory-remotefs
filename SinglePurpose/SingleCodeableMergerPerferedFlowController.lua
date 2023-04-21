-- Settings:

--   EEPROM boot:
--     remotefs="SinglePurpose"
--     bootloader="SingleCodeableMergerPerferedFlowController.lua"

--   System Control:
--     order="a,b,c"        required, a, b and, c are the inputs of the merger in the order they are prefered (a is tried before b is tried before c); 0 = right, 1 = middle, 2 = left
--     beltspeed="integer"  optional, default: 780

-- This is mainly useful for recycling coal at a power station before letting
-- new coal in to the belt feed so no coal gets "jammed" when using mods like
-- Loaders and Unloaders.


local noOrder = "No 'order' setting for merger preference, must be an array of inputs in preference order, eg: order=\"1,2,0\"\n\t0 = right\n\t1 = middle\n\t2 = left"
local badOrder = "'order' setting is invalid, must be an array of inputs in preference order, eg: order=\"1,2,0\"\n\t0 = right\n\t1 = middle\n\t2 = left"

local beltspeed = tonumber( EEPROM.Boot.ComputerSettings[ "beltspeed" ] ) or 780

local tmp = EEPROM.Boot.ComputerSettings[ "order" ]

if tmp == nil then computer.panic( noOrder ) end
local order = string.split( tmp )
if order == nil or #order == 0 then computer.panic( badOrder ) end
for index = 1, #order do
    local v = order[ index ]
    if v == nil or tonumber( v ) == nil then computer.panic( badOrder ) end
    local o = tonumber( v )
    if o < 0 or o > 2 then computer.panic( badOrder ) end
    order[ index ] = o
end

local merger = component.proxy( component.findComponent( findClass( "CodeableMerger" ) )[ 1 ] )

function getInputName( index )
    if index == nil or type( index ) ~= "number" then return "invalid" end
    if index == 0 then return "right" end
    if index == 1 then return "middle" end
    if index == 2 then return "left" end
    return "invalid"
end

function getPreferedInputItem( order )
    local o, item
    
    for index = 1, #order do
        o = order[ index ]
        item = merger:getInput( o )
        if item ~= nil and item.type ~= nil then return o, item.type end
    end
    
    return nil, nil
end

event.clear()
event.listen( merger )

local eventWait = 1 / ( beltspeed / 60 )
print( "Belt speed: ", beltspeed, ' -> ', eventWait, "s" )
print( "Input preference order:" )
for index = 1, #order do
    local o = order[ index ]
    print( "\t", o, getInputName( o ) )
end


while true do
    local e, s = event.pull( eventWait )
    
    if merger.canOutput then
        local index, item = getPreferedInputItem( order )
        if index ~= nil then
            local retry = 0
            while retry < 10 and not merger:transferItem( index ) do
                retry = retry + 1
            end
            if retry >= 10 then
                print( "timed out on input ", getInputName( index ) )
            end
        end
    end
    
end
