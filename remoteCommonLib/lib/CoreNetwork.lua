if _G[ "____CoreNetwork" ] ~= nil then return _G[ "____CoreNetwork" ] end

---------------------------------
-- Core Network Package

local CoreNetwork                       = {}
CoreNetwork.__PacketHandlers            = {}
CoreNetwork.__PacketID                  = "npid"
CoreNetwork.__PacketData                = "json"
CoreNetwork.__PacketEncloseDataChar     = '\a'     -- Extended chars will not transmit properly, use the single bell character as it will encode just fine and shouldn't? be used in actual data
CoreNetwork.__PacketDataTokenizePattern = string.format( "(%%w+)=(%%b%s%s)", CoreNetwork.__PacketEncloseDataChar, CoreNetwork.__PacketEncloseDataChar )
CoreNetwork.__PacketDataHeadPattern     = string.format( "%%s=%s%%s%s", CoreNetwork.__PacketEncloseDataChar, CoreNetwork.__PacketEncloseDataChar )
CoreNetwork.__PacketDataPattern         = string.format( "%%s %%s=%s%%s%s", CoreNetwork.__PacketEncloseDataChar, CoreNetwork.__PacketEncloseDataChar )
CoreNetwork.__json                      = require( "/lib/json.lua", ____RemoteCommonLib )

CoreNetwork.__index = CoreNetwork
_G[ "____CoreNetwork" ] = CoreNetwork




---Register a packet event handler
---@param port integer: The port the packet must be received on
---@param packet_id integer: The packet_id on the port
---@param handler function: handler = function( net, sender, payload )
--- net userdata: NetworkCard (PCI Device) the packet was received on.
--- sender string: Remote NetworkCard UUID that sent the packet on the port.
--- payload table: Contains the packet payload as sent from the source
---@return boolean
function CoreNetwork.registerPacketHandler( port, packet_id, handler )
    if port == nil or type( port ) ~= "number" then return false end
    if packet_id == nil or type( packet_id ) ~= "number" then return false end
    if handler == nil or type( handler ) ~= "function" then return false end
    
    local packetHandler = CoreNetwork.__PacketHandlers[ port ] or {}
    packetHandler[ packet_id ] = handler
    CoreNetwork.__PacketHandlers[ port ] = packetHandler
    
    return true
end


---NetworkMessage dispatcher; calls the appropriate handler for the packet on the port.  Call this in your main loop.
---@param edata table: {event.pull()}
---@return boolean: true, event was handled, false otherwise
function CoreNetwork.handleEvent( edata )
    if edata == nil or edata[ 1 ] == nil or edata[ 1 ] ~= "NetworkMessage" then return false end
    
    local net    = edata[ 2 ]   -- NetworkCard UUID the packet was received with
    local sender = edata[ 3 ]   -- Remote NetworkCard UUID that sent the packet
    local port   = edata[ 4 ]   -- CoreNetwork port the packet was received on
    local packet = edata[ 5 ]   -- Encoded packet
    
    --Allow self talk and make it the packet handlers responsibility about what to do with it
    --if sender == net then return true end -- Don't talk to ourselves
    
    -- Get the table of packet handlers for the port
    local packetHandler = CoreNetwork.__PacketHandlers[ port ]
    if packetHandler == nil then return false end
    
    -- Decode the packet into it's packet_id and data payload
    local packet_id, payload = CoreNetwork.decodePacket( packet )
    if packet_id == nil or type( packet_id ) ~= "number" then return false end
    
    -- Get the packet handler for the packet_id
    local handler = packetHandler[ packet_id ]
    if handler == nil then return false end
    
    -- Handle it
    return handler( net, sender, payload )
end


---Register for event handling with the given NetworkCard (PCI Device).  Call this in your init function once you've gotten the NetworkCards in the computer.
---@param net userdata: NetworkCard (PCI Device) to add to the event system
function CoreNetwork.listenForNetworkEventsOn( net )
    event.listen( net )
    for port, packetHandlers in pairs( CoreNetwork.__PacketHandlers ) do
        net:open( port )
    end
end








---------------------------------
-- NetworkMessage packet encode and decoder

---Encode the packet_id and serialize the data payload into a json string that can be sent to another computer using the FicsitNetwork API
---@param id integer PACKET_ID being sent
---@param payload table? The payload of the packet.  This is serialized to json for transmission
---@return string: id and data packed into a string ready to be sent or broadcast on a NetworkCard
function CoreNetwork.encodePacket( id, payload )
    local packet = string.format( CoreNetwork.__PacketDataHeadPattern, CoreNetwork.__PacketID, id )
    if payload ~= nil and type( payload ) == "table" then
        packet = string.format( CoreNetwork.__PacketDataPattern, packet, CoreNetwork.__PacketData, CoreNetwork.__json.encode( payload ) )
    end
    return packet
end


---Decode the raw packet string received on the NetworkCard into the packet_id and deserialized json into the data payload
---@param packet string encoded packet to rebuild the id and payload from
---@return integer packet_id
---@return table data payload
function CoreNetwork.decodePacket( packet )
    local packet_id = -1
    local payload = nil
    local pdata = {}
    for key, value in string.gmatch( packet, CoreNetwork.__PacketDataTokenizePattern ) do
        local trimmed = string.sub( value, 2, string.len( value ) - 1 ) -- Strip the data encapsulation characters
        pdata[ key ] = trimmed
    end
    local pid = pdata[ CoreNetwork.__PacketID ]
    if pid == nil then
        computer.panic( "decodePacket() - bad packet - no '" .. CoreNetwork.__PacketID .. "' : '" .. packet )
    end
    packet_id = math.tointeger( pid )
    local jdata = pdata[ CoreNetwork.__PacketData ]
    if jdata ~= nil and type( jdata ) == "string" then
        payload = CoreNetwork.__json.decode( jdata )
    end
    return packet_id, payload                  -- Return the PacketID and packet data
end







return CoreNetwork