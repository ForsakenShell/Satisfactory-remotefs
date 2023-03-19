if _G[ "____ConsoleRedirected" ] ~= nil then return end

____ConsoleHandle = filesystem.open( "/console.txt", "w" )
____ConsoleRedirected = ____ConsoleHandle ~= nil
if ____ConsoleRedirected then
    print( "All print() statements have been redirected to /console.txt on the disk mounted as root.\n\nThis will be the last line written to the computer console." )
else
    print( "WARNING: Unable to redirect to file, filesystem could not create /console.txt - print() will still output to the computer console." )
end

local __oldPrint = print
print = function( ... )
    if ____ConsoleRedirected then
        --[[
        local d = { ... }
        local s = ''
        for _, v in pairs( d ) do
            if s ~= '' then s = s .. ' ' end
            if v == nil then
                s = s .. 'nil'
            else
                s = s .. tostring( v )
                -- [ [
                --local t = type( v )
                --if t == "boolean" or t == "number" then
                --    s = s .. tostring( v )
                --elseif t == "string" then
                --    s = s .. tostring( v )
                --else
                --    s = s .. tostring( t )
                --end
                -- ] ]
            end
        end
        s = s .. '\n'
        ____ConsoleHandle:write( s )
        ]]
        ____ConsoleHandle:write( ... )
        ____ConsoleHandle:write( '\n' )
    else
        __oldPrint( ... )
    end
end
