if _G[ "____CoreNetwork" ] ~= nil then return _G[ "____CoreNetwork" ] end


----------------------------------------------------------------
-- Core Network Package

local CoreNetwork                           = {}
CoreNetwork.__PacketHandlers                = {}
CoreNetwork.__PacketID                      = "npid"
CoreNetwork.__PacketPayload                 = "json"
CoreNetwork.__PacketEnclosePayloadChar         = '\a'     -- Extended chars will not transmit properly, use the single bell character as it will encode just fine and shouldn't? be used in the actual payload
CoreNetwork.__PacketPayloadTokenizePattern  = string.format( "(%%w+)=(%%b%s%s)", CoreNetwork.__PacketEnclosePayloadChar, CoreNetwork.__PacketEnclosePayloadChar )
CoreNetwork.__PacketPayloadHeadPattern      = string.format( "%%s=%s%%s%s"     , CoreNetwork.__PacketEnclosePayloadChar, CoreNetwork.__PacketEnclosePayloadChar )
CoreNetwork.__PacketPayloadPattern          = string.format( "%%s %%s=%s%%s%s" , CoreNetwork.__PacketEnclosePayloadChar, CoreNetwork.__PacketEnclosePayloadChar )
CoreNetwork.__json                          = require( "/lib/json.lua", EEPROM.Remote.CommonLib )

CoreNetwork.__index = CoreNetwork
_G[ "____CoreNetwork" ] = CoreNetwork




----------------------------------------------------------------
-- Network Management


----------------------------------------------------------------
---Register a packet handler for a given PACKET_ID on the specified network port.  PACKET_IDs are specific to each port so different ports can use the same PACKET_ID for something else.  All ports are handled the same across all network cards.
---@param port integer The port the packet must be received on
---@param packet_id integer The PACKET_ID on the port
---@param handler function handler = function(net: userdata, sender: string, payload: table) -> (boolean) : return true if the packet is handled; false otherwise.
---@return boolean, string true, nil if PACKET_ID handler is registered for the port; false, reason on error.
function CoreNetwork.registerPacketHandler( port, packet_id, handler )
    if port == nil or type( port ) ~= "number" then return false, "Invalid port" end
    if packet_id == nil or type( packet_id ) ~= "number" then return false, "Invalid PACKET_ID" end
    if handler == nil or type( handler ) ~= "function" then return false, "Invalid packet handler" end
    
    local portHandlers = CoreNetwork.__PacketHandlers[ port ] or {}
    portHandlers[ packet_id ] = handler
    CoreNetwork.__PacketHandlers[ port ] = portHandlers
    
    return true, nil
end


----------------------------------------------------------------
---NetworkMessage dispatcher; calls the appropriate handler for the packet on the port.  Call this in your main loop.
---@param edata table table of {event.pull()}
---@return boolean true event was handled; false if the event is not a NetworkMessage or not handled (no handler)
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
    
    -- Decode the packet into it's packet_id and payload
    local packet_id, payload = CoreNetwork.decodePacket( packet )
    if packet_id == nil then return false end
    
    -- Get the packet handler for the packet_id
    local handler = packetHandler[ packet_id ]
    if handler == nil then return false end
    
    -- Handle it
    return handler( net, sender, payload )
end


----------------------------------------------------------------
------Register for event handling with the given NetworkCard (PCI Device).  Call this in your init function with the NetworkCards in the computer once all the packet handlers are registered.
---@param net userdata NetworkCard (PCI Device) to add to the event system
function CoreNetwork.listenForNetworkEventsOn( net )
    event.listen( net )
    for port, packetHandlers in pairs( CoreNetwork.__PacketHandlers ) do
        net:open( port )
    end
end




----------------------------------------------------------------
-- NetworkMessage packet encode and decoder


----------------------------------------------------------------
---Encode the PACKET_ID and serialize the payload into a json string that can be sent to another computer using the FicsitNetwork API
---@param id integer PACKET_ID being sent
---@param payload table The payload of the packet.  This is serialized to json for transmission
---@return string id and payload packed into a string ready to be sent or broadcast on a NetworkCard
function CoreNetwork.encodePacket( id, payload )
    local packet = string.format( CoreNetwork.__PacketPayloadHeadPattern, CoreNetwork.__PacketID, id )
    if payload ~= nil and type( payload ) == "table" then
        packet = string.format( CoreNetwork.__PacketPayloadPattern, packet, CoreNetwork.__PacketPayload, CoreNetwork.__json.encode( payload ) )
    end
    return packet
end


----------------------------------------------------------------
---Decode the raw packet string received on the NetworkCard into the packet_id and deserialized json into the payload
---@param packet string encoded packet to rebuild the id and payload from
---@return integer, table
---@return integer packet_id or nil on error
---@return table payload; may be nil if the packet was created with no payload however, it will always be nil on error
function CoreNetwork.decodePacket( packet )
    local packet_id = -1
    local payload = nil
    local pdata = {}
    for key, value in string.gmatch( packet, CoreNetwork.__PacketPayloadTokenizePattern ) do
        local trimmed = string.sub( value, 2, string.len( value ) - 1 ) -- Strip the payload encapsulation characters
        pdata[ key ] = trimmed
    end
    local pid = pdata[ CoreNetwork.__PacketID ]
    if pid == nil then
        print( string.format( "Bad packet - no '%s' : '%s'\n%s", CoreNetwork.__PacketID, packet, debug.traceback() ) )
        return nil, nil
    end
    packet_id = math.tointeger( pid )
    local jdata = pdata[ CoreNetwork.__PacketPayload ]
    if jdata ~= nil and type( jdata ) == "string" then -- if not nil, then should always be a string (json serialized)
        payload = CoreNetwork.__json.decode( jdata )
    end
    return packet_id, payload                  -- Return the PacketID and payload
end




----------------------------------------------------------------
return CoreNetwork