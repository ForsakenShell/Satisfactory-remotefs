-- Network diagnostic script
-- See bottom for debug dumps of connected network nicks

-- Save debug dumps to 'console.txt'
require( '/lib/ConsoleToFile.lua', ____RemoteCommonLib )



exportObjects = component.proxy( component.findComponent( "" ) )

for _, object in pairs( exportObjects ) do
    if object == computer.getInstance() then
        table.remove( exportObjects, _ )
    end
end




---Get the platforms making up this entire station as an array starting with the station itself (it is a platform after all)
---@param station userdata The station to return the array of platforms (in-order) that are connected to it
---@return table The platforms, starting with the station at [1] and all others at [2...]
local function getPlatforms( station )
    if station == nil or type( station ) ~= "userdata" then return nil end
    local results = {}
    table.insert( results, station )
    
    local pLast = nil
    local pCur = station
    while( pCur ~= nil )do
        local pNext = pCur:getConnectedPlatform( 1 )
        if pNext == nil or ( pLast ~= nil and pNext == pLast )then
            -- Nothing in that direction or we got the previous platform (this platform is reversed)
            pNext = pCur:getConnectedPlatform( 0 )
            if pNext == nil or pNext == pLast then
                -- No really, we're done
                break
            end
        end
        if pNext ~= nil then
            pLast = pCur
            pCur = pNext
            table.insert( results, pCur )
        end
    end
    
    return results
end


-- Find all the train stations and add their platforms
local additionalObjects = {}
for _, object in pairs( exportObjects ) do
    
    local name = string.lower( object.internalName )
    local foo, bar = string.find( name, "trainstation", 1, true )
    if foo ~= nil and foo > 0 then
        print( "train station: " .. name )
        local platforms = getPlatforms( object )
        if platforms ~= nil and #platforms > 1 then
            for i = 2, #platforms do
                table.insert( additionalObjects, platforms[ i ] )
            end
        end
    end
end
for _, object in pairs( additionalObjects ) do
    table.insert( exportObjects, object )
end




local function addToString( instr, addstr, sep )
    if addstr == nil or addstr == '' then return instr end
    if sep == nil then sep = ' ' end
    instr = instr or ''
    if instr ~= '' then instr = instr .. sep end
    return instr .. addstr
end


local function getParameterTypeNameFromProperty( property )
    if property == nil then return nil end
    local pt = tostring( property )
    local sc = nil
    if      pt == 'ArrayProperty' then
        sc = property:getInner()
        if sc == nil then return nil end
        local innerResult = getParameterTypeNameFromProperty( sc )
        if innerResult == nil then end
        return 'Array( ' .. innerResult .. ' )'
    end
    if pt == 'ClassProperty'
    or pt == 'ObjectProperty'
    or pt == 'StructProperty'
    or pt == 'TraceProperty' then
        sc = property:getSubclass()
    end
    if sc == nil then return nil end
    return sc.name
end

local function dataTypeName( dt, object )
    if dt == nil or type( dt ) ~= 'number' then return 'invalid' end
    local result = nil
    if     dt == 0 then result = 'nil'
    elseif dt == 1 then result = 'bool'
    elseif dt == 2 then result = 'int'
    elseif dt == 3 then result = 'float'
    elseif dt == 4 then result = 'string'
    elseif dt == 5 then result = 'object'
    elseif dt == 6 then result = 'class'
    elseif dt == 7 then result = 'trace'
    elseif dt == 8 then result = 'struct'
    elseif dt == 9 then result = 'array'
    elseif dt == 10 then result = 'anything'
    end
    local innerResult = getParameterTypeNameFromProperty( object )
    if innerResult ~= nil then
        result = innerResult
    end
    if result ~= nil then return result end
    return string.format( '(%d) unknown', dt )
end


local function dataFlagName( df )
    if df == nil or type( df ) ~= 'number' then return 'invalid' end
    local s = ''
    local sep = ' | '
    if ( df &   1 ) ~= 0 then s = addToString( s, 'member attribute', sep ) end
    if ( df &   2 ) ~= 0 then s = addToString( s, 'read only', sep ) end
    if ( df &   4 ) ~= 0 then s = addToString( s, 'parameter', sep ) end
    if ( df &   8 ) ~= 0 then s = addToString( s, 'output parameter', sep ) end
    if ( df &  16 ) ~= 0 then s = addToString( s, 'return value', sep ) end
    if ( df &  32 ) ~= 0 then s = addToString( s, 'runtime synchronous', sep ) end
    if ( df &  64 ) ~= 0 then s = addToString( s, 'runtime parallel', sep ) end
    if ( df & 128 ) ~= 0 then s = addToString( s, 'runtime asynchronous', sep ) end
    if ( df & 256 ) ~= 0 then s = addToString( s, 'class attribute', sep ) end
    return '(' .. df .. ') ' .. s
end


local function dumpReflectionProperty( o, p, indents, resolver, includeValue, ... )
    if o == nil or p == nil or type( p ) ~= "string" or p == '' then return end
    if includeValue == nil or type( includeValue ) ~= "boolean" then includeValue = true end
    local v = o[ p ]
    local vs = tostring( v )
    local s = indents .. p .. " = "
    if resolver ~= nil and type( resolver ) == 'function' then
        s = s .. resolver( v, ... )
        if includeValue then s = s .. ' (' .. vs .. ')' end
    else
        s = s .. vs
    end
    print( s )
end

local function dumpProperty( p, indents )
    if p == nil then return end
    dumpReflectionProperty( p, "dataType", indents, dataTypeName, false, p )
    dumpReflectionProperty( p, "flags", indents, dataFlagName, false )
end

local function dumpArrayProperty( p, indents )
    indents = indents or ''
    dumpProperty( p, indents )
    local i = p:getInner()
    if i ~= nil then
        dumpReflectionBase( i, indents, 'getInner()' )
    end
end

local function dumpSubClassProperty( p, indents )
    indents = indents or ''
    dumpProperty( p, indents )
    local i = p:getSubclass()
    if i ~= nil then
        dumpReflectionBase( i, indents, 'getSubclass()' )
    end
end

local function inOrOut( isOut )
    if isOut then return "out" end
    return "in"
end

local function dumpParameters( f, indents, isSignal )
    if f == nil then return end
    local parametersLine = ''
    local returnsLine = ''
    local parameters = f:getParameters()
    if parameters ~= nil then
        --indents = indents or ''
        --print( indents .. 'getParameters()' )
        --indents = indents .. '\t'
        local fullDump = {}
        local parametersDesc = {}
        local returnsDesc = {}
        local lparam = #parameters
        if isSignal then -- Signals don't have parameters, only returns
            lparam = 0
        end
        for index, parameter in pairs( parameters ) do
        --    dumpReflectionBase( parameter, indents, _ )
            local isReturnValue = ( ( parameter.flags & 16 ) ~= 0 ) or ( index > lparam )
            local ps = parameter.name
            local psl = ps .. ': ' .. dataTypeName( parameter.dataType, parameter )
            if parameter.description ~= '' then
                psl = psl .. ' - ' .. parameter.description
            end
            if isReturnValue then
                returnsLine = addToString( returnsLine, ps, ', ' )
                returnsDesc[ index ] = psl
            else
                parametersLine = addToString( parametersLine, ps, ', ' )
                parametersDesc[ index ] = psl
            end
            --if parameter.dataType < 0 or parameter.dataType > 10 then
            --    fullDump[ index ] = parameter
            --end
        end
        parametersLine = '( ' .. parametersLine .. ' )'
        if returnsLine == '' then returnsLine = 'void' end
        local indent2 = indents .. '\t'
        if not isSignal then -- Signals don't have parameters, only returns
            print( indents .. 'parameters: ' .. parametersLine )
            for _, desc in pairs( parametersDesc ) do
                print( indent2 .. desc )
            end
        end
        print( indents .. 'returns: ' .. returnsLine )
        for _, desc in pairs( returnsDesc ) do
            print( indent2 .. desc )
        end
        if table.countKeyValuePairs( fullDump ) ~= 0 then
            print( indents .. 'Unknown parameter types:' )
            for _, parameter in pairs( fullDump ) do
                dumpReflectionBase( parameter, indent2, _ )
            end
        end
    end
end

local function dumpFunction( f, indents )
    indents = indents or ''
    dumpReflectionProperty( f, "flags", indents, dataFlagName, false )
    dumpParameters( f, indents, false )
end

local function dumpSignal( s, indents )
    indents = indents or ''
    dumpReflectionProperty( s, "isVarArgs", indents )
    dumpParameters( s, indents, true )
end


function dumpReflectionBase( r, indents, leader )
    if r == nil then return end
    
    indents = indents or ''
    
    leader = leader or ''
    if leader ~= '' then leader = leader .. ' = ' end
    print( indents .. leader .. r.name .. " '" .. r.displayName .. "'" )
    --dumpObject( r, r.name, indents, leader )
    
    indents = indents .. '\t'
    
    local rt = tostring( r )
    print( indents .. rt )
    
    local d = r.description
    if d ~= nil and type( d ) == "string" and d ~= '' then
        print( indents .. d )
    end
    
    --local isProperty = string.find( string.lower( rt ), 'property', 1, true ) ~= nil 
    if rt == 'Property' then
        dumpProperty( r, indents )
    elseif rt == 'ArrayProperty' then
        dumpArrayProperty( r, indents )
    elseif rt == 'ClassProperty' then
        dumpSubClassProperty( r, indents )
    elseif rt == 'ObjectProperty' then
        dumpSubClassProperty( r, indents )
    elseif rt == 'StructProperty' then
        dumpSubClassProperty( r, indents )
    elseif rt == 'TraceProperty' then
        dumpSubClassProperty( r, indents )
    
    elseif rt == 'Function' then
        dumpFunction( r, indents )
        
    elseif rt == 'Signal' then
        dumpSignal( r, indents )
        
    elseif rt == 'Class' then
        --if not table.hasValue( exportObjects, r ) then
        --    table.insert( exportObjects, r )
        --end
        dumpObject( r, r.name, indents, nil, false)
    end
    
end

local function dumpReflectionArrayFunction( r, func, indents )
    local f = r[ func ]
    if f == nil or type( f ) ~= "function" then return end
    
    indents = indents or ''
    
    local results = f( r )
    local n = #results
    print( indents .. func .. "() = " .. tostring( n ) )
    if n == 0 then return end
    
    indents = indents .. '\t'
    for _, result in pairs( results ) do
        if result ~= r then
            dumpReflectionBase( result, indents )
        end
    end
end




function dumpObject( o, name, indents, leader, dumpType )
    if o == nil then return end
    
    indents = indents or ''
    
    name = name or ''
    leader = leader or ''
    if leader ~= '' and name ~= '' then leader = leader .. ' = ' end
    print( indents .. leader .. name )
    
    indents = indents .. '\t'
    dumpReflectionProperty( o, "hash", indents )
    dumpReflectionProperty( o, "internalName", indents )
    dumpReflectionProperty( o, "internalPath", indents )
    
    if dumpType == nil or type( dumpType ) ~= "boolean" then dumpType = true end
    
    if dumpType then
        local pt = o:getType()
        if pt ~= nil then
            --print( tostring( pt ) )
            dumpReflectionArrayFunction( pt, "getAllSignals", indents )
            dumpReflectionArrayFunction( pt, "getAllProperties", indents )
            dumpReflectionArrayFunction( pt, "getAllFunctions", indents )
        end
    end
    
end


for _, object in pairs( exportObjects ) do
    local name = object[ "id" ] or object[ "name" ] or object[ "internalName" ]
    dumpObject( object, name, nil, tostring( object ) )
end

