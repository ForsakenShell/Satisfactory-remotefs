---
--- Created by 1000101
--- DateTime: 15/02/2023 7:05 am
---

local UPDATED = "14/03/2023 1:40 am"
print( "\nInitialising HypertubeNode.Network\n\nLast Update: " .. UPDATED .. "\n" )




-- Require the core components
local CoreNetwork           = require( "/lib/CoreNetwork.lua", ____RemoteCommonLib )
local Color = require( "/lib/Colors.lua" )





-- The Hypertube networking component
local Network = {}
Network.__index = Network


Network.Default = {}
Network.Default.NETWORK_SIZE    = 20
Network.Default.NETWORK_SIZE_SETTING = "network_size"
Network.Default.TIMEOUT_PER_NODE = 250 -- in ms, default network size and timeout will result in a default 5s timeout between broadcasting the compute and waiting for all nodes to respond

Network.port                    = 500

Network.PID_ADMIN_IDENT         = 0x100
Network.PID_ADMIN_RESET         = 0x101
Network.PID_ADMIN_NODE_ERROR    = 0x102

Network.PID_ROUTE_COMPUTED      = 0x200
Network.PID_ROUTE_RESET         = 0x201
Network.PID_ROUTE_NODE_SET      = 0x202



Network.ERROR_MISSING_NODE_IDENT = 0x1000


---Register for event handling with the given NetworkCard (PCI Device).  Call this in your init function once you've gotten the NetworkCards in the computer.
---@param net userdata: NetworkCard (PCI Device) to add to the event system
function Network.listenForNetworkEventsOn( net )
    CoreNetwork.listenForNetworkEventsOn( net )
end

---NetworkMessage dispatcher; calls the appropriate handler for the packet on the port.  Call this in your main loop.
---@param edata table: {event.pull()}
---@return boolean: true, event was handled, false otherwise
function Network.handleEvent( edata )
    return CoreNetwork.handleEvent( edata )
end


----------------------------------------------------------------
--- ADMIN_IDENT
---
--- Handshake with other nodes and build the network graph for
--- each node.

local function createAdminIdentPacket( initialIDENT )
    local netloc = HypertubeNode.networkcard.location
    return CoreNetwork.encodePacket( Network.PID_ADMIN_IDENT, {
        -- Network.Ident_Payload
        uuid = computer.getInstance().id,
        vertex = HypertubeNode.vertex,
        name = HypertubeNode.name,
        connections = HypertubeNode.connections,
        location = { x = netloc.x, y = netloc.y, z = netloc.z },
        mode = HypertubeNode.mode,
        initialIDENT = initialIDENT,
    } )
end

function Network.sendAdminIdent( initialIDENT )
    HypertubeNode.networkcard:broadcast( Network.port, createAdminIdentPacket( initialIDENT ) )
end

function Network.handleAdminIdent( net, sender, payload )
    
    local vertex = payload.vertex
    
    -- Is this a new node?  (Including ourself)
    local node = HypertubeNode.nodes[ vertex ] or {}
    local isExistingNode = HypertubeNode.nodes[ vertex ] ~= nil
    
    if isExistingNode then
        -- A node with this ID exists, make sure the computers match and throw an error if it doesn't
        if payload.uuid ~= node.uuid then
            local e = "Network vertex collision, two different HypertubeNodes have the same vertex ID:\n\tvertex: " .. tostring( vertex )
            
            e = e .. "\n\texisting node: " .. node.uuid
            e = e .. "\n\t\tmode: " .. HypertubeNode.getModeName( node.mode )
            if node.name ~= nil then
                e = e .. "\n\t\tname: " .. node.name
            end
            e = e .. "\n\t\tconnections:"
            for _, v in pairs( node.connections ) do
                e = e .. ' ' .. tostring( v )
            end
            
            e = e .. "\n\tnew node: " .. payload.uuid
            e = e .. "\n\t\tmode: " .. HypertubeNode.getModeName( payload.mode )
            if payload.name ~= nil then
                e = e .. "\n\t\tname: " .. payload.name
            end
            e = e .. "\n\t\tconnections:"
            for _, v in pairs( payload.connections ) do
                e = e .. ' ' .. tostring( v )
            end
            error( e )
        end
        
    end
    
    node.uuid = payload.uuid
    node.vertex = payload.vertex
    node.name = payload.name
    node.connections = payload.connections
    node.location = payload.location
    node.mode = payload.mode
    
    -- Update the map
    HypertubeNode.nodes[ vertex ] = node
    
    -- Create connections in the Matrix
    HypertubeNode.hyper_network:reset_connections_for( vertex )
    for _, remote in pairs( node.connections ) do
        --print( vertex .. "->" .. remote)
        HypertubeNode.hyper_network:connect( vertex, remote )
    end
    
    -- Set the position of the vertex
    HypertubeNode.hyper_network:assign_location( vertex, node.location )
    
    -- Regardless of whether we have them in our map, they just came online (maybe local reset?)
    -- and this was their initial IDENT, send them an IDENT back
    if payload.initialIDENT and payload.vertex ~= HypertubeNode.vertex then -- Don't talk to yourself, it's embarassing
        net:send( sender, Network.port, createAdminIdentPacket( false ) ) -- NOT an initialIDENT from us though
    end
    
    -- Update the display
    if HypertubeNode.mode == HypertubeNode.MODE_DESTINATION then
        HypertubeNode.UIO.ListOpt.setListData( HypertubeNode.nodes )
        HypertubeNode.updateMapToggleMode()
    end
    
    return true
end

CoreNetwork.registerPacketHandler(
    Network.port,
    Network.PID_ADMIN_IDENT,
    Network.handleAdminIdent )

----------------------------------------------------------------
--- ADMIN_RESET
---
--- Reboot the node, optionally flash the EEPROM from the remote
--- file system before rebooting.

function Network.sendAdminReset( updateEEPROM )
    local packet = CoreNetwork.encodePacket( Network.PID_ADMIN_RESET, {
        updateEEPROM = updateEEPROM or false,
    } )
    HypertubeNode.networkcard:broadcast( Network.port, packet )
end


function Network.handleAdminReset( net, sender, payload )
    HypertubeNode.setControlUIOSignalBlockStates( true, true, true )
    HypertubeNode.setNodeStatus( 'Resetting node...', Color.YELLOW_SIGN_BRDRTEXT, Color.GREY_0125 )
    
    -- Reload the settings so we can preserve any that may have changed since booting
    local settings = readComputerSettings()
    
    -- Now update any runtime settings
    local size = HypertubeNode.hyper_network.size
        
    if size <= Network.Default.NETWORK_SIZE then
        -- Nuke it so the default (which may have changed with a software update) takes over on the next load
        settings[ Network.Default.NETWORK_SIZE_SETTING ] = nil
    else
        settings[ Network.Default.NETWORK_SIZE_SETTING ] = size
    end
    writeComputerSettings( settings )
    
    -- Optionally flash the EEPROM
    if payload.updateEEPROM then
        updateEEPROM()
    end
    
    -- Reboot the computer
    computer.beep()
    computer.reset()
end

CoreNetwork.registerPacketHandler(
    Network.port,
    Network.PID_ADMIN_RESET,
    Network.handleAdminReset )

----------------------------------------------------------------
--- PID_ADMIN_NODE_ERROR
---
--- Reboot the node, optionally flash the EEPROM from the remote
--- file system before rebooting.

local function nodeErrorString( payload )
    local dest = HypertubeNode.nodes[ payload.vertex ]
    local n = ''
    if dest ~= nil then n = dest.name end
    return string.format( "ADMIN_NODE_ERROR\n\tuuid   : %s\n\tvertex : %d\n\tname   : %s\n\tcode   : %x\n\tdetails: %s", payload.uuid, payload.vertex, n, payload.code, payload.details )
end

function Network.sendAdminNodeError( remote, code, details )
    local payload = {
        uuid = computer.getInstance().id,
        vertex = HypertubeNode.vertex,
        code = code,
        details = details,
    }
    local packet = CoreNetwork.encodePacket( Network.PID_ADMIN_NODE_ERROR, payload )
    HypertubeNode.networkcard:send( remote, Network.port, packet )
    print( nodeErrorString( payload ) )
    computer.beep()
end


function Network.handleAdminNodeError( net, sender, payload )
    HypertubeNode.setControlUIOSignalBlockStates( true, true, true )
    HypertubeNode.setNodeStatus( 'Nodes report errors, see console log', Color.RED_SIGN_HIGH, Color.GREY_0125 )
    
    print( nodeErrorString( payload ) )
    
    -- Yell at the player to get their attention
    computer.beep()
end

CoreNetwork.registerPacketHandler(
    Network.port,
    Network.PID_ADMIN_NODE_ERROR,
    Network.handleAdminNodeError )

----------------------------------------------------------------
--- ROUTE_COMPUTED
---
--- A node has computed a route and is telling the network they
--- need to change their switch states.

function Network.sendRouteComputed( route )
    local packet = CoreNetwork.encodePacket( Network.PID_ROUTE_COMPUTED, {
        start = HypertubeNode.vertex,
        destination = HypertubeNode.destination,
        route = route,
    } )
    HypertubeNode.networkcard:broadcast( Network.port, packet )
end

function Network.handleRouteComputed( net, sender, payload )
    --print( payload.start, HypertubeNode.vertex )
    if payload.start == HypertubeNode.vertex then
        --print( "no self talk" )
        return
    end            -- Start is setup before broadcasting this, don't do silly things
    
    HypertubeNode.setControlUIOSignalBlockStates( true, true, false )
    
    HypertubeNode.start = payload.start                     -- Set the start the route start
    HypertubeNode.destination = payload.destination         -- Set the destination to the route destination
    HypertubeNode.route = payload.route                     -- Set the routing information
    
    local start = HypertubeNode.nodes[ HypertubeNode.start ]
    local dest = HypertubeNode.nodes[ HypertubeNode.destination ]
    local canProcess = ( start ~= nil )and( dest ~= nil )
    if start == nil then
        -- report error to entrance node
        Network.sendAdminNodeError( sender,
            Network.ERROR_MISSING_NODE_IDENT,
            "Start is unknown: " .. payload.start )
    end
    if dest == nil then
        -- report error to entrance node
        Network.sendAdminNodeError( sender,
            Network.ERROR_MISSING_NODE_IDENT,
            "Destination is unknown: " .. payload.destination )
    end
    if not canProcess then
        -- Block everything except a network reset
        HypertubeNode.setControlUIOSignalBlockStates( true, true, true )
        return
    end
    local sname = start.name
    local dname = dest.name
    if HypertubeNode.vertex == payload.destination then
        HypertubeNode.setNodeStatus( 'Arriving from ' .. sname , Color.WHITE, Color.GREEN_SIGN_HIGH )
        HypertubeNode.changeComputeRouteMode( false )
        HypertubeNode.setControlUIOSignalBlockStates( true, false, false )
    else
        HypertubeNode.setNodeStatus( 'Routing ' .. sname .. ' to ' .. dname, Color.YELLOW_SIGN_BRDRTEXT, Color.CYAN_SIGN_BACKGROUND )
    end
    
    HypertubeNode.setSwitches()                             -- Set the switch states for this node for the route
    Network.sendRouteNodeSet( net, sender )   -- Tell the starting node this node is ready
end

CoreNetwork.registerPacketHandler(
    Network.port,
    Network.PID_ROUTE_COMPUTED,
    Network.handleRouteComputed )


----------------------------------------------------------------
--- ROUTE_NODE_SET
---
--- A node has set it's switch states and is ready, once all other nodes have
--- reported ready then the entry tube will turn it's switches on and update the
--- sign to inform the player.

function Network.sendRouteNodeSet( net, sender )
    --print( "send ready: ", sender )
    local packet = CoreNetwork.encodePacket( Network.PID_ROUTE_NODE_SET, {
        vertex = HypertubeNode.vertex,
    } )
    -- Don't broadcast, send specifically to the start
    net:send( sender, Network.port, packet )
end

function Network.handleRouteNodeSet( net, sender, payload )
    
    --print( "ready:", payload.vertex )
    
    HypertubeNode.programming[ payload.vertex ] = true
    
    -- Check all other nodes are ready, return if any aren't
    for _, ready in pairs( HypertubeNode.programming ) do
        if not ready then return end
    end
    
    -- The rest of the network is ready, update the entrance
    
    HypertubeNode.setSwitches()                             -- Set the switch states for this node for the route
    
    HypertubeNode.route_timeout = math.huge                 -- Prevent the timeout from triggering
    
    -- Update the signage
    local sname = HypertubeNode.nodes[ HypertubeNode.start ].name
    local dname = HypertubeNode.nodes[ HypertubeNode.destination ].name
    HypertubeNode.setNodeStatus( 'Enter tube to ' .. dname, Color.WHITE, Color.GREEN_SIGN_HIGH )
    HypertubeNode.setControlUIOSignalBlockStates( true, true, false )
end

CoreNetwork.registerPacketHandler(
    Network.port,
    Network.PID_ROUTE_NODE_SET,
    Network.handleRouteNodeSet )


----------------------------------------------------------------
--- ROUTE_RESET
---
--- Reboot the node, optionally flash the EEPROM from the remote
--- file system before rebooting.

function Network.sendRouteReset()
    local packet = CoreNetwork.encodePacket( Network.PID_ROUTE_RESET, nil )
    HypertubeNode.networkcard:broadcast( Network.port, packet )
end

function Network.handleRouteReset( net, sender, payload )
    HypertubeNode.start = HypertubeNode.vertex              -- Reset to local node vertex
    HypertubeNode.destination = HypertubeNode.UIO.ListOpt.getSelectedDestination() -- Reset to local node selected list option
    HypertubeNode.route = nil                               -- Reset the routing information
    HypertubeNode.resetSwitches()                           -- Turn off all the switches for this node
    HypertubeNode.setNodeStatus( nil )
    HypertubeNode.changeComputeRouteMode( true )
    HypertubeNode.setControlUIOSignalBlockStates( false, false, true )
end

CoreNetwork.registerPacketHandler(
    Network.port,
    Network.PID_ROUTE_RESET,
    Network.handleRouteReset )

----------------------------------------------------------------





return Network