---Vector 2d { x:integer, y:integer }
---@class Vector2d:table
local Vector2d = _G[ "Vector2d" ] or {
    x = 0,
    y = 0,
    pattern = '{x=%d,y=%d}',
}
_G[ "Vector2d" ] = Vector2d
Vector2d.__index = Vector2d



---Create a new Vector2d and return it
---@param x integer
---@param y integer
---@return Vector2d
function Vector2d.new( x, y )
    if x == nil or type( x ) ~= "number" then return nil end
    if y == nil or type( y ) ~= "number" then return nil end
    local o = { x = math.floor( x ), y = math.floor( y ) }
    setmetatable( o, { __index = Vector2d } )
    return o
end


---Zero length Vector2d
Vector2d.Zero = Vector2d.new( 0, 0 )




---Tests whether the passed in variable is a Vector2d
---@param v any
---@return boolean true if v is a Vector2d, false otherwise
function Vector2d.isVector2d( v )
    return v ~= nil
    and type( v ) == "table"
    and getmetatable( v ) ~= nil
    and getmetatable( v ).__index == Vector2d
end



---Are the two vectors the "same"?  This means that x and y are equal even if the vectors themselves are different tables.
---@param a Vector2d
---@param b Vector2d
---@return boolean true if a and b are Vector2d and the value of the two vectors are numerically equal, false otherwise
function Vector2d.equals( a, b )
    -- Are they even Vector2d?
    if not Vector2d.isVector2d( a ) then return false end
    if not Vector2d.isVector2d( b ) then return false end
    
    -- Don't test for table equality, at best is saves one comparison, worst (and most likely) it adds one
    return ( a.x == b.x )and( a.y == b.y )
end



---Return this Vector2d as a string using the supplied pattern or default Vector2d.pattern
---@param pattern? string Optional pattern to use for string.format()
---@return string formatted string
function Vector2d:ToString( pattern )
    pattern = pattern or self.pattern
    return string.format( pattern, self.x, self.y )
end

---Return the Vector2d? as a string using the supplied pattern or default Vector2d.pattern
---@param v table vector
---@param pattern? string Optional pattern to use for string.format()
---@return string formatted string
function Vector2d.ToString( v, pattern )
    if v == nil then return 'nil' end
    local vt = type( v )
    if vt ~= "table" and vt ~= "userdata" then return 'invalid' end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    if x == nil or type( x ) ~= "number"
    or y == nil or type( y ) ~= "number"
    then return 'invalid' end
    pattern = pattern or Vector2d.pattern
    return string.format( pattern, x, y )
end




---Add a vector to this vector
---@param b Vector2d
function Vector2d:add( b )
    if not Vector2d.isVector2d( b ) then return end
    self.x = self.x + b.x
    self.y = self.y + b.y
end

---Add a vector from this vector
---@param b Vector2d
function Vector2d:sub( b )
    if not Vector2d.isVector2d( b ) then return end
    self.x = self.x - b.x
    self.y = self.y - b.y
end

---Multiply this vector by a factor
---@param f number
function Vector2d:mul( f )
    if f == nil or type( f ) ~= "number" then return end
    self.x = math.floor( self.x * f )
    self.y = math.floor( self.y * f )
end

---Divide this vector by a divisor
---@param d number
function Vector2d:div( d )
    if d == nil or type( d ) ~= "number" then return end
    self.x = math.floor( self.x / d )
    self.y = math.floor( self.y / d )
end




---Add vector a and vector b together and return a new vector result
---@param a Vector2d
---@param b Vector2d
---@return Vector2d
function Vector2d.add( a, b )
    if not Vector2d.isVector2d( a ) then return nil end
    if not Vector2d.isVector2d( b ) then return nil end
    return Vector2d.new( a.x + b.x, a.y + b.y )
end

---Subtract vector b from vector a and return a new vector result
---@param a Vector2d
---@param b Vector2d
---@return Vector2d
function Vector2d.sub( a, b )
    if not Vector2d.isVector2d( a ) then return nil end
    if not Vector2d.isVector2d( b ) then return nil end
    return Vector2d.new( a.x - b.x, a.y - b.y )
end

---Multiply the vector by the factor and return a new vector result
---@param a Vector2d
---@param f number
---@return Vector2d
function Vector2d.mul( a, f )
    if not Vector2d.isVector2d( a ) then return nil end
    if f == nil or type( f ) ~= "number" then return nil end
    return Vector2d.new( a.x * f, a.y * f )
end

---Divide the vector by the divisor and return a new vector result
---@param a Vector2d
---@param d number
---@return Vector2d
function Vector2d.div( a, d )
    if not Vector2d.isVector2d( a ) then return nil end
    if d == nil or type( d ) ~= "number" then return nil end
    return Vector2d.new( a.x / d, a.y / d )
end




---Vector dot product
---@param a Vector2d
---@param b Vector2d
---@return number
function Vector2d.dot( a, b )
    if not Vector2d.isVector2d( a ) then return nil end
    if not Vector2d.isVector2d( b ) then return nil end
    return ( a.x * b.x ) + ( a.y * b.y )
end


---Vector cross product
---@param a Vector2d
---@param b Vector2d
---@return number
function Vector2d.cross( a, b )
    if not Vector2d.isVector2d( a ) then return nil end
    if not Vector2d.isVector2d( b ) then return nil end
    return ( a.x * b.y ) - ( a.y * b.x )
end



---Return the length of this Vector2d
function Vector2d:length()
    return ( ( self.x * self.x ) + ( self.y * self.y ) ) ^ 0.5 -- oldest trick - factoring/multiplication is faster than sqrt/dividing
end


---Return the area of this Vector2d
function Vector2d:area()
    return self.x * self.y
end


---Return the angle (in radians) of this Vector2d
function Vector2d:angle()
    return math.atan2( self.x, self.y )
end




---Convert this Vector2d to { X, Y }
---@return table table{ X, Y }
function Vector2d:ToVector2D()
    return { X = self.x, Y = self.y }
end

---Convert from { v.X or v.x or v[1], ... }
---@return table table{ X, Y } or nil
function Vector2d.ToVector2D( v )
    if v == nil or type( v ) ~= "table" then return nil end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    if x == nil or y == nil then return nil end
    return { X = math.floor( x ), Y = math.floor( y ) }
end

---Convert from { v.X or v.x or v[1], ... }
---@return Vector2d Vector2d or nil
function Vector2d.ToVector2d( v )
    if v == nil or type( v ) ~= "table" then return nil end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    if x == nil or y == nil then return nil end
    return Vector2d.new( x, y )
end

---Convert from { v.X or v.x or v[1], ... }
---@return array array[ 1, 2 ] or nil
function Vector2d.ToVectorArray( v )
    if v == nil or type( v ) ~= "table" then return nil end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    if x == nil or y == nil then return nil end
    return { math.floor( x ), math.floor( y ) }
end




return Vector2d