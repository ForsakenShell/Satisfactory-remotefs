----------------------------------------------------------------
-- Generic field meta information

---@class FieldMeta:table
---@field name string The name of the field as can be resolved by o[ FieldMeta.name ]
---@field ftype string The type of the field as can be resolved by type( o[ FieldMeta.name ] )
---@field allownil boolean Can this field be nil?
---@field valuetest function If supplied, the test function for the field value: function( meta, value ): boolean, string; where meta = FieldMeta, value = o[ FieldMeta.name ]; return boolean = isValue, string = reason if false
---@field metatable table Optional: The table to use as FieldMeta.metatable == getmetatable( value )
---@field metatablename string The name of meta table, the same as the metatable field but quoted
---@field serialize function If supplied, the function to serialize the field to a string: function( meta, value, ... ):boolean,string; where meta = FieldMeta, value = o[ FieldMeta.name ], ... = extra information from usercode, return boolean, string = true, serialized string or false, error string.
---@field pattern string Serialization string pattern such that string.format( pattern, field, ... )
---@field apply function If supplied, the function to "apply" the field (whatever that means to usercode): function( meta, value, ... ):boolean,string; where meta = FieldMeta, value = o[ FieldMeta.name ], ... = extra information from usercode, return boolean, string = true, nil or false, error string.  Note:  apply WILL be called even when value is nil, it is the applicators job to handle nils.
local FieldMeta = {
    name = '',
    ftype = '',
    allownil = false,
    valuetest = nil,
    metatable = nil,
    metatablename = nil,
    serialize = nil,
    pattern = nil,
    apply = nil,
}
FieldMeta.__index = FieldMeta


function FieldMeta.new( o )
    setmetatable( o, { __index = FieldMeta } )
    return o
end


---Test a table field for [nil], required type [and, value[s]]
---@param value any The value being tested
---@return boolean, string true, nil or false, reason
function FieldMeta:isValid( value, checkMeta )
    -- Make sure the meta table is correct
    if self.name == nil or type( self.name ) ~= "string" or self.name == '' then return false, string.format( "FieldMeta.name is missing or wrong type\n%s", debug.traceback() ) end 
    if self.ftype == nil or type( self.ftype ) ~= "string" or self.ftype == '' then return false, string.format( "FieldMeta.ftype is missing or wrong type\n%s", debug.traceback() ) end 
    if self.__index ~= FieldMeta then
        local mt = getmetatable( self )
        if mt == nil or mt.__index ~= FieldMeta then return false, string.format( "FieldMeta.metatable incorrect, expected FieldMeta\n%s", debug.traceback() ) end
    end
    
    -- Okay, now check the actual field
    
    if value == nil then
        if self.allownil then return true, nil end
        return false, string.format( "%s is nil\n%s", self.name, debug.traceback() )
    end
    if type( value ) ~= self.ftype then
        return false, string.format( "%s is incorrect type, expected %s\n%s", self.name, self.ftype, debug.traceback() )
    end
    if checkMeta == nil or type( checkMeta ) ~= "boolean" then checkMeta = true end
    if checkMeta and self.metatable ~= nil then
        if type( self.metatable ) ~= "table" then return false, string.format( "FieldMeta.metatable is invalid\n%s", debug.traceback() ) end
        if self.metatablename == nil or type( self.metatablename ) ~= "string" or self.metatablename == '' then return false, string.format( "FieldMeta.metatablename is missing or invalid\n%s", debug.traceback() ) end
        local mt = getmetatable( value )
        if ( mt ~= nil and mt.__index ~= self.metatable ) and value.__index ~= self.metatable then
            --print( '?' , tostring( self.metatable ) )
            --print( '>', tostring( mt ) )
            --if mt ~= nil then print( '>\t' .. tostring( mt.__index ) ) end
            --print( '}', tostring( value.__index ) )
            return false, string.format( "%s metatable incorrect, expected %s\n%s", self.name, self.metatablename, debug.traceback() )
        end
    end
    if self.valuetest ~= nil then
        if type( self.valuetest ) ~= "function" then return false, string.format( "FieldMeta.valuetest is invalid, expected function got %s\n%s", type( self.valuetest ), debug.traceback() ) end
        return self.valuetest( self, value )
    end
    return true, nil
end




----------------------------------------------------------------
-- Generic class meta information

---@class ClassMeta:table
---@field metatable table The table to use as ClassMeta.metatable == getmetatable( o ) - NOT THIS TABLE!  THE TABLE THIS META TABLE DESCRIBES!
---@field metatablename string The name of the table this ClassMeta describes, the same as the metatable field but quoted
---@field fields array The fields in the table
---@field pattern string Serialization string pattern to the table such that string.format( ClassMeta.pattern, ClassMeta.name, table.concat( fieldImports, ',' ) )
local ClassMeta = {
    metatable = nil,
    metatablename = nil,
    allownil = false,
    fields = {},
    pattern = '%s=(%s)',
}
ClassMeta.__index = ClassMeta
ClassMeta.FieldMeta = FieldMeta


function ClassMeta.new( o )
    setmetatable( o, { __index = ClassMeta } )
    return o
end


---Check whether table o conforms to the table layout described by the class meta
---@param name string Required: name of the variable 'o' - not it's class type
---@param o table Required: table to test
---@param checkMeta boolean Optional: Test o has the proper return from getmetatable(); default = true
function ClassMeta:isValid( name, o, checkMeta )
    -- Make sure the meta table is correct
    if name == nil or type( name ) ~= "string" or name == '' then return false, string.format( "name is missing or wrong type\n%s", debug.traceback() ) end 
    if self.metatable == nil or type( self.metatable ) ~= "table" then return false, string.format( "ClassMeta.metatable is missing or wrong type\n%s", debug.traceback() ) end
    if self.metatablename == nil or type( self.metatablename ) ~= "string" or self.metatablename == '' then return false, string.format( "ClassMeta.metatablename is missing or wrong type\n%s", debug.traceback() ) end
    if self.fields == nil or type( self.fields ) ~= "table" then return false, string.format( "ClassMeta.fields is missing or wrong type\n%s", debug.traceback() ) end
    if self.__index ~= ClassMeta then
        local mt = getmetatable( self )
        if mt == nil or mt.__index ~= ClassMeta then return false, string.format( "ClassMeta.metatable incorrect, expected ClassMeta\n%s", debug.traceback() ) end
    end
    
    -- Okay, now check the actual table
    
    if o == nil then
        if self.allownil then return true, nil end
        return false, string.format( "%s is nil\n%s", name, debug.traceback() )
    end
    
    local ftype = "table"
    if type( o ) ~= ftype then
        return false, string.format( "%s is incorrect type, expected %s got %s\n%s", name, ftype, type( o ), debug.traceback() )
    end
    
    if checkMeta == nil or type( checkMeta ) ~= "boolean" then checkMeta = true end
    if checkMeta and self.metatable ~= nil then
        local mt = getmetatable( o )
        if ( mt ~= nil and mt.__index ~= self.metatable ) and o.__index ~= self.metatable then
            return false, string.format( "%s metatable incorrect, expected %s\n%s", name, self.metatablename, debug.traceback() )
        end
    end
    
    for _, field in pairs( self.fields ) do
        
        if type( field ) ~= "table" then
            return false, string.format( "ClassMeta.fields[ %s ] for %s is invalid; expected FieldMeta table\n%s", _, self.metatablename, debug.traceback() )
        end
        local mt = getmetatable( field )
        if mt == nil or mt.__index  ~= FieldMeta then
            return false, string.format( "ClassMeta.fields[ %s ] for %s is invalid; expected FieldMeta table\n%s", _, self.metatablename, debug.traceback() )
        end
        
        local result, reason = field:isValid( o[ field.name ], true )
        if not result then
            return result, string.format( '%s: %s', name, reason )
        end
        
    end
    
    return true, nil
end


---Serialize a table to a string
---@param name string Required: name of the variable 'o' - not it's class type
---@param o table table to serialize
---@param ... any extra information from usercode to pass to the field importers
---@return boolean, string true, serialized string or false, error string
function ClassMeta:serialize( name, o, ... )
    local result, reason = self:isValid( name, o, true )
    if not result then return false, reason end
    
    -- Get the field imports
    local serializedFields = {}
    for _, field in pairs( self.fields ) do
        if field.serialize ~= nil and type( field.serialize ) == "function" then
            --print( field.name .. " has serialize()" )
            local value = o[ field.name ]
            if value ~= nil then
                --print( field.name .. ".value = " .. tostring( value ) )
                local serial = field.serialize( field, value, ... )
                if serial ~= nil then
                    --print( name, fieldImport )
                    table.insert( serializedFields, serial )
                end
            end
        end
    end
    
    -- No contents, don't add this table
    if #serializedFields == 0 then
        --print( name .. ' has no serialized field' )
        return true, nil
    end
    
    -- otherwise, build it all
    local pattern = self.pattern or '%s=(%s)'
    return true, string.format( pattern, name, table.concat( serializedFields, ',' ) )
end


---"Apply" the table - whatever that means to usercode.  This function calls all the FieldMeta.apply() functions for this ClassMeta.
---@param name string Required: name of the variable 'o' - not it's class type
---@param o table table to "apply"
---@param ... any extra information from usercode to pass to the field applicators
---@return boolean, string true, nil or false, error string
function ClassMeta:apply( name, o, ... )
    local result, reason = self:isValid( name, o, true )
    if not result then return false, reason end
    
    -- Apply the fields
    for _, field in pairs( self.fields ) do
        if field.apply ~= nil and type( field.apply ) == "function" then
            field.apply( field, o[ field.name ], ... )
        end
    end
    
    return true, nil
end




----------------------------------------------------------------
-- Common table field functions
FieldMeta.Common = {}

function FieldMeta.Common.Test_Integer_Positive( meta, value )
    if value < 1 then
        return false, string.format( "%s must be a positive integer - got %d", meta.name, value )
    end
    return true, nil
end
function FieldMeta.Common.Test_Integer_NotNegative( meta, value )
    if value < 0 then
        return false, string.format( "%s must be a non-negative integer - got %d", meta.name, value )
    end
    return true, nil
end
function FieldMeta.Common.Test_Number_NotNegative( meta, value )
    if value < 0.0 then
        return false, string.format( "%s must be a non-negative number - got %1.6f", meta.name, value )
    end
    return true, nil
end
function FieldMeta.Common.Test_String_NotEmpty( meta, value )
    if value == '' then
        return false, string.format( "%s cannot be empty", meta.name )
    end
    return true, nil
end

FieldMeta.Common.Pattern_String     = '%s=%s'
FieldMeta.Common.Pattern_Integer    = '%s=%d'
FieldMeta.Common.Pattern_Number     = '%s=%1.6f'
FieldMeta.Common.Pattern_Color      = '%s=(R=%1.6f,G=%1.6f,B=%1.6f,A=%1.6f)'
FieldMeta.Common.Pattern_Vector2d   = '%s=(X=%d,Y=%d)'
FieldMeta.Common.Pattern_Vector2f   = '%s=(X=%1.6f,Y=%1.6f)'
FieldMeta.Common.Pattern_Vector3f   = '%s=(X=%1.6f,Y=%1.6f,Z=%1.6f)'
FieldMeta.Common.Pattern_Vector4F   = '%s=(X=%1.6f,Y=%1.6f,Z=%1.6f,W=%1.6f)'

function FieldMeta.Common.Serialize_String( meta, value, ... )
    local pattern = meta.pattern or FieldMeta.Common.Pattern_String
    return string.format( pattern, meta.name, value )
end
function FieldMeta.Common.Serialize_Integer( meta, value, ... )
    local pattern = meta.pattern or FieldMeta.Common.Pattern_Integer
    return string.format( pattern, meta.name, value )
end
function FieldMeta.Common.Serialize_Number( meta, value, ... )
    local pattern = meta.pattern or FieldMeta.Common.Pattern_Number
    return string.format( pattern, meta.name, value )
end
function FieldMeta.Common.Serialize_Boolean( meta, value, ... )
    local pattern = meta.pattern or FieldMeta.Common.Pattern_String
    if value then
        value = 'True'
    else
        value = 'False'
    end
    return string.format( pattern, meta.name, value )
end
function FieldMeta.Common.Serialize_Color( meta, value, ... )
    local pattern = meta.pattern or FieldMeta.Common.Pattern_Color
    return string.format( pattern, meta.name, value.r, value.g, value.b, value.a )
end
function FieldMeta.Common.Serialize_Vector2d( meta, value, ... )
    local pattern = meta.pattern or FieldMeta.Common.Pattern_Vector2d
    return string.format( pattern, meta.name, value.x, value.y )
end
function FieldMeta.Common.Serialize_Vector2f( meta, value, ... )
    local pattern = meta.pattern or FieldMeta.Common.Pattern_Vector2f
    return string.format( pattern, meta.name, value.x, value.y )
end
function FieldMeta.Common.Serialize_Vector3f( meta, value, ... )
    local pattern = meta.pattern or FieldMeta.Common.Pattern_Vector3f
    return string.format( pattern, meta.name, value.x, value.y, value.z )
end
function FieldMeta.Common.Serialize_Vector4f( meta, value, ... )
    local pattern = meta.pattern or FieldMeta.Common.Pattern_Vector4F
    return string.format( pattern, meta.name, value.x, value.y, value.Z, value.w )
end




----------------------------------------------------------------
return ClassMeta