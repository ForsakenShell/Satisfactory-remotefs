---Vector 3f { x:number, y:number }
---@class Vector3f:table
local Vector3f = _G[ "Vector3f" ] or {
    x = 0.0,
    y = 0.0,
    z = 0.0,
    pattern = '{x=%1.6f,y=%1.6f,z=%1.6f}',
}
_G[ "Vector3f" ] = Vector3f
Vector3f.__index = Vector3f



---Create a new Vector3f and return it
---@param x number
---@param y number
---@param z number
---@return Vector3f
function Vector3f.new( x, y, z )
    if x == nil or type( x ) ~= "number" then return nil end
    if y == nil or type( y ) ~= "number" then return nil end
    if z == nil or type( z ) ~= "number" then return nil end
    local o = { x = x, y = y, z = z }
    setmetatable( o, { __index = Vector3f } )
    return o
end


---Zero length Vector3f
Vector3f.Zero = Vector3f.new( 0.0, 0.0, 0.0 )




---Tests whether the passed in variable is a Vector3f
---@param v any
---@return boolean true if v is a Vector3f, false otherwise
function Vector3f.isVector3f( v )
    return v ~= nil
    and type( v ) == "table"
    and getmetatable( v ) ~= nil
    and getmetatable( v ).__index == Vector3f
end



---Are the two vectors the "same"?  This means that x and y are equal even if the vectors themselves are different tables.
---@param a Vector3f
---@param b Vector3f
---@return boolean true if a and b are Vector3f and the value of the two vectors are numerically equal, false otherwise
function Vector3f.equals( a, b )
    -- Are they even Vector3f?
    if not Vector3f.isVector3f( a ) then return false end
    if not Vector3f.isVector3f( b ) then return false end
    
    -- Don't test for table equality, at best is saves one comparison, worst (and most likely) it adds one
    return ( a.x == b.x )and( a.y == b.y )and( a.z == b.z )
end




---Return this Vector3f as a string using the supplied pattern or default Vector3f.pattern
---@param pattern? string Optional pattern to use for string.format()
---@return string formatted string
function Vector3f:ToString( pattern )
    pattern = pattern or self.pattern
    return string.format( pattern, self.x, self.y, self.z )
end

---Return the Vector3f? as a string using the supplied pattern or default Vector3f.pattern
---@param v table vector
---@param pattern? string Optional pattern to use for string.format()
---@return string formatted string
function Vector3f.ToString( v, pattern )
    if v == nil then return 'nil' end
    local vt = type( v )
    if vt ~= "table" and vt ~= "userdata" then return 'invalid' end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    local z = v.z or v.Z or v[ 3 ]
    if x == nil or type( x ) ~= "number"
    or y == nil or type( y ) ~= "number"
    or z == nil or type( z ) ~= "number"
    then return 'invalid' end
    pattern = pattern or Vector3f.pattern
    return string.format( pattern, x, y, z )
end




---Add a vector to this vector
---@param b Vector3f
function Vector3f:add( b )
    if not Vector3f.isVector3f( b ) then return end
    self.x = self.x + b.x
    self.y = self.y + b.y
    self.z = self.z + b.z
end

---Add a vector from this vector
---@param b Vector3f
function Vector3f:sub( b )
    if not Vector3f.isVector3f( b ) then return end
    self.x = self.x - b.x
    self.y = self.y - b.y
    self.z = self.z - b.z
end

---Multiply this vector by a factor
---@param f number
function Vector3f:mul( f )
    if f == nil or type( f ) ~= "number" then return end
    self.x = self.x * f
    self.y = self.y * f
    self.z = self.z * f
end

---Divide this vector by a divisor
---@param d number
function Vector3f:div( d )
    if d == nil or type( d ) ~= "number" then return end
    self.x = self.x / d
    self.y = self.y / d
    self.z = self.z / d
end




---Add vector a and vector b together and return a new vector result
---@param a Vector3f
---@param b Vector3f
---@return Vector3f
function Vector3f.add( a, b )
    if not Vector3f.isVector3f( a ) then return nil end
    if not Vector3f.isVector3f( b ) then return nil end
    return Vector3f.new( a.x + b.x, a.y + b.y, a.z + b.z )
end

---Subtract vector b from vector a and return a new vector result
---@param a Vector3f
---@param b Vector3f
---@return Vector3f
function Vector3f.sub( a, b )
    if not Vector3f.isVector3f( a ) then return nil end
    if not Vector3f.isVector3f( b ) then return nil end
    return Vector3f.new( a.x - b.x, a.y - b.y, a.z - b.z )
end

---Multiply the vector by the factor and return a new vector result
---@param a Vector3f
---@param f number
---@return Vector3f
function Vector3f.mul( a, f )
    if not Vector3f.isVector3f( a ) then return nil end
    if f == nil or type( f ) ~= "number" then return nil end
    return Vector3f.new( a.x * f, a.y * f, a.z * f )
end

---Divide the vector by the divisor and return a new vector result
---@param a Vector3f
---@param d number
---@return Vector3f
function Vector3f.div( a, d )
    if not Vector3f.isVector3f( a ) then return nil end
    if d == nil or type( d ) ~= "number" then return nil end
    return Vector3f.new( a.x / d, a.y / d, a.z / d )
end




---Return the length of this Vector3f
function Vector3f:length()
    return ( ( self.x * self.x ) + ( self.y * self.y ) + ( self.z * self.z ) ) ^ 0.5 -- oldest trick - factoring/multiplication is faster than sqrt/dividing
end


---Return the volume of this Vector3f
function Vector3f:volume()
    return self.x * self.y * self.z
end


---Normalize this vector to a length of 1.0 (this vector cannot be a Vector3f.Zero)
function Vector3f:normalize()
    local length = self:length()
    if length > 0.0 then
        self:div( length )
    end
end




---Convert this Vector3f to { X, Y }
---@return table table{ X, Y }
function Vector3f:ToVector3F()
    return { X = self.x, Y = self.y, Z = self.z }
end

---Convert from { v.X or v.x or v[1], ... }
---@return table table{ X, Y } or nil
function Vector3f.ToVector3F( v )
    if v == nil or type( v ) ~= "table" then return nil end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    local z = v.z or v.Z or v[ 3 ]
    if x == nil or y == nil or z == nil then return nil end
    return { X = x, Y = y, Z = z }
end

---Convert from { v.X or v.x or v[1], ... }
---@return Vector3f Vector3f or nil
function Vector3f.ToVector3f( v )
    if v == nil or type( v ) ~= "table" then return nil end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    local z = v.z or v.Z or v[ 3 ]
    if x == nil or y == nil or z == nil then return nil end
    return Vector3f.new( x, y, z )
end

---Convert from { v.X or v.x or v[1], ... }
---@return array array[ 1, 2 ] or nil
function Vector3f.ToVectorArray( v )
    if v == nil or type( v ) ~= "table" then return nil end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    local z = v.z or v.Z or v[ 3 ]
    if x == nil or y == nil or z == nil then return nil end
    return { x, y, z }
end




return Vector3f