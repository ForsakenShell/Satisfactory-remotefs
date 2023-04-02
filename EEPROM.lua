EEPROM = { Version = { full = { 1, 3, 8, '' } } }
-- This will get updated with each new script release Major.Minor.Revision.Hotfix
-- Revision/Hotfix should be incremented every change and can be used as an "absolute version" for checking against
-- Do not move from the topline of this file as it is checked remotely
-- Also be sure to update EEPROM.lua.version to match

---
--- Created by 1000101
--- DateTime: 11/03/2023 3:30 am
---

--- Use these nickname settings on the Computer, those marked with an asterix (*) are required:
---
---   *remotefs="childpath"
---     The remote file system to map as the root path for this computer.
---
---   bootloader="boot.lua"
---     The name of the Lua file to load the execute on this computer.
---
---   usetempfilesystem="false"
---     If no local disk is present then create (true) a temporary file system and use
---     the loadFile() function in require().  Otherwise, do not use a temporary file system
---     (false) and load() remotely fetched files directly in require().
---     NOTE:  This setting is automatically set to false if a local disk is present.
---
---   tempremotefiles="true"
---     This controls the longevity of files that are fetched from a remote file system.
---     "true" - remote files are never stored locally.
---     "false" - the full file path is created on the local/RAM disk and the file is never deleted.
---
---   alwaysfetchfromremote="false"
---     Controls whether to try to fetch the remote copy regardless of whether the file is on the local disk.
---
---  NOTE about the temporary file system:
---    In addition to your program requirements there must be enough RAM installed to host a
---    temporary file system.

--- Remote URL to find all remote file systems in with the exception of EEPROM.lua which
--- should be directly in EEPROM.Remote.FSBaseURL

EEPROM.Remote = {}
EEPROM.Remote.FSBaseURL = "http://localhost/remotefs"
EEPROM.Remote.CommonLib = "/remoteCommonLib"    --- Used for common libraries to all computers no matter their specific purpose
EEPROM.Remote.EEPROM    = EEPROM.Remote.FSBaseURL .. '/EEPROM.lua'

--- You can run your own tiny web server on your own machine or another machine on your
--- own network so you don't need to use git or some other hosting service on the internet.
--- The one I use for testing and works well with Satisfactory is:
---     Rebex Tiny Web Server v1.0.0 (free)
---     https://www.rebex.net/tiny-web-server

--- See the very bottom of this file for how to include your "standard library" and comment out mine



---Format a version table of { integer, integer, integer, char } into a string
function EEPROM.Version.IsValid( t )
    -- Input table can be 3 or 4 component
    if type( t ) ~= "table" or #t < 3 or #t > 4 then return false end
    -- Force results into the expected form
    local r1 = tonumber( t[ 1 ] )
    local r2 = tonumber( t[ 2 ] )
    local r3 = tonumber( t[ 3 ] )
    local r4 = t[ 4 ] or ''
    -- Verify usercode isn't trying to be sly
    return( type( r1 ) == "number" and r1 >= 0
        and type( r2 ) == "number" and r2 >= 0
        and type( r3 ) == "number" and r3 >= 0
        and type( r4 ) == "string"
        and( #r4 == 0
            or( #r4 == 1 and string.byte( r4 ) > 96 and string.byte( r4 ) < 123 )
        )
    )
end

function EEPROM.Version.ToString( t )
    if not EEPROM.Version.IsValid( t ) then return nil end
    return string.format( 'v%d.%d.%d%s', t[ 1 ], t[ 2 ], t[ 3 ], t[ 4 ] )
end

EEPROM.Version.pretty = EEPROM.Version.ToString( EEPROM.Version.full )
print( "\n\nSystem EEPROM " .. EEPROM.Version.pretty .. "...\n\n" )




EEPROM.____filesystem = filesystem  -- If usercode decides to mask this, make sure it's accessible to us
if not EEPROM.____filesystem.initFileSystem( "/dev" ) then
    computer.panic( "Cannot initialize /dev" )
end



EEPROM.Settings = {}



---Decodes a table of settings stored in a string.
---Settings should be encoded as: key1="value1" key2="value2" ...
---@param str string Tokenized string to decode
---@param lowerKeys? boolean Force the keys to be lowercase, otherwise any cAmElCaSInG is preserved and it will be usercode responsibility to deal with it
---@return table table {key=field,value=value*} *value will not be quoted despite the requirement to enclose the value in double quotes in the string
function EEPROM.Settings.FromString( str, lowerKeys )
    lowerKeys = lowerKeys or false
    local results = {}
    if str == nil or type( str ) ~= "string" then return results end
    for key, value in string.gmatch( str, '(%w+)=(%b"")' ) do
        if lowerKeys then key = string.lower( key ) end
        results[ key ] = string.sub( value, 2, string.len( value ) - 1 )
    end
    return results
end


---Encodes a table of settings into a string.
---Settings will be encoded as: key1="value1" key2="value2" ...
---@param settings table Table to tokenize into a string
---@param lowerKeys? boolean Force the keys to be lowercase, otherwise any cAmElCaSInG is preserved and it will be usercode responsibility to deal with it
---@return string
function EEPROM.Settings.ToString( settings, lowerKeys )
    if settings == nil or type( settings ) ~= "table" then return nil end
    lowerKeys = lowerKeys or false
    local str = ''
    for k, v in pairs( settings ) do
        if str ~= '' then str = str .. ' ' end
        if lowerKeys then k = string.lower( k ) end
        str = str .. k .. '="' .. v .. '"'
    end
    return str
end


---Reads the table of settings stored in a Network Components nickname.  This function does not apply the setings, this merely reads the string and turns it into a {key, value} table.
---Settings should be encoded as: key1="value1" key2="value2" ...
---@param proxy userdata NetworkComponent proxy
---@param lowerKeys? boolean Force the keys to be lowercase, otherwise any cAmElCaSInG is preserved and it will be usercode responsibility to deal with it
---@return table table {key=field,value=value*} *value will not be quoted despite the requirement to enclose the value in double quotes in the nick
function EEPROM.Settings.FromComponentNickname( proxy, lowerKeys )
    if proxy == nil then return nil end
    return EEPROM.Settings.FromString( proxy.nick, lowerKeys )
end


---Writes a table of settings to the Network Components nickname.
---@param proxy userdata The machine proxy to write settings to
---@param settings table Settings to be written to the machines nickname
---@param lowerKeys? boolean Force the keys to be lowercase, otherwise any cAmElCaSInG is preserved and it will be usercode responsibility to deal with it
function EEPROM.Settings.ToComponentNickname( proxy, settings, lowerKeys )
    if proxy == nil then return end
    local str = EEPROM.Settings.ToString( settings, lowerKeys )
    if str == nil then return end
    proxy[ "nick" ] = str
end


---Reads the table of settings stored in the computers nickname, does not apply the setings
---Settings should be encoded as: key1="value1" key2="value2" ...
---@param lowerKeys? boolean Force the keys to be lowercase, otherwise any cAmElCaSInG is preserved and it will be usercode responsibility to deal with it
---@return table table {key=field,value=value*} *value will not be quoted despite it's requirement to enclose the value in the nick
function EEPROM.Settings.FromComputer( lowerKeys )
    return EEPROM.Settings.FromComponentNickname( computer.getInstance(), lowerKeys )
end

---Writes settings to the computer nickname
---@param settings table Settings to be written to the computers nickname, if nil then EEPROM.Boot.ComputerSettings, which were loaded when the computer booted, will be written
---@param lowerKeys? boolean Force the keys to be lowercase, otherwise any cAmElCaSInG is preserved and it will be usercode responsibility to deal with it
function EEPROM.Settings.ToComputer( settings, lowerKeys )
    EEPROM.Settings.ToComponentNickname( computer.getInstance(), settings or EEPROM.Boot.ComputerSettings, lowerKeys )
end




---We are assuming a single disk in the system, if you have more than one then I need to update this script to handle that
local function getFirstDisk()
    local fsChildren = EEPROM.____filesystem.childs( "/dev" )
    for _, uuid in pairs( fsChildren ) do
        if uuid ~= "serial" then return uuid end
    end
    return ''
end




---Extract a boolean from a string
---@param s string the string
---@param default boolean the default value if s does not equal "true" or "false" or isn't a string
---@return boolean
local function stringToBoolean( s, default )
    if type( s ) == "string" then   -- never trust usercode, not even your own.
        s = string.lower( s )       -- also never trust the player, even yourself!
        if s == 'true' then return true end
        if s == 'false' then return false end
    end
    if default == nil or type( default ) ~= "boolean" then default = false end
    return default
end




--- Gather all the important information to boot the computer
EEPROM.Boot = {}
EEPROM.Boot.Disk                    = getFirstDisk()
EEPROM.Boot.InternetCard            = computer.getPCIDevices( findClass( "FINInternetCard" ) )[ 1 ]
EEPROM.Boot.ComputerSettings        = EEPROM.Settings.FromComputer( true ) -- Get the settings table, make sure all the keys are lowercase
EEPROM.Boot.RemoteFS                = EEPROM.____filesystem.path( 1, EEPROM.Boot.ComputerSettings[ "remotefs" ] or '' )
EEPROM.Boot.BootLoader              = EEPROM.____filesystem.path( 1, EEPROM.Boot.ComputerSettings[ "bootloader" ] or 'boot.lua' )
EEPROM.Boot.UseTempFileSystem       = stringToBoolean( EEPROM.Boot.ComputerSettings[ "usetempfilesystem" ], false ) and ( EEPROM.Boot.Disk == '' )
EEPROM.Boot.TempRemoteFiles         = stringToBoolean( EEPROM.Boot.ComputerSettings[ "tempremotefiles" ], true )
EEPROM.Boot.AlwaysFetchFromRemote   = stringToBoolean( EEPROM.Boot.ComputerSettings[ "alwaysfetchfromremote" ], false )


if EEPROM.Boot.InternetCard ~= nil and EEPROM.Boot.RemoteFS ~= '' then
    print( "RemoteFSBaseURL: " .. EEPROM.Remote.FSBaseURL )
    print( "RemoteCommonLib: " .. EEPROM.Remote.CommonLib )
    print( "RemoteFS       : " .. EEPROM.Boot.RemoteFS )
    print( "Use TempFS     : " .. tostring( EEPROM.Boot.UseTempFileSystem ) )
    print( "Temp Files     : " .. tostring( EEPROM.Boot.TempRemoteFiles ) )
    print( "Always Fetch   : " .. tostring( EEPROM.Boot.AlwaysFetchFromRemote ) )
end




-- Setup the root disk aliasing or computer panic if no files to access
if EEPROM.Boot.Disk == '' then
    print( "WARNING        : No local disk installed" )
else
    print( "Disk           : " .. EEPROM.Boot.Disk )
    EEPROM.Boot.HostPath = '%LocalAppData%\\FactoryGame\\Saved\\SaveGames\\computers\\' .. EEPROM.Boot.Disk
    print( 'Host path      : "' .. EEPROM.Boot.HostPath .. '"' )
    if not EEPROM.____filesystem.mount( "/dev/" .. EEPROM.Boot.Disk, '/' ) then
        computer.panic( "Could not mount disk to root" )
    end
    EEPROM.Boot.UseTempFileSystem = false
end

if EEPROM.Boot.InternetCard == nil then
    print( "WARNING        : No InternetCard installed, will not be able to fetch from remote file system if a file does not exist on the local disk" )
else
    if EEPROM.Boot.RemoteFS == '' then
        print( "WARNING        : No remote file system specified to fetch files from; EEPROM updates may still happen, however" )
        
    elseif EEPROM.Boot.UseTempFileSystem then
        if not EEPROM.____filesystem.makeFileSystem( "tmpfs", "tmp" ) then
            computer.panic( "Could not create temporary file system to host remote files" )
        end
        if not EEPROM.____filesystem.mount( "/dev/tmp", '/' ) then
            computer.panic( "Could not mount RAM disk as root" )
        end
    end
end

if EEPROM.Boot.Disk == '' and ( EEPROM.Boot.InternetCard == nil or EEPROM.Boot.RemoteFS == '' ) then
    computer.panic( "No disk and no InternetCard (or remote file system) means no file system" )
end


EEPROM.Boot.UseLoadFile = ( ( EEPROM.Boot.Disk ~= '' ) or EEPROM.Boot.UseTempFileSystem ) and not EEPROM.Boot.TempRemoteFiles


print( "BootLoader     : " .. EEPROM.Boot.BootLoader .. "\n\n" )




--require implementation with fetch from remotefs to local [RAM] disk

EEPROM.__RequiredFiles = {}


---Fetch a text file from a remote host, optionally panic the computer if the file cannot be retrieved
---@param remote string Full URL to the file
---@param panicOnFail boolean computer.panic() if the file cannot be retrieved; otherwise return nil
---@param debugTraceLevel? integer debug.traceback level, default is 2
---@return boolean, string true, data or false, reason
function EEPROM.Remote.Fetch( remote, panicOnFail, debugTraceLevel )
    local request = EEPROM.Boot.InternetCard:request( remote, "GET", "" )
    local result, data = request:await()
    local result = ( result ~= nil )and( result >= 200 and result <= 299 )  -- Magic numbers are bad, 2xx is the request successful response range
    if panicOnFail and not result then
        debugTraceLevel = debugTraceLevel or 2
        if debugTraceLevel < 2 then debugTraceLevel = 2 end
        computer.panic( debug.traceback( "Could not fetch file from: " .. remote, debugTraceLevel ) )
    end
    return result, data
end


---Get the URL for the module and remote filesystem, takes modname and remotefs in the same manner as require()
function EEPROM.Remote.GetURL( modname, remotefs )
    local fs = EEPROM.____filesystem.path( 1, remotefs or EEPROM.Boot.RemoteFS )
    local url = EEPROM.Remote.FSBaseURL .. fs .. modname
    return url
end

---Load the given module.  This implementation looks at the local disk mounted as root and/or the remote filesystem specified by the computer settings or the explicit remote filesystem passed as the remotefs parameter.
---@param modname string filepath to load and compile; filepath should be relative to the (remote) filesystem root
---@param remotefs string Optional remote filesystem to fetch the file from
---@param panicOnFailure boolean Optional panic the computer on any error (default: true) or return nil (false)
function require( modname, remotefs, panicOnFailure )
    if panicOnFailure == nil or type( panicOnFailure ) ~= "boolean" then panicOnFailure = true end
    
    -- Make sure we are properly slashed to start
    modname = EEPROM.____filesystem.path( 1, modname )
    
    
    -- Check the localized file in the table
    local package = EEPROM.__RequiredFiles[ modname ]
    if package ~= nil then
        -- Already required
        return package
    end
    
    
    -- Assume the computer specific remote filesystem if not specified
    remotefs = EEPROM.____filesystem.path( 1, remotefs or EEPROM.Boot.RemoteFS )
    
    -- Get the remote URL
    local remote = EEPROM.Remote.GetURL( modname, remotefs )
    
    -- Prefix the local filename with the RemoteCommonLib fs path to prevent local file conflicts
    if remotefs == EEPROM.Remote.CommonLib then
        modname = EEPROM.Remote.CommonLib .. modname
    end
    
    
    -- Try the local disk first, if we can't find it then we'll look for it remotely
    if not EEPROM.Boot.AlwaysFetchFromRemote
    and EEPROM.Boot.Disk ~= ''
    and EEPROM.____filesystem.exists( modname ) then
        -- Create a new file package
        package = EEPROM.____filesystem.loadFile( modname )() -- The compiled lua file loaded into memory
        EEPROM.__RequiredFiles[ modname ] = package         -- Remember this file package
    end
    
    
    -- Try and fetch from remote
    if EEPROM.Boot.InternetCard ~= nil and remotefs ~= nil then
        
        -- Fetch the file
        local result, data = EEPROM.Remote.Fetch( remote, EEPROM.Boot.AlwaysFetchFromRemote and panicOnFailure, 3 )
        
        -- Always fetch but don't panic, return nil
        if not result and EEPROM.Boot.AlwaysFetchFromRemote and not panicOnFailure then
            return nil
            
        elseif result then
            
            -- load() or loadFile() based on computer settings and hardware
            if EEPROM.Boot.UseLoadFile then
                
                -- Build the path on the [RAM] disk
                local function buildPath( filepath )
                    local pattern = '([^/]+)'
                    local results = {}
                    local _ = string.gsub( filepath, pattern,
                        function( c )
                            results[ #results + 1 ] = c
                            --print( c )
                        end )
                    --Build the path from the start of results to #results - 1 (the last index should be the filename)
                    local path = ''
                    for i=1, #results - 1 do
                        path = path .. '/' .. results[ i ]
                        if  not EEPROM.____filesystem.exists( path )
                        and not EEPROM.____filesystem.createDir( path ) then
                            if panicOnFailure then
                                computer.panic( debug.traceback( "Unable to create " .. path, 2 ) )
                            else
                                return nil
                            end
                        end
                    end
                    return path, results[ #results ]
                end
                local path, name = buildPath( modname )
                
                
                -- Write it to the [RAM] disk
                local handle = EEPROM.____filesystem.open( modname, "w" )
                if handle == nil then
                    if panicOnFailure then
                        computer.panic( debug.traceback( "Unable to create file " .. modname, 2 ) )
                    else
                        return nil
                    end
                end
                handle:write( data )
                handle:close()
                
            else
                
                -- No disk at all or no storing remote files, load it directly from the returned buffer
                package = load( data, modname )()           -- Compile the Lua file in memory
                EEPROM.__RequiredFiles[ modname ] = package -- Remember this file package
                
                -- Return the package
                return package
            end
            
        end
    end
    
    
    -- Try to find it on the [RAM] disk [again]
    if not EEPROM.____filesystem.exists( modname ) then
        -- Last chance to panic so do it!
        if panicOnFailure then
            computer.panic( debug.traceback( "Cannot find file " .. modname, 2 ) )
        else
            return nil
        end
    end
    
    
    -- Create a new file package
    package = EEPROM.____filesystem.loadFile( modname )()     -- The compiled lua file loaded into memory
    EEPROM.__RequiredFiles[ modname ] = package             -- Remember this file package
    
    
    -- Return the package
    return package
end



---Gets the version of the remote module, takes modname and remotefs in the same manner as require().
---Returns it's version which must be the first line of it's source file (see EEPROM.lua an example).  The variable name does not matter, not does it matter if it's in a comment, just that a table of "{ integer, integer, integer, char }" appears on the first line.
---@return version, reason table, string returns nil, reason on any error and version, remote URL on success
function EEPROM.Version.GetRemote( modname, remotefs )
    local remote = EEPROM.Remote.GetURL( modname, remotefs )
    return EEPROM.Version.GetRemoteEx( remote )
end

---Downloads the remote copy of a remote file and returns it's version which must be the first line of it's source file (see EEPROM.lua an example).  The variable name does not matter, not does it matter if it's in a comment, just that a table of "{ integer, integer, integer, char }" (no quotes) appears on the first line.
---@return version, reason table, string returns nil, reason on any error and version, remote URL on success
function EEPROM.Version.GetRemoteEx( remote )
    -- No internet card means no updates
    if EEPROM.Boot.InternetCard == nil then
        return nil, "No InternetCard installed in computer"
    end
    
    -- Try the smaller "version" file that (if it exists) will just contain the version table
    local vOnlyFile = remote .. ".version"
    local result, data = EEPROM.Remote.Fetch( vOnlyFile, false, 3 )
    if not result then
        -- Doesn't exist or some other problem, try and get the full remote file
        result, data = EEPROM.Remote.Fetch( remote, false, 3 )
    else
        remote = vOnlyFile
    end
    if not result then
        return nil, data
    end
    
    -- Extract the table from the first line and turn it into a function call in our sandbox
    local extract = data:match( "%b{}" )
    if extract == nil then return nil, "First line does not contain version table" end
    local first_line = "v(" .. extract .. ")"
    
    
    -- Setup our sandbox
    local version
    local env = {}
    function env.v( t )
        if not EEPROM.Version.IsValid( t ) then return end
        -- Input table can be 3 or 4 component
        --if type( t ) ~= "table" or #t < 3 or #t > 4 then return end
        -- Force results into the expected form
        local r1 = tonumber( t[ 1 ] )
        local r2 = tonumber( t[ 2 ] )
        local r3 = tonumber( t[ 3 ] )
        local r4 = t[ 4 ] or ''
        -- Verify usercode isn't trying to be sly
        --if  type( r1 ) == "number" and r1 >= 0
        --and type( r2 ) == "number" and r2 >= 0
        --and type( r3 ) == "number" and r3 >= 0
        --and type( r4 ) == "string"
        --and( #r4 == 0
        --    or( #r4 == 1 and string.byte( r4 ) > 96 and string.byte( r4 ) < 123 )
        --)then
            -- Version will always be 4 component
            version = {
                math.floor( r1 ),
                math.floor( r2 ),
                math.floor( r3 ),
                r4 }
        --end
    end
    
    -- Run the line in the sandbox, wrapped in a pcall
    -- The pcall will catch errors decoding the table before it's passed to the sandbox where it will verify the table contents
    local function loadVersion()
        load( first_line, remote, 'bt', env )()
    end
    pcall( loadVersion )
    if version == nil then return nil, "First line does not contain version table" end
    
    --print( string.format( "Remote version:\n\tURL: %s\n\tRaw Version: {%s}\n\tMajor: %d\n\tMinor: %d\n\tRevision: %d\n\tHotfix: %s\n\n----", remote, extract, version[ 1 ], version[ 2 ], version[ 3 ], version[ 4 ] ))
    
    return version, remote
end


local function getVersionCompare( v )
    local h = v[ 4 ] or ''
    local hotfix = 0
    if h ~= '' and #h == 1 then
        local b = string.byte( h, 1 )
        if b > 96 and b < 123 then  -- must be 'a' .. 'z' or we ignore it
            hotfix = ( b - 96 )  / 100
        end
    end
    return v[ 3 ] + hotfix
end

---Compares two versions and returns an integer representing the difference.
---@return integer? nil = a or b is invalid, 0 = a == b, 1 = a > b, -1 a < b
function EEPROM.Version.Compare( a, b )
    if not EEPROM.Version.IsValid( a )
    or not EEPROM.Version.IsValid( b ) then return nil end
    local va = getVersionCompare( a )
    local vb = getVersionCompare( b )
    if va > vb then return  1 end
    if va < vb then return -1 end
    return 0
end


---Downloads the remote copy of the boot loader module and returns it's version and remote URL or nil and an error string
function EEPROM.Version.GetRemoteBootLoader()
    local version, reason = EEPROM.Version.GetRemote( EEPROM.Boot.BootLoader )
    return version, reason
end


---Downloads the remote copy of the EEPROM module and returns it's version and remote URL or nil and an error string
function EEPROM.Version.GetRemoteEEPROM()
    local version, reason = EEPROM.Version.GetRemoteEx( EEPROM.Remote.EEPROM )
    return version, reason
end




---Downloads the latest EEPROM.lua and flashes the chip; does not reboot the computer
---@param panicOnFail? boolean Panic the computer on failure, default: false
---@return boolean, string success/failure and, the remote URL or error reason
function EEPROM.Remote.Update( panicOnFail )
    panicOnFail = panicOnFail or false
    
    -- No internet card means no updates
    if EEPROM.Boot.InternetCard == nil then
        local r = "No InternetCard installed in computer"
        if panicOnFail then
            computer.panic( debug.traceback( r, 3 ) )
        end
        return false, r
    end
    
    -- Fetch the EEPROM
    local result, data = EEPROM.Remote.Fetch( EEPROM.Remote.EEPROM, panicOnFail, 3 )
    if not result then
        return false, data -- Let the caller handle this
    end
    
    -- Flash it
    computer.setEEPROM( data )
    
    -- Return success
    return true, EEPROM.Remote.EEPROM
end




--vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv--

-- Include the "standard library"
-- Delete this section and replace it with your own per the instructions
-- at the top of this file, which you read - right?


-- Basic extensions first
require( "/lib/extensions/strings.lua", EEPROM.Remote.CommonLib )
require( "/lib/extensions/tables.lua", EEPROM.Remote.CommonLib )

-- Then more complex ones that may need the basics themselves
require( "/lib/extensions/component.lua", EEPROM.Remote.CommonLib )
require( "/lib/extensions/computer.lua", EEPROM.Remote.CommonLib )

--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^--




-- We haven't even started yet!
event.clear()
event.ignoreAll()




-- Ok, time to get down to brass tacks
require( EEPROM.Boot.BootLoader )