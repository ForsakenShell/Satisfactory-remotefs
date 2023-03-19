---Vector 2f { x:number, y:number }
---@class Vector2f:table
local Vector2f = _G[ "Vector2f" ] or {
    x = 0.0,
    y = 0.0,
}
_G[ "Vector2f" ] = Vector2f
Vector2f.__index = Vector2f



---Create a new Vector2f and return it
---@param x number
---@param y number
---@return Vector2f
function Vector2f.new( x, y )
    if x == nil or type( x ) ~= "number" then return nil end
    if y == nil or type( y ) ~= "number" then return nil end
    local o = { x = x, y = y }
    setmetatable( o, { __index = Vector2f } )
    return o
end


---Zero length Vector2f
Vector2f.Zero = Vector2f.new( 0.0, 0.0 )




---Tests whether the passed in variable is a Vector2f
---@param v any
---@return boolean true if v is a Vector2f, false otherwise
function Vector2f.isVector2f( v )
    return v ~= nil
    and type( v ) == "table"
    and getmetatable( v ) ~= nil
    and getmetatable( v ).__index == Vector2f
end



---Are the two vectors the "same"?  This means that x and y are equal even if the vectors themselves are different tables.
---@param a Vector2f
---@param b Vector2f
---@return boolean true if a and b are Vector2f and the value of the two vectors are numerically equal, false otherwise
function Vector2f.equals( a, b )
    -- Are they even Vector2f?
    if not Vector2f.isVector2f( a ) then return false end
    if not Vector2f.isVector2f( b ) then return false end
    
    -- Don't test for table equality, at best is saves one comparison, worst (and most likely) it adds one
    return ( a.x == b.x )and( a.y == b.y )
end



---Add a vector to this vector
---@param b Vector2f
function Vector2f:add( b )
    if not Vector2f.isVector2f( b ) then return end
    self.x = self.x + b.x
    self.y = self.y + b.y
end

---Add a vector from this vector
---@param b Vector2f
function Vector2f:sub( b )
    if not Vector2f.isVector2f( b ) then return end
    self.x = self.x - b.x
    self.y = self.y - b.y
end

---Multiply this vector by a factor
---@param f number
function Vector2f:mul( f )
    if f == nil or type( f ) ~= "number" then return end
    self.x = self.x * f
    self.y = self.y * f
end

---Divide this vector by a divisor
---@param d number
function Vector2f:div( d )
    if d == nil or type( d ) ~= "number" then return end
    self.x = self.x / d
    self.y = self.y / d
end




---Add vector a and vector b together and return a new vector result
---@param a Vector2f
---@param b Vector2f
---@return Vector2f
function Vector2f.add( a, b )
    if not Vector2f.isVector2f( a ) then return nil end
    if not Vector2f.isVector2f( b ) then return nil end
    return Vector2f.new( a.x + b.x, a.y + b.y )
end

---Subtract vector b from vector a and return a new vector result
---@param a Vector2f
---@param b Vector2f
---@return Vector2f
function Vector2f.sub( a, b )
    if not Vector2f.isVector2f( a ) then return nil end
    if not Vector2f.isVector2f( b ) then return nil end
    return Vector2f.new( a.x - b.x, a.y - b.y )
end

---Multiply the vector by the factor and return a new vector result
---@param a Vector2f
---@param f number
---@return Vector2f
function Vector2f.mul( a, f )
    if not Vector2f.isVector2f( a ) then return nil end
    if f == nil or type( f ) ~= "number" then return nil end
    return Vector2f.new( a.x * f, a.y * f )
end

---Divide the vector by the divisor and return a new vector result
---@param a Vector2f
---@param d number
---@return Vector2f
function Vector2f.div( a, d )
    if not Vector2f.isVector2f( a ) then return nil end
    if d == nil or type( d ) ~= "number" then return nil end
    return Vector2f.new( a.x / d, a.y / d )
end




---Vector dot product
---@param a Vector2f
---@param b Vector2f
---@return number
function Vector2f.dot( a, b )
    if not Vector2f.isVector2f( a ) then return nil end
    if not Vector2f.isVector2f( b ) then return nil end
    return ( a.x * b.x ) + ( a.y * b.y )
end


---Vector cross product
---@param a Vector2f
---@param b Vector2f
---@return number
function Vector2f.cross( a, b )
    if not Vector2f.isVector2f( a ) then return nil end
    if not Vector2f.isVector2f( b ) then return nil end
    return ( a.x * b.y ) - ( a.y * b.x )
end



---Return the length of this Vector2f
function Vector2f:length()
    return ( ( self.x * self.x ) + ( self.y * self.y ) ) ^ 0.5 -- oldest trick - factoring/multiplication is faster than sqrt/dividing
end


---Return the area of this Vector2f
function Vector2f:area()
    return self.x * self.y
end


---Return the angle (in radians) of this Vector2f
function Vector2f:angle()
    return math.atan2( self.x, self.y )
end


---Normalize this vector to a length of 1.0 (this vector cannot be a Vector2f.Zero)
function Vector2f:normalize()
    local length = self:length()
    if length > 0.0 then
        self:div( length )
    end
end




---Convert this Vector2f to { X, Y }
---@return table table{ X, Y }
function Vector2f:ToVector2F()
    return { X = self.x, Y = self.y }
end

---Convert from { v.X or v.x or v[1], ... }
---@return table table{ X, Y } or nil
function Vector2f.ToVector2F( v )
    if v == nil or type( v ) ~= "table" then return nil end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    if x == nil or y == nil then return nil end
    return { X = x, Y = y }
end

---Convert from { v.X or v.x or v[1], ... }
---@return Vector2f Vector2f or nil
function Vector2f.ToVector2f( v )
    if v == nil or type( v ) ~= "table" then return nil end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    if x == nil or y == nil then return nil end
    return Vector2f.new( x, y )
end

---Convert from { v.X or v.x or v[1], ... }
---@return array array[ 1, 2 ] or nil
function Vector2f.ToVectorArray( v )
    if v == nil or type( v ) ~= "table" then return nil end
    local x = v.x or v.X or v[ 1 ]
    local y = v.y or v.Y or v[ 2 ]
    if x == nil or y == nil then return nil end
    return { x, y }
end




return Vector2f