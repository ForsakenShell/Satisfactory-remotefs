---A simple class to control flow of items through codeable merger[s] until the requested item count has been reached
---@class ItemTransferRequest:table
---@field item ItemType Item being requested
---@field mergers array The CodeableMergers used to control item flow
---@field count integer Total number of items to transfer
---@field current integer Current count of items transfered - may be initialized with a positive value representing the current amount it items in the destination
---@field pattern string string.format() pattern used by ItemTransferRequest:status()
local ItemTransferRequest = _G[ "____ItemTransferRequest" ]
if ItemTransferRequest ~= nil then return ItemTransferRequest end


ItemTransferRequest = {
    item = nil,
    mergers = nil,
    count = 0,
    current = 0,
    pattern = "%s: %d/%d",
}
ItemTransferRequest.__index = ItemTransferRequest
_G[ "____ItemTransferRequest" ] = ItemTransferRequest

local ItemTransferRequests = {}
_G[ "____ItemTransferRequests" ] = ItemTransferRequests







---Stop listening for events from the mergers for this request
---@param request ItemTransferRequest
local function stopListeningToMergers( request )
    for _, merger in pairs( request.mergers ) do
        event.ignore( merger )
        ItemTransferRequests[ merger.hash ] = nil
    end
end


---Try and transfer an item in the mergers input to the output
---@param request ItemTransferRequest
---@param merger userdata
---@param input integer
---@param item userdata
---@return boolean Was the item transfered?
local function tryTransferItem( request, merger, input, item )
    if request.current >= request.count then return false end
    
    if item == nil then
        item = merger:getInput( input )
    end
    if item == nil or item.type == nil or item.type ~= request.item then return false end
    
    if not merger:transferItem( input ) then return false end
    
    request.current = request.current + 1
    if request.current >= request.count then
        stopListeningToMergers( request )
    end
    
    return true
end


---Look for an input with the request item and transfer it, triggering the event queue for future transfers
---@param request ItemTransferRequest
---@param merger userdata
---@return boolean Was any item transfered?
function tryPumpMerger( request, merger )
    if request.current >= request.count then return false end
    if merger.canOutput then
        for i = 0, 2 do
            if tryTransferItem( request, merger, i ) then
                return true
            end
        end
    end
    return false
end


---Pump all the mergers for this request.
---@param request ItemTransferRequest
---@return boolean Was any item transfered?
function tryTransferItems( request )
    if request.current >= request.count then return false end
    local result = true
    for _, merger in pairs( request.mergers ) do
        result = result and tryPumpMerger( request, merger )
        if request.current >= request.count then break end
    end
    return result
end








---Create a new ItemTransferRequest; item, count, [current] and, mergers must be valid on entry
---@param o table table to turn into an ItemTransferRequest, setup the event listeners and, pump the mergers
function ItemTransferRequest.new( o )
    if o == nil or type( o ) ~= "table" then
        print( "ItemTransferRequest.new() :: o is nil or not a table" )
        return nil
    end
    if o.item == nil or type( o.item ) ~= "userdata" then
        print( "ItemTransferRequest.new() :: o.item is nil or not userdata" )
        return nil
    end
    if o.count == nil or type( o.count ) ~= "number" or o.count < 1 then
        print( "ItemTransferRequest.new() :: o.count is nil or not a number or less than 1" )
        return nil
    end
    if o.mergers == nil then
        print( "ItemTransferRequest.new() :: o.mergers is nil" )
        return nil
    end
    if type( o.mergers ) ~= "table" then
        print( "ItemTransferRequest.new() :: o.mergers is not a table - " .. type( o.mergers ) )
        return nil
    end
    if #o.mergers < 1 then
        print( "ItemTransferRequest.new() :: o.mergers is empty" )
        return nil
    end
    if o.current ~= nil and( type( o.current ) ~= "number" or o.current < 0 )then
        print( "ItemTransferRequest.new() :: o.current is invalid" )
        return nil
    end
    o.current = o.current or 0
    setmetatable( o, { __index = ItemTransferRequest } )
    
    for _, merger in pairs( o.mergers ) do
        ItemTransferRequests[ merger.hash ] = o
        event.listen( merger )
    end
    
    -- Pump the transfers to trigger event-based handling afterwards
    tryTransferItems( o )
    
    return o
end




---Signal: ItemRequest
---@param merger userdata
---@param input integer
---@param item userdata
---@param return boolean
local function handleSignalItemRequest( merger, input, item )
    if merger == nil then return false end
    if input == nil or type( input ) ~= "number" then return false end
    if item == nil or type( item ) ~= "userdata" then return false end
    
    local request = ItemTransferRequests[ merger.hash ]
    if request == nil then return false end
    
    tryTransferItem( request, merger, input, item )
    return true -- Transfered or not, we still consumed the event
end


---Signal: ItemOutputted
---@param merger userdata
---@param item userdata
---@param return boolean
local function handleSignalItemOutputted( merger, item )
    if merger == nil then return false end
    
    local request = ItemTransferRequests[ merger.hash ]
    if request == nil then return false end
    
    tryPumpMerger( request, merger )
    return true -- Transfered or not, we still consumed the event
end


---ItemTransferRequest dispatcher.  Call this in your main loop.
---@param edata table table {event.pull()}
---@return boolean true, event was handled, false otherwise
function ItemTransferRequest.handleEvent( edata )
    if edata == nil or edata[ 1 ] == nil then return false end
    
    local signal = edata[ 1 ]
    
    if signal == "ItemRequest" then
        return handleSignalItemRequest( edata[ 2 ], edata[ 3 ], edata[ 4 ] )
    end
    
    if signal == "ItemOutputted" then
        return handleSignalItemOutputted( edata[ 2 ], edata[ 3 ] )
    end
    
    return false    -- Unknown signal
end




---Return a patterned string with the item name, current and count; override this if you want something more/else
function ItemTransferRequest:status()
    return string.format( self.pattern, self.item.name, self.current, self.count )
end


---Is the request complete?  curremt >= count
function ItemTransferRequest:isComplete()
    return self.current >= self.count
end




return ItemTransferRequest