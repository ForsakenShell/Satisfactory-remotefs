print( "\n\nUpdating EEPROM from remote..." )
local result = updateEEPROM()
if result then
    print( "\tEEPROM successfully updated" )
else
    print( "\tCould not update EEPROM" )
end
print( "program terminated" )