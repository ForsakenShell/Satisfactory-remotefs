---Vector 4F { x:number, y:number }
---@class Vector4F:table
local Vector4F = _G[ "Vector4F" ] or {
    X = 0.0,
    Y = 0.0,
    Z = 0.0,
    W = 0.0,
    pattern = '{X=%1.6f,Y=%1.6f,Z=%1.6f,W=%1.6f}',
}
_G[ "Vector4F" ] = Vector4F
Vector4F.__index = Vector4F



---Create a new Vector4F and return it
---@param X number
---@param Y number
---@param Z number
---@param W number
---@return Vector4F
function Vector4F.new( X, Y, Z, W )
    if X == nil or type( X ) ~= "number" then return nil end
    if Y == nil or type( Y ) ~= "number" then return nil end
    if Z == nil or type( Z ) ~= "number" then return nil end
    if W == nil or type( W ) ~= "number" then return nil end
    local o = { X = X, Y = Y, Z = Z, W = W }
    setmetatable( o, { __index = Vector4F } )
    return o
end


---Zero length Vector4F
Vector4F.Zero = Vector4F.new( 0.0, 0.0, 0.0, 0.0 )




---Tests whether the passed in variable is a Vector4F
---@param v any
---@return boolean true if v is a Vector4F, false otherwise
function Vector4F.isVector4F( v )
    return v ~= nil
    and type( v ) == "table"
    and getmetatable( v ) ~= nil
    and getmetatable( v ).__index == Vector4F
end



---Are the two vectors the "same"?  This means that x and y are equal even if the vectors themselves are different tables.
---@param a Vector4F
---@param b Vector4F
---@return boolean true if a and b are Vector4F and the value of the two vectors are numerically equal, false otherwise
function Vector4F.equals( a, b )
    -- Are they even Vector4F?
    if not Vector4F.isVector4F( a ) then return false end
    if not Vector4F.isVector4F( b ) then return false end
    
    -- Don't test for table equality, at best is saves one comparison, worst (and most likely) it adds one
    return ( a.X == b.X )and( a.Y == b.Y )and( a.Z == b.Z )and( a.W == b.W )
end




---Return this Vector4F as a string using the supplied pattern or default Vector4F.pattern
---@param pattern? string Optional pattern to use for string.format()
---@return string formatted string
function Vector4F:ToString( pattern )
    pattern = pattern or self.pattern
    return string.format( pattern, self.X, self.Y, self.Z, self.W )
end

---Return the Vector4F? as a string using the supplied pattern or default Vector4F.pattern
---@param v table vector
---@param pattern? string Optional pattern to use for string.format()
---@return string formatted string
function Vector4F.ToString( v, pattern )
    if v == nil then return 'nil' end
    local vt = type( v )
    if vt ~= "table" and vt ~= "userdata" then return 'invalid' end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    local z = v.z or v.Z or v[ 3 ]
    local w = v.w or v.W or v[ 4 ]
    if x == nil or type( x ) ~= "number"
    or y == nil or type( y ) ~= "number"
    or z == nil or type( z ) ~= "number"
    or w == nil or type( w ) ~= "number"
    then return 'invalid' end
    pattern = pattern or Vector4F.pattern
    return string.format( pattern, x, y, z, w )
end




---Add a vector to this vector
---@param b Vector4F
function Vector4F:add( b )
    if not Vector4F.isVector4F( b ) then return end
    self.X = self.X + b.X
    self.Y = self.Y + b.Y
    self.Z = self.Z + b.Z
    self.W = self.W + b.W
end

---Add a vector from this vector
---@param b Vector4F
function Vector4F:sub( b )
    if not Vector4F.isVector4F( b ) then return end
    self.X = self.X - b.X
    self.Y = self.Y - b.Y
    self.Z = self.Z - b.Z
    self.W = self.W - b.W
end

---Multiply this vector by a factor
---@param f number
function Vector4F:mul( f )
    if f == nil or type( f ) ~= "number" then return end
    self.X = self.X * f
    self.Y = self.Y * f
    self.Z = self.Z * f
    self.W = self.W * f
end

---Divide this vector by a divisor
---@param d number
function Vector4F:div( d )
    if d == nil or type( d ) ~= "number" then return end
    self.X = self.X / d
    self.Y = self.Y / d
    self.Z = self.Z / d
    self.W = self.W / d
end




---Add vector a and vector b together and return a new vector result
---@param a Vector4F
---@param b Vector4F
---@return Vector4F
function Vector4F.add( a, b )
    if not Vector4F.isVector4F( a ) then return nil end
    if not Vector4F.isVector4F( b ) then return nil end
    return Vector4F.new( a.X + b.X, a.Y + b.Y, a.Z + b.Z, a.W + b.W )
end

---Subtract vector b from vector a and return a new vector result
---@param a Vector4F
---@param b Vector4F
---@return Vector4F
function Vector4F.sub( a, b )
    if not Vector4F.isVector4F( a ) then return nil end
    if not Vector4F.isVector4F( b ) then return nil end
    return Vector4F.new( a.X - b.X, a.Y - b.Y, a.Z - b.Z, a.W - b.W )
end

---Multiply the vector by the factor and return a new vector result
---@param a Vector4F
---@param f number
---@return Vector4F
function Vector4F.mul( a, f )
    if not Vector4F.isVector4F( a ) then return nil end
    if f == nil or type( f ) ~= "number" then return nil end
    return Vector4F.new( a.X * f, a.Y * f, a.Z * f, a.W * f )
end

---Divide the vector by the divisor and return a new vector result
---@param a Vector4F
---@param d number
---@return Vector4F
function Vector4F.div( a, d )
    if not Vector4F.isVector4F( a ) then return nil end
    if d == nil or type( d ) ~= "number" then return nil end
    return Vector4F.new( a.X / d, a.Y / d, a.Z / d, a.W / d )
end




---Return the length of this Vector4F
function Vector4F:length()
    return ( ( self.X * self.X ) + ( self.Y * self.Y ) + ( self.Z * self.Z ) + ( self.W * self.W ) ) ^ 0.5 -- oldest trick - factoring/multiplication is faster than sqrt/dividing
end


---Normalize this vector to a length of 1.0 (this vector cannot be a Vector4F.Zero)
function Vector4F:normalize()
    local length = self:length()
    if length > 0.0 then
        self:div( length )
    end
end




---Convert this Vector4F to { X, Y, Z, W }
---@return table table{ X, Y }
function Vector4F:ToVector4f()
    return { X = self.X, Y = self.Y, Z = self.Z, W = self.W }
end

---Convert from { v.X or v.X or v[1], ... }
---@return table table{ x, y, z, w } or nil
function Vector4F.ToVector4f( v )
    if v == nil or type( v ) ~= "table" then return nil end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    local z = v.z or v.Z or v[ 3 ]
    local w = v.w or v.W or v[ 4 ]
    if x == nil or y == nil or z == nil or w == nil then return nil end
    return { x = x, y = y, z = z, w = w }
end

---Convert from { v.X or v.X or v[1], ... }
---@return Vector4F Vector4F or nil
function Vector4F.ToVector4F( v )
    if v == nil or type( v ) ~= "table" then return nil end
    local X = v.x or v.X or v[ 1 ]
    local Y = v.y or v.Y or v[ 2 ]
    local Z = v.z or v.Z or v[ 3 ]
    local W = v.w or v.W or v[ 4 ]
    if X == nil or Y == nil or Z == nil or W == nil then return nil end
    return Vector4F.new( X, Y, Z, W )
end

---Convert from { v.X or v.X or v[1], ... }
---@return array array[ 1, 2, 3, 4 ] or nil
function Vector4F.ToVectorArray( v )
    if v == nil or type( v ) ~= "table" then return nil end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    local z = v.z or v.Z or v[ 3 ]
    local w = v.w or v.W or v[ 4 ]
    if x == nil or y == nil or z == nil or w == nil then return nil end
    return { x, y, z, w }
end




return Vector4F