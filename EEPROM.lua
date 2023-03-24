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
--- should be directly in ____RemoteFSBaseURL

____RemoteFSBaseURL = "http://localhost/remotefs"
____RemoteCommonLib = "/remoteCommonLib"                                --- Used for common libraries to all computers no matter their specific purpose

--- You can run your own tiny web server on your own machine or another machine on your
--- own network so you don't need to use git or some other hosting service on the internet.
--- The one I use for testing and works well with Satisfactory is:
---     Rebex Tiny Web Server v1.0.0 (free)
---     https://www.rebex.net/tiny-web-server

--- See the very bottom of this file for how to include your "standard library" and comment out mine




print( "\n\nSystem EEPROM v1.1.5...\n\n" )




local ____filesystem = filesystem                   -- If usercode decides to mask this, make sure it's accessible to us
if not ____filesystem.initFileSystem( "/dev" ) then
    computer.panic( "Cannot initialize /dev" )
end




---Decodes a table of settings stored in a string.
---Settings should be encoded as: key1="value1" key2="value2" ...
---@param str string Tokenized string to decode
---@param lowerKeys boolean Force the keys to be lowercase, otherwise any cAmElCaSInG is preserved and it will be usercode responsibility to deal with it
---@return table table {key=field,value=value*} *value will not be quoted despite the requirement to enclose the value in double quotes in the nick
function settingsFromString( str, lowerKeys )
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
---@param lowerKeys boolean Force the keys to be lowercase, otherwise any cAmElCaSInG is preserved and it will be usercode responsibility to deal with it
---@return string
function stringFromSettings( settings )
    if settings == nil or type( settings ) ~= "table" then return nil end
    local str = ''
    for k, v in pairs( settings ) do
        if str ~= '' then str = str .. ' ' end
        str = str .. k .. '="' .. v .. '"'
    end
    return str
end


---Reads the table of settings stored in a machines nickname.  This function does not apply the setings, this merely reads the string and turns it into a {key, value} table.
---Settings should be encoded as: key1="value1" key2="value2" ...
---@param proxy userdata NetworkComponent proxy
---@param lowerKeys boolean Force the keys to be lowercase, otherwise any cAmElCaSInG is preserved and it will be usercode responsibility to deal with it
---@return table table {key=field,value=value*} *value will not be quoted despite the requirement to enclose the value in double quotes in the nick
function readNetworkComponentSettings( proxy, lowerKeys )
    if proxy == nil then return nil end
    return settingsFromString( proxy.nick, lowerKeys )
end


---Writes a table of settings to the machines nickname.
---@param proxy userdata The machine proxy to write settings to
---@param settings table Settings to be written to the machines nickname
function writeNetworkComponentSettings( proxy, settings )
    if proxy == nil then return end
    local str = stringFromSettings( settings )
    if str == nil then return end
    proxy[ "nick" ] = str
end


---Reads the table of settings stored in the computers nickname, does not apply the setings
---Settings should be encoded as: key1="value1" key2="value2" ...
---@return table table {key=field,value=value*} *value will not be quoted despite it's requirement to enclose the value in the nick
function readComputerSettings( lowerKeys )
    return readNetworkComponentSettings( computer.getInstance(), lowerKeys )
end

---Writes settings to the computer nickname
function writeComputerSettings( settings )
    writeNetworkComponentSettings( computer.getInstance(), settings or ____ComputerSettings )
end




---We are assuming a single disk in the system, if you have more than one then I need to update this script to handle that
local function getFirstDisk()
    local fsChildren = ____filesystem.childs( "/dev" )
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

____Disk_UUID               = getFirstDisk()
____InternetCard            = computer.getPCIDevices( findClass( "FINInternetCard" ) )[ 1 ]
____ComputerSettings        = readComputerSettings( true ) -- Get the settings table, make sure all the keys are lowercase
____RemoteFS                = ____filesystem.path( 1, ____ComputerSettings[ "remotefs" ] or '' )
____BootLoader              = ____filesystem.path( 1, ____ComputerSettings[ "bootloader" ] or 'boot.lua' )
____UseTempFileSytem        = stringToBoolean( ____ComputerSettings[ "usetempfilesystem" ], false ) and ( ____Disk_UUID == '' )
____TempRemoteFiles         = stringToBoolean( ____ComputerSettings[ "tempremotefiles" ], true )
____AlwaysFetchFromRemote   = stringToBoolean( ____ComputerSettings[ "alwaysfetchfromremote" ], false )


if ____InternetCard ~= nil and ____RemoteFS ~= '' then
    print( "RemoteFSBaseURL: " .. ____RemoteFSBaseURL )
    print( "RemoteCommonLib: " .. ____RemoteCommonLib )
    print( "RemoteFS       : " .. ____RemoteFS )
    print( "TempFS         : " .. tostring( ____UseTempFileSytem ) )
    print( "Temp Files     : " .. tostring( ____TempRemoteFiles ) )
    print( "Always Fetch   : " .. tostring( ____AlwaysFetchFromRemote ) )
end




-- Setup the root disk aliasing or computer panic if no files to access
if ____Disk_UUID == '' then
    print( "WARNING        : No local disk installed" )
else
    print( "Disk           : " .. ____Disk_UUID )
    print( 'Windows path   : "%LocalAppData%\\FactoryGame\\Saved\\SaveGames\\computers\\' .. ____Disk_UUID .. '"' )
    if not ____filesystem.mount( "/dev/" .. ____Disk_UUID, '/' ) then
        computer.panic( "Could not mount disk to root" )
    end
    ____UseTempFileSytem = false
end

if ____InternetCard == nil then
    print( "WARNING        : No InternetCard installed, will not be able to fetch from remote file system if a file does not exist on the local disk" )
else
    if ____RemoteFS == '' then
        print( "WARNING        : No remote file system specified to fetch files from; EEPROM updates may still happen, however" )
        
    elseif ____UseTempFileSytem then
        if not ____filesystem.makeFileSystem( "tmpfs", "tmp" ) then
            computer.panic( "could not create temporary file system to host remote files\n" .. debug.traceback() )
        end
        if not ____filesystem.mount( "/dev/tmp", '/' ) then
            computer.panic( "Could not mount RAM disk as root\n" .. debug.traceback() )
        end
    end
end

if ____Disk_UUID == '' and ( ____InternetCard == nil or ____RemoteFS == '' ) then
    computer.panic( "No disk and no InternetCard (or remote file system) means no file system\n" .. debug.traceback() )
end


____UseLoadFile             = ( ( ____Disk_UUID ~= '' ) or ____UseTempFileSytem ) and not ____TempRemoteFiles


print( "BootLoader     : " .. ____BootLoader .. "\n\n" )




--require implementation with fetch from remotefs to local [RAM] disk

____RequiredFiles = {}


---Fetch a text file from a remote host, optionally panic the computer if the file cannot be retrieved
---@param remote string Full URL to the file
---@param panicOnFail boolean computer.panic() if the file cannot be retrieved; otherwise return nil
local function remoteFetchFile( remote, panicOnFail )
    local request = ____InternetCard:request( remote, "GET", "" )
    local result, data = request:await()
    if panicOnFail
    and( ( result == nil )or( result < 200 or result > 299 ) )then  -- Magic numbers are bad, 2xx is the request successful response range
        computer.panic( "Could not fetch file from: " .. remote .. "\n" .. debug.traceback() )
    end
    return data
end


---Load the given module.  This implementation looks as the local disk mounted as root and/or the remote filesystem specified by the computer settings or the explicit remote filesystem passed as the second parameter to require()
---@param modname string filepath to load and compile; filepath should be relative to the (remote) filesystem root
---@param remotefs string Optional remote filesystem to fetch the file from
function require( modname, remotefs )
    -- Make sure we are properly slashed to start
    modname = ____filesystem.path( 1, modname )
    
    
    -- Check the localized file in the table
    local package = ____RequiredFiles[ modname ]
    if package ~= nil then
        -- Already required
        return package
    end
    
    
    -- As we may manipulate the local filename, grab a copy for remote filename manipulation
    local remote = modname
    
    -- Assume the computer specific remote filesystem if not specified
    remotefs = ____filesystem.path( 1, remotefs or ____RemoteFS )
    
    -- Prefix the local filename with the RemoteCommonLib fs path to prevent local file conflicts
    if remotefs == ____RemoteCommonLib then
        modname = ____RemoteCommonLib .. modname
    end
    
    
    -- Try the local disk first, if we can't find it then we'll look for it remotely
    if not ____AlwaysFetchFromRemote
    and ____Disk_UUID ~= ''
    and ____filesystem.exists( modname ) then
        -- Create a new file package
        package = ____filesystem.loadFile( modname )() -- The compiled lua file loaded into memory
        ____RequiredFiles[ modname ] = package         -- Remember this file package
    end
    
    
    -- Try and fetch from remote
    if ____InternetCard ~= nil and remotefs ~= nil then
        
        -- Build the URL
        remote = ____RemoteFSBaseURL .. remotefs .. remote
        
        
        -- Fetch the file
        local data = remoteFetchFile( remote, ____AlwaysFetchFromRemote )
        
        if data ~= nil then
            
            -- load() or loadFile() based on computer settings and hardware
            if ____UseLoadFile then
                
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
                        if  not ____filesystem.exists( path )
                        and not ____filesystem.createDir( path ) then
                            computer.panic( "Unable to create " .. path .. "\n" .. debug.traceback() )
                        end
                    end
                    return path, results[ #results ]
                end
                local path, name = buildPath( modname )
                
                
                -- Write it to the [RAM] disk
                local handle = ____filesystem.open( modname, "w" )
                if handle == nil then
                    computer.panic( "Unable to create file " .. modname .. "\n" .. debug.traceback() )
                end
                handle:write( data )
                handle:close()
                
            else
                
                -- No disk at all or no storing remote files, load it directly from the returned buffer
                package = load( data, modname )()                  -- The compiled lua file loaded into memory
                ____RequiredFiles[ modname ] = package             -- Remember this file package
                
                -- Return the package
                return package
            end
            
        end
    end
    
    
    -- Try to find it on the [RAM] disk [again]
    if not ____filesystem.exists( modname ) then
        -- Last chance to panic so do it!
        computer.panic( "Cannot find file " .. modname .. "\n" .. debug.traceback()  )
    end
    
    
    -- Create a new file package
    package = ____filesystem.loadFile( modname )()     -- The compiled lua file loaded into memory
    ____RequiredFiles[ modname ] = package             -- Remember this file package
    
    
    -- Return the package
    return package
end


---Downloads the latest EEPROM.lua and flashes the chip; does not reboot the computer
---@return boolean, string success/failure and, the remote URL or nil if no network card
function updateEEPROM()
    -- No internet card means no updates
    if ____InternetCard == nil then
        return false, nil
    end
    
    -- Build the remote URL for the EEPROM
    local remote = ____RemoteFSBaseURL .. "/EEPROM.lua"
    local request = ____InternetCard:request( remote, "GET", "" )
    
    -- Fetch it
    local data = remoteFetchFile( remote, false )
    if data == nil then
        return false, remote -- Let the caller handle this
    end
    
    -- Flash it
    computer.setEEPROM( data )
    
    -- Return success
    return true, remote
end




--vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv--

-- Include the "standard library"
-- Delete this section and replace it with your own per the instructions
-- at the top of this file, which you read - right?


-- Basic extensions first
require( "/lib/extensions/strings.lua", ____RemoteCommonLib )
require( "/lib/extensions/tables.lua", ____RemoteCommonLib )

-- Then more complex ones that may need the basics themselves
require( "/lib/extensions/component.lua", ____RemoteCommonLib )
require( "/lib/extensions/computer.lua", ____RemoteCommonLib )

--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^--




-- We haven't even started yet!
event.clear()
event.ignoreAll()




-- Ok, time to get down to brass tacks
require( ____BootLoader )