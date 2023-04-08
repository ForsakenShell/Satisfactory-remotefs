-- Datum holding information about a production machine of some kind
local MachineDatum = _G[ "____MachineDatum" ]
if MachineDatum ~= nil then return MachineDatum end




----------------------------------------------------------------

--local ClassGroup                = require( "/lib/classgroups.lua", EEPROM.Remote.CommonLib )
local _Collimator               = require( "/lib/Collimator.lua", EEPROM.Remote.CommonLib )
local _Column                   = _Collimator.Column
local Color                     = require( "/lib/Colors.lua", EEPROM.Remote.CommonLib )
--local utf8                      = require( "/lib/utf8.lua", EEPROM.Remote.CommonLib )
local ItemDatum                 = require( "/lib/ItemDatum.lua", EEPROM.Remote.CommonLib )


-- Internal magic numbers
local __MT_INVALID              = 0
local __MT_MANUFACTURER         = 1
local __MT_EXTRACTOR            = 2


-- More internal magic
local __TYPE_MANUFACTURER       = findClass( "Manufacturer" )
local __TYPE_EXTRACTOR          = findClass( "FGBuildableResourceExtractorBase" )



----------------------------------------------------------------

local MachineDatum = {
    machine = nil,
    mt = __MT_INVALID,
    cycleTime = 0.0,
    potential = 0.0,
    progress = 0.0,
    __lastProgress = 0.0,
    productivity = 0.0,
    currentPowerConsumption = 0.0,
}
MachineDatum.__index = MachineDatum
_G[ "____MachineDatum" ] = MachineDatum




----------------------------------------------------------------

MachineDatum.MT_INVALID         = __MT_INVALID
MachineDatum.MT_MANUFACTURER    = __MT_MANUFACTURER
MachineDatum.MT_EXTRACTOR       = __MT_EXTRACTOR




----------------------------------------------------------------

local cWhite                    = Color.WHITE
local cBlack                    = Color.BLACK
local cRed                      = Color.new( 1.0, 0.0, 0.0, 1.0 )
local cYellow                   = Color.new( 1.0, 1.0, 0.0, 1.0 )
local cGreen                    = Color.new( 0.0, 1.0, 0.0, 1.0 )

local PowerShard                = findItem( "Power Shard" )
local PotentialSlots            = {
    ItemDatum.new( PowerShard, 1 ),
    ItemDatum.new( PowerShard, 1 ),
    ItemDatum.new( PowerShard, 1 ),
}
local PotentialSlotUnused       = Color.GREY_0125

local INV_STATUS     = { "○", "◒", "●" } -- { "\u{25CB}", "\u{25D2}", "\u{25CF}" } -- empty circle, half full circle, full circle
local ACT_STATUS_OFF = "☼" -- "\u{263C}" -- Sun With Rays
local ACT_STATUS_ON = { "", "", "", "", "", "" } -- { "\u{EE06}", "\u{EE07}", "\u{EE08}", "\u{EE09}", "\u{EE0A}", "\u{EE0B}" } -- Spiny circle


----------------------------------------------------------------

local function getInvStackStatus( sIdx, stkCount, refAmount, inventory, stackSize, potential )
    local t = nil
    local c = nil
    if inventory == component.INV_INPUT then
        
        local warnAmount = refAmount * 2
        if stkCount < refAmount then
            if stkCount == 0 then
                t = INV_STATUS[ 1 ]
            else
                t = INV_STATUS[ 2 ]
            end
            c = cRed
        elseif stkCount < warnAmount then
            t = INV_STATUS[ 2 ]
            c = cYellow
        else
            if stkCount < stackSize then
                t = INV_STATUS[ 2 ]
            else
                t = INV_STATUS[ 3 ]
            end
            c = cGreen
        end
        
    elseif inventory == component.INV_OUTPUT then
        
        local warnAmount = math.max( 0, stackSize - refAmount * 2 )
        refAmount = math.max( 0, stackSize - refAmount )
        
        if stkCount > refAmount then
            if stkCount < stackSize then
                t = INV_STATUS[ 2 ]
            else
                t = INV_STATUS[ 3 ]
            end
            c = cRed
        elseif stkCount > warnAmount then
            t = INV_STATUS[ 2 ]
            c = cYellow
        else
            if stkCount == 0 then
                t = INV_STATUS[ 1 ]
            else
                t = INV_STATUS[ 2 ]
            end
            c = cGreen
        end
        
    elseif inventory == component.INV_POTENTIAL then
        
        -- Either is has a shard or it doesn't
        if stkCount > 0 then
            t = INV_STATUS[ 3 ] -- full
        else
            t = INV_STATUS[ 1 ] -- empty
        end
        
        -- Color depends on whether it's required
        if( sIdx == 0 and potential > 1.0 )
        or( sIdx == 1 and potential > 1.5 )
        or( sIdx == 2 and potential > 2.0 )then
            c = cGreen
        else
            c = PotentialSlotUnused
        end
        
    end
    
    return t, c
end




----------------------------------------------------------------

function MachineDatum.GetMachineType( machine )
    if machine == nil or type( machine ) ~= "userdata" or machine[ "getType" ] == nil then return __MT_INVALID end
    local ct = machine:getType()
    if ct:isChildOf( __TYPE_MANUFACTURER ) then
        return __MT_MANUFACTURER
    elseif ct:isChildOf( __TYPE_EXTRACTOR ) then
        return __MT_EXTRACTOR
    end
    return __MT_INVALID
end

function MachineDatum.new( machine )
    local mt = MachineDatum.GetMachineType( machine )
    if mt == __MT_INVALID then
        return nil, "machine type is invalid; must be a child class of Manufacturer or FGBuildableResourceExtractorBase"
    end
    
    local datum = {}
    datum.machine = machine
    datum.mt = mt
    datum.progress = machine.progress
    setmetatable( datum, { __index = MachineDatum } )
    datum:update()
    
    return datum
end


----------------------------------------------------------------

function MachineDatum:update()
    local machine = self.machine
    self.cycleTime = machine.cycleTime
    self.potential = machine.potential
    self.__lastProgress = self.progress
    self.progress = machine.progress
    self.productivity = machine.productivity
    self.currentPowerConsumption = machine.powerConsumProducing or 0.0
    if machine.standby or self.__lastProgress == self.progress then
        self.currentPowerConsumption = 0
    end
end




----------------------------------------------------------------

-- Get the inventory "status" of a specific stack; refItems must be appropriate for the inventory being checked.
function MachineDatum:getInventoryStackStatus( inventory, stack, refItems )
    if inventory == nil or type( inventory ) ~= "string" or inventory == '' then
        --panic( debug.traceback( "bad inventory", 2 ) )
        return nil, nil, nil, nil end
    if stack == nil or type( stack ) ~= "number" or stack < 0 then
        --panic( debug.traceback( "bad stack", 2 ) )
        return nil, nil, nil, nil end
    if refItems == nil or type( refItems ) ~= "table" or #refItems == 0 then
        --panic( debug.traceback( "bad refItems", 2 ) )
        return nil, nil, nil, nil end
    
    if  inventory ~= component.INV_INPUT
    and inventory ~= component.INV_OUTPUT
    and inventory ~= component.INV_POTENTIAL then
        --panic( debug.traceback( "really bad inventory", 2 ) )
        return nil, nil, nil, nil
    end
    
    if refItems ~= nil and stack >= #refItems then
        --panic( debug.traceback( "refItems", 2 ) )
        return nil, nil, nil, nil end
    
    local machine = self.machine
    local inv = component.getInventoryByName( machine, inventory )
    if inv == nil then
        --panic( debug.traceback( "can't get inventory", 2 ) )
        return nil, nil, nil, nil end
    local stk = inv:getStack( stack )
    if stk == nil then
        panic( debug.traceback( "can't get stack", 2 ) )
        return nil, nil, nil, nil end
    
    local refItem = refItems[ 1 + stack ] -- refItems is 1, ...; getStack() is 0, ...
    local refAmount = refItem.amount
    local stkCount = stk.count
    local t, c = getInvStackStatus( stack, stkCount, refAmount, inventory, refItem.stackSize, self.potential )
    
    return t, c, nil, 1
end


-- Get the "status" for all expected item stacks in the inventory; refItems must be appropriate for the inventory being checked.
local ____MD_invStatus = {}
function MachineDatum:getInventoryStatus( inventory, refItems )
    if inventory == nil or type( inventory ) ~= "string" or inventory == '' then
        --panic( debug.traceback( "bad inventory", 2 ) )
        return nil, nil, nil, nil end
    if refItems == nil or type( refItems ) ~= "table" or #refItems == 0 then
        --panic( debug.traceback( "bad refItems", 2 ) )
        return nil, nil, nil, nil end
    
    if  inventory ~= component.INV_INPUT
    and inventory ~= component.INV_OUTPUT
    and inventory ~= component.INV_POTENTIAL then
        --panic( debug.traceback( "really bad inventory", 2 ) )
        return nil, nil, nil, nil
    end
    
    if refItems == nil or #refItems == 0 then
        --panic( debug.traceback( "refItems", 2 ) )
        return nil, nil, nil, nil end
    
    local machine = self.machine
    local inv = component.getInventoryByName( machine, inventory )
    if inv == nil then
        --panic( debug.traceback( "can't get inventory", 2 ) )
        return nil, nil, nil, nil end
    
    local mdis = ____MD_invStatus[ inventory ]
    if mdis == nil then
        mdis = {
            t = {},
            c = {},
        }
        ____MD_invStatus[ inventory ] = mdis
    end
    local t = mdis.t
    local c = mdis.c
    
    local refAmount
    local stkCount
    
    for iIdx, item in pairs( refItems ) do
        local sIdx = iIdx - 1 -- refItems is 1, ...; getStack() is 0, ...
        local stack = inv:getStack( sIdx )
        if stack == nil then
            --panic( debug.traceback( "can't get stack " .. tostring( sIdx ), 2 ) )
            return nil, nil, nil, nil end
        
        refAmount = item.amount
        stkCount = stack.count
        
        local st, sc = getInvStackStatus( sIdx, stkCount, refAmount, inventory, item.stackSize, self.potential )
        t[ iIdx ] = st
        c[ iIdx ] = sc
    end
    
    return t, c, nil, 1
    
end




----------------------------------------------------------------

local Collimator = {}
Collimator.__index = Collimator
MachineDatum.Collimator = Collimator

function Collimator.new( machineType, outputItems, inputItems, maxWidth, baseProductionTime, drawText )
    if machineType == nil or type( machineType ) ~= "number"
    or( machineType ~= __MT_MANUFACTURER and machineType ~= __MT_EXTRACTOR )then return nil, "machineType is invalid" end
    
    if outputItems == nil or type( outputItems ) ~= "table" or #outputItems == 0 then return nil, "outputItems is invalid" end
    for i, o in pairs( outputItems ) do
        if not ItemDatum.isItemDatum( o ) then return nil, "outputItems[ " .. tostring( i ) .. " ] is invalid" end
    end
    
    if machineType == __MT_MANUFACTURER then
        if( inputItems == nil or type( inputItems ) ~= "table" or #inputItems == 0 )then return nil, "inputItems is invalid" end
        for i, o in pairs( inputItems ) do
            if not ItemDatum.isItemDatum( o ) then return nil, "inputItems[ " .. tostring( i ) .. " ] is invalid" end
        end
    end
    
    if machineType == __MT_EXTRACTOR and
    ( inputItems ~= nil )then return nil, "inputItems is invalid" end
    
    if maxWidth == nil or type( maxWidth ) ~= "number" or maxWidth < 1 then return nil, "maxWidth is invalid" end
    if baseProductionTime == nil or type( baseProductionTime ) ~= "number" or baseProductionTime <= 0.0 then return nil, "baseProductionTime is invalid, must be greater than 0.0" end
    if drawText ~= nil and type( drawText ) ~= "function" then return nil, "drawText is invalid" end
    
    -- Collimator Column Resolvers
    
    local __MD_cc__d = { '', '' }
    local __MD_cc__f = { cWhite, cWhite }
    local __MD_cc__l = { 4, 1 }
    local function MD_Collimate_Cycle( md )
        local pd = ACT_STATUS_OFF
        local pf = cRed
        if md.currentPowerConsumption > 0 then
            -- Individual status indicator indexes, so they don't do weird jumps on the display
            local npsc = md.__MD_Column_StatusChar or 1
            pd = ACT_STATUS_ON[ npsc ]
            npsc = npsc + 1
            if npsc > #ACT_STATUS_ON then npsc = 1 end
            md.__MD_Column_StatusChar = npsc
            pf = cGreen
        end
        __MD_cc__d[ 1 ] = string.format( "%3.0f%%", md.progress * 100.0 )
        __MD_cc__d[ 2 ] = pd
        __MD_cc__f[ 2 ] = pf
        return __MD_cc__d, __MD_cc__f, nil, __MD_cc__l
    end
    
    local function MD_Collimate_Prod( md )
        local d = string.format( "%3.0f%%", md.productivity * 100.0 )
        return d, cWhite, nil, 4 -- #d
    end
    
    local __MD_cs__d = { '', '' }
    local __MD_cs__f = { cWhite, cWhite }
    local __MD_cs__l = { 13, 0 }
    local function MD_Collimate_Speed( md )
        local sd, sf, sb, sl = md:getInventoryStatus( component.INV_POTENTIAL, PotentialSlots )
        --if sd == nil or #sd == 0 then panic( "shit sun" ) end
        
        __MD_cs__d[ 1 ] = string.format( "%6.2fs %3.0f%%", baseProductionTime / md.potential, md.potential * 100.0 )
        __MD_cs__d[ 2 ] = sd
        __MD_cs__f[ 2 ] = sf
        __MD_cs__l[ 2 ] = sl
        
        return __MD_cs__d, __MD_cs__f, nil, __MD_cs__l
    end
    
    local function MD_Collimate_Inputs( md )
        local d, f, b, l = md:getInventoryStatus( component.INV_INPUT, inputItems )
        return d, f, nil, l
    end
    
    
    local __MD_co__d = { '', '' }
    local __MD_co__f = { cWhite, cWhite }
    local __MD_co__l = { 0, 0 }
    local function MD_Collimate_Output( md, index )
        local item = outputItems[ index ]
        local od, of, ob, ol = md:getInventoryStackStatus( component.INV_OUTPUT, index - 1, outputItems )
        local output = item.amount * ( 60 / md.cycleTime ) * md.productivity
        __MD_co__d[ 1 ] = string.format( item.pattern, output )
        __MD_co__d[ 2 ] = od
        __MD_co__f[ 2 ] = of
        __MD_co__l[ 1 ] = item.patternLen
        __MD_co__l[ 2 ] = ol
        return __MD_co__d, __MD_co__f, nil, __MD_co__l
    end
    
    local function MD_Collimate_Primary( md )
        local d, f, b, l = MD_Collimate_Output( md, 1 )
        return d, f, nil, l
    end
    
    local function MD_Collimate_Secondary( md )
        local d, f, b, l = MD_Collimate_Output( md, 2 )
        return d, f, nil, l
    end
    
    
    -- Create the columns
    local c = {}
    c[ #c + 1 ] = _Column.new( { header = 'Cycle'       , width =  6, resolver = MD_Collimate_Cycle     } )
    c[ #c + 1 ] = _Column.new( { header = 'Productivity', width =  4, resolver = MD_Collimate_Prod      } )
    c[ #c + 1 ] = _Column.new( { header = 'Speed'       , width = 16, resolver = MD_Collimate_Speed, sep = '' } )
    if machineType == __MT_MANUFACTURER then            -- width =  1 .. 4
        c[ #c + 1 ] = _Column.new( { header = 'Inputs'  , width =  #inputItems, resolver = MD_Collimate_Inputs, sep = '' } )
    end
    
    -- total width of table to this point
    local total = 0
    for i = 1, #c do
        total = total + c[ i ].width
    end
    
    -- divide the remaining area between the outputs
    local nout = #outputItems
    local remaining = maxWidth - total -- - nout -- account for padding
    if remaining < nout then return nil, "maxWidth is too small - " .. tostring( maxWidth ) end
    local outMax = math.floor( remaining / nout )
    
    function createOutputColumn( index, resolver )
        if index > nout then return end
        local item = outputItems[ index ]
        local name = item.name
        local nameLen = item.nameLen
        local maxOutput = item.amount * ( 60 / baseProductionTime ) * 2.5    -- Maximum possible output of product
        local w = 3                 -- decimal + two places
        while maxOutput > 1.0 do    -- add every whole number digit
            w = w + 1
            maxOutput = maxOutput / 10.0
        end
        item.pattern = string.format( "%%%d.2f %s/m", w, item.units )
        w = w + 3 + item.unitsLen   -- Pattern + space + units
        item.patternLen = w
        local outMin = w + 2        -- + space + status indicator
        local cWid = math.min( outMax, math.max( outMin, nameLen ) )   -- prefered item name length
        c[ #c + 1 ] = _Column.new( { header = name, width = cWid, resolver = resolver } )
        remaining = remaining - cWid
    end
    -- Create output columns
    createOutputColumn( 1, MD_Collimate_Primary )
    createOutputColumn( 2, MD_Collimate_Secondary )
    
    -- Set the table padding based on the remaining screen space
    local padding = 1 + math.floor( remaining / #c )
    
    -- Add the remaining space to the columns
    -- Don't do this, it looks like trash, use the padding method above
    --remaining = math.floor( remaining / #c )
    --for i = 1, #c do
    --    local v = c[ i ].width
    --    c[ i ].width = v + remaining
    --    c[ i ]:update()
    --end
    
    local result, reason = _Collimator.new( {
        columns     = c,
        padding     = padding,
        drawText    = drawText,
    })
    if result == nil then
        computer.panic( reason )
    end
    
    return result
end






----------------------------------------------------------------

return MachineDatum