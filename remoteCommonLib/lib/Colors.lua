-- Colors!

if _G[ "____Color" ] ~= nil then return _G[ "____Color" ] end
local Color = {
    r = 0.0,
    g = 0.0,
    b = 0.0,
    a = 0.0,
    pattern = '{r=%1.6f,g=%1.6f,b=%1.6f,a=%1.6f}',
}
Color.__index = Color

_G[ "____Color" ] = Color




---Round a number
---@param a number
local function round( a )
    return math.floor( a + 0.5 )
end


---Clamp a number
local function clamp( x, min, max )
    if x < min then return min end
    if x > max then return max end
    return x
end

---Clamp a color channel
local function champ( c )
    return clamp( c, 0.0, 1.0 )
end



---Create a new Color and return it or nil on invalid input; channels will be clamped
---@param r number
---@param g number
---@param b number
---@param a number
---@return Color
function Color.new( r, g, b, a )
    if r == nil or type( r ) ~= "number" then return nil end
    if g == nil or type( g ) ~= "number" then return nil end
    if b == nil or type( b ) ~= "number" then return nil end
    if a == nil or type( a ) ~= "number" then return nil end
    local o = {
        r = champ( r ),
        g = champ( g ),
        b = champ( b ),
        a = champ( a ),
    }
    setmetatable( o, { __index = Color } )
    return o
end




---Tests whether the passed in variable is a Color
---@param c any
---@return boolean true if c is a Color, false otherwise
function Color.isColor( c )
    return c ~= nil
    and type( c ) == "table"
    and getmetatable( v ) ~= nil
    and getmetatable( v ).__index == Color
end




Color.BLACK             = Color.new( 0.000, 0.000, 0.000, 1.0 )
Color.WHITE             = Color.new( 1.000, 1.000, 1.000, 1.0 )
Color.GREY_0750         = Color.new( 0.750, 0.750, 0.750, 1.0 )
Color.GREY_0500         = Color.new( 0.500, 0.500, 0.500, 1.0 )
Color.GREY_0250         = Color.new( 0.250, 0.250, 0.250, 1.0 )
Color.GREY_0125         = Color.new( 0.125, 0.125, 0.125, 1.0 )



---Convert the Color to it's hex RGBA string equivalent; channels will be clamped
function Color:ToRGBA()
    local r = round( champ( self.r ) * 255.0 )
    local g = round( champ( self.g ) * 255.0 )
    local b = round( champ( self.b ) * 255.0 )
    local a = round( champ( self.a ) * 255.0 )
    return string.format( "%02x%02x%02x%02x", r, g, b, a )
end





---Are the two colors equal?  Compares after conversion to hex RGBA so floating point inaccuracies are flattened out
function Color:equals( other )
    if not Color.isColor( other ) then return false end
    return self:ToRGBA() == other:ToRGBA()
end


---Return this Color as a string using the supplied pattern or default Color.pattern
---@param pattern? string Optional pattern to use for string.format()
---@return string formatted string
function Color:ToString( pattern )
    pattern = pattern or self.pattern
    return string.format( pattern, self.r, self.g, self.b, self.a )
end

---Return the Color? as a string using the supplied pattern or default Color.pattern
---@param c table color
---@param pattern? string Optional pattern to use for string.format()
---@return string formatted string
function Color.ToString( c, pattern )
    if c == nil then return 'nil' end
    local vt = type( v )
    if vt ~= "table" and vt ~= "userdata" then return 'invalid' end
    local r = c.r or c.R or c[ 1 ]
    local g = c.g or c.G or c[ 2 ]
    local b = c.b or c.B or c[ 3 ]
    local a = c.a or c.A or c[ 4 ]
    if r == nil or type( r ) ~= "number"
    or g == nil or type( g ) ~= "number"
    or b == nil or type( b ) ~= "number"
    or a == nil or type( a ) ~= "number"
    then return 'invalid' end
    pattern = pattern or Color.pattern
    return string.format( pattern, r, g, b, a )
end




---Convert a color from { c.R or c.r or c[1], ... } to { R=, G=, B=, A= }; channels will be clamped
function Color.ToCOLOR( c )
    if c == nil or type( c ) ~= "table" then return nil end
    local r = c.r or c.R or c[ 1 ]
    local g = c.g or c.G or c[ 2 ]
    local b = c.b or c.B or c[ 3 ]
    local a = c.a or c.A or c[ 4 ]
    if r == nil or type( r ) ~= "number"
    or g == nil or type( g ) ~= "number"
    or b == nil or type( b ) ~= "number"
    or a == nil or type( a ) ~= "number"
    then return nil end
    return { R = champ( r ), G = champ( g ), B = champ( b ), A = champ( a ) }
end
---Convert a color from { c.R or c.r or c[1], ... } to { r=, g=, b=, a= }; channels will be clamped
function Color.Tocolor( c )
    local r = c.r or c.R or c[ 1 ]
    local g = c.g or c.G or c[ 2 ]
    local b = c.b or c.B or c[ 3 ]
    local a = c.a or c.A or c[ 4 ]
    if r == nil or type( r ) ~= "number"
    or g == nil or type( g ) ~= "number"
    or b == nil or type( b ) ~= "number"
    or a == nil or type( a ) ~= "number"
    then return nil end
    return { r = champ( r ), g = champ( g ), b = champ( b ), a = champ( a ) }
end
---Convert a color from { c.R or c.r or c[1], ... } to an array { [1]=, [2]=, [3]=, [4]= }; channels will be clamped
function Color.ToColorArray( c )
    local r = c.r or c.R or c[ 1 ]
    local g = c.g or c.G or c[ 2 ]
    local b = c.b or c.B or c[ 3 ]
    local a = c.a or c.A or c[ 4 ]
    if r == nil or type( r ) ~= "number"
    or g == nil or type( g ) ~= "number"
    or b == nil or type( b ) ~= "number"
    or a == nil or type( a ) ~= "number"
    then return nil end
    return { champ( r ), champ( g ), champ( b ), champ( a ) }
end




return Color