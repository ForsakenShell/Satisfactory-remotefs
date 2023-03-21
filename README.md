# Satisfactory-remotefs

Remote Filesystem codebase for Satisfactory Ficsit-Networks (FIN)

From the top of EEPROM.lua:

```shell
--- Use these nickname settings on the Computer, those marked with an asterix (\*) are required:

--- *remotefs="childpath"
--- The remote file system to map as the root path for this computer.

--- bootloader="boot.lua"
--- The name of the Lua file to load the execute on this computer.

--- usetempfilesystem="false"
--- If no local disk is present then create (true) a temporary file system and use
--- the loadFile() function in require(). Otherwise, do not use a temporary file system
--- (false) and load() remotely fetched files directly in require().
--- NOTE: This setting is automatically set to false if a local disk is present.

--- tempremotefiles="true"
--- This controls the longevity of files that are fetched from a remote file system.
--- "true" - remote files are never stored locally.
--- "false" - the full file path is created on the local/RAM disk and the file is never deleted.

--- alwaysfetchfromremote="false"
--- Controls whether to try to fetch the remote copy regardless of whether the file is on the local disk.

--- NOTE about the temporary file system:
--- In addition to your program requirements there must be enough RAM installed to host a
--- temporary file system.
```
