-- Datum holding information about an item


local ItemDatum = _G[ "____ItemDatum" ]
if ItemDatum ~= nil then return ItemDatum end




local utf8                      = require( "/lib/utf8.lua", EEPROM.Remote.CommonLib )




-- Internal magic strings
local __Item            = "Item-Struct"
local __ItemType        = "ItemType-Class"
local __ItemAmount      = "ItemAmount-Struct"
local __ItemStack       = "ItemStack-Struct"




-- Internal magic numbers
--local __FORM_INVALID    = 0
local __FORM_SOLID      = 1
local __FORM_LIQUID     = 2
local __FORM_GAS        = 3
local __FORM_HEAT       = 4



local ItemDatum = {
    item = nil,         -- The ItemType-Class
    name = '',          -- The unicode string display name of the item
    nameLen = 0,        -- The length of the name unicode string, determined once when the ItemDatum is new()
    form = 0,           -- The item.form
    isFluid = false,    -- Quick test of item.form
    units = '',         -- The unicode string display units for the item
    unitsLen = 0,       -- The length of the units unicode string, determined once when the ItemDatum is new()
    stackSize = 0,
    amount = 0,
}
ItemDatum.__index = ItemDatum
_G[ "____ItemDatum" ]   = ItemDatum




-- Common static values
ItemDatum.FORM_SOLID    = __FORM_SOLID
ItemDatum.FORM_LIQUID   = __FORM_LIQUID
ItemDatum.FORM_GAS      = __FORM_GAS
ItemDatum.FORM_HEAT     = __FORM_HEAT


-- Common helper functions

function ItemDatum.itemIsSolid( item )
    if item == nil or tostring( item ) ~= __ItemType then return false end
    local form = item.form
    return ( form == __FORM_SOLID )
end

function ItemDatum.itemIsFluid( item )
    if item == nil or tostring( item ) ~= __ItemType then return false end
    local form = item.form
    return ( form == __FORM_LIQUID )or( form == __FORM_GAS ) -- Liquids and Gasses are both Fluids
end

function ItemDatum.itemIsTemperature( item )
    if item == nil or tostring( item ) ~= __ItemType then return false end
    local form = item.form
    return ( form == __FORM_HEAT )
end

function ItemDatum.unitsByForm( form )
    if form == nil or type( form ) ~= "number" then return nil, nil end
    if form == __FORM_SOLID then
        return "p", 1
    end
    if form == __FORM_LIQUID
    or form == __FORM_GAS then
        return "m³", 2
    end
    if form == __FORM_HEAT then   -- TODO:  Revisit this, just guessing for now
        return "C", 1
    end
    return nil, nil
end

function ItemDatum.itemUnits( item )
    if item == nil or tostring( item ) ~= __ItemType then return nil, nil end
    return ItemDatum.unitsByForm( item.form )
end



---Is the specified object an ItemDatum?
function ItemDatum.isItemDatum( o )
    if o == nil or type( o ) ~= "table" then return false end
    local mt = getmetatable( o )
    return mt ~= nil
    and mt.__index == ItemDatum
end



---Creates an ItemDatum from an ItemType, ItemAmount or, ItemStack.  ItemType and ItemStack must pass a valid amount parameter, amount will be taken directly from ItemAmount.
---@param item any Item-Struct, ItemType-Class, ItemAmount-Struct or, ItemStack-Struct
---@param amount? integer The amount for this ItemDatum; since this is only meaningful to usercode this value can be anything.  For recipes this could be the ingredient or output amount, for example.
function ItemDatum.new( item, amount )
    if item == nil then return nil, "item is nil" end
    
    local _item = nil
    local _amount = nil
    local it = tostring( item )
    if it == __Item then
        _item = item.type
        _amount = amount
    end
    if it == __ItemType then
        _item = item
        _amount = amount
    end
    if it == __ItemAmount then
        _item = item.type
        _amount = item.amount
    end
    if it == __ItemStack then
        _item = item.item
        _amount = amount
    end
    if _item == nil then return nil, "item type could not be resolved - " .. it end
    if _amount  == nil then return nil, "amount is invalid" end
    
    local name = _item.name
    local units, unitsLen = ItemDatum.unitsByForm( _item.form )
    
    local isFluid = ItemDatum.itemIsFluid( _item )
    if isFluid then
        _amount = _amount / 1000.0
    end
    
    local datum = {
        item = _item,
        name = name,
        nameLen = utf8.len( name ),
        form = _item.form,
        isFluid = isFluid,
        units = units,
        unitsLen = unitsLen,
        stackSize = _item.max,
        amount = _amount,
    }
    setmetatable( datum, { __index = ItemDatum } )
    
    return datum
end



---Create an array of ItemDatums from ItemAmounts
function ItemDatum.FromItemAmounts( itemamounts )
    if itemamounts == nil or #itemamounts == 0 then return nil end
    
    local results = {}
    
    for i, itemamount in ipairs( itemamounts ) do
        local result, reason = ItemDatum.new( itemamount )
        if result == nil then computer.panic( reason ) end
        results[ i ] = result
    end
    
    return results
end


return ItemDatum