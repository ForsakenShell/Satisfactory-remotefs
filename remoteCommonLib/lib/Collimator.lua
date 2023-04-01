local Collimator = _G[ "____Collimator" ]
if Collimator ~= nil then return Collimator end


local __DebugMode = true




local utf8 = require( "/lib/utf8.lua", ____RemoteCommonLib )




local function Common_Test_ValidColor( meta, value )
    if value.r == nil or type( value.r ) ~= "number" then return false, meta.name .. " is not a valid Color" end
    if value.g == nil or type( value.g ) ~= "number" then return false, meta.name .. " is not a valid Color" end
    if value.b == nil or type( value.b ) ~= "number" then return false, meta.name .. " is not a valid Color" end
    if value.a == nil or type( value.a ) ~= "number" then return false, meta.name .. " is not a valid Color" end
    return true, nil
end


local ClassMeta = nil
if __DebugMode then
    ClassMeta = require( "/lib/ClassMeta.lua", ____RemoteCommonLib )
end



---Column layout and data resolution for the Collimator
---@class Column:table
---@field header string name of the Column
---@field width integer width in character columns of the Column
---@field fcolor Color foreground color for drawText
---@field bcolor Color background color for drawText
---@field sep string character to separate child table results returned by resolver
---@field resolver function function( source: table|userdata ): string|table, color|table, color|table
local Column = {
    header = 'column',
    width = 8,
    fcolor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    bcolor = { r = 0.0, g = 0.0, b = 0.0, a = 1.0 },
    sep = ' ',
    resolver = function( source ) return nil, nil, nil end,
}
Column.__index = Column


local Column_MetaData = nil
if __DebugMode then
    Column_MetaData = ClassMeta.new( {
        metatablename = "Column",
        metatable = Column,
        fields = {
            ClassMeta.FieldMeta.new( { name = "header", ftype = "string" } ),
            ClassMeta.FieldMeta.new( { name = "width", ftype = "number", valuetest = ClassMeta.FieldMeta.Common.Test_Integer_Positive } ),
            ClassMeta.FieldMeta.new( { name = "fcolor", ftype = "table", allownil = true, valuetest = Common_Test_ValidColor } ),
            ClassMeta.FieldMeta.new( { name = "bcolor", ftype = "table", allownil = true, valuetest = Common_Test_ValidColor } ),
            ClassMeta.FieldMeta.new( { name = "sep", ftype = "string", allownil = true } ),
            ClassMeta.FieldMeta.new( { name = "resolver", ftype = "function", allownil = true } ),
        }
    } )
end

function Column.new( o )
    if __DebugMode then
        local result, reason = Column_MetaData:isValid( 'o', o, false )
        if not result then return nil, reason end
    end
    setmetatable( o, { __index = Column } )
    return o
end






---This class will take a set of data and collimate it
---@class Collimator:table
---@field columns array array of Columns
---@field padding integer additional spaces between columns
---@field maxWidth integer maximum string length returned by xxxToString functions
---@field drawText function Draw the text at the coordinates with the colors
local Collimator = {
    columns = {},
    padding = 0,
    maxWidth = math.huge,
    drawText = function( x, y, text, fcolor, bcolor ) end,
}
Collimator.__index = Collimator
_G[ "____Collimator" ] = Collimator


local function Collimator_Test_ValidColumns( meta, value )
    if #value == 0 then return false, meta.name .. " array is empty" end
    if #value ~= table.countKeyValuePairs( value ) then return false, meta.name .. " is not a completely sequential array" end
    for k, v in pairs( value ) do
        local result, reason = Column_MetaData:isValid( string.format( "%s[ %s ]", meta.name, tostring( k ) ), v, true )
        if not result then return false, reason end
    end
    return true, nil
end


local Collimator_MetaData = nil
if __DebugMode then
    Collimator_MetaData = ClassMeta.new( {
        metatablename = "Collimator",
        metatable = Collimator,
        fields = {
            ClassMeta.FieldMeta.new( { name = "columns", ftype = "table", valuetest = Collimator_Test_ValidColumns } ),
            ClassMeta.FieldMeta.new( { name = "padding", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Integer_NotNegative } ),
            ClassMeta.FieldMeta.new( { name = "maxWidth", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Integer_NotNegative } ),
            ClassMeta.FieldMeta.new( { name = "drawText", ftype = "function", allownil = true } ),
        }
    } )
end




---Create a new Collimator
---@param o table Table to use as the Collimator, must pass Collimator_MetaData:isValid( o, false )
---@return Collimator, string Collimator, nil on success; nil, reason on error
function Collimator.new( o )
    if __DebugMode then
        local result, reason = Collimator_MetaData:isValid( 'o', o, false )
        if not result then return nil, reason end
    end
    o.__size = #o.columns
    setmetatable( o, { __index = Collimator } )
    return o, nil
end


---Get the size (number of columns) of this Collimator
function Collimator:getSize()
    return self.__size
end




---@param column Column
---@param source any
---@return string|table, color|table, color|table
local function resolveCell( column, source )
    local data = ''
    local fcolor = column.fcolor
    local bcolor = column.bcolor
    
    if source == nil then
        return data, fcolor, bcolor
    end
    
    local resolver = column.resolver
    local dtype = type( source )
    
    if resolver ~= nil and( dtype == "table" or dtype == "userdata" )then
        local fdata, ffcolor, fbcolor  = resolver( source )
        if fdata ~= nil then
            local ftype = type( fdata )
            if ftype == "string" then
                data = fdata
            elseif ftype == "number" then
                data = tostring( fdata )
            elseif ftype == "boolean" then
                data = tostring( fdata )
            elseif ftype == "table" then
                data = fdata
            end
        end
        if ffcolor ~= nil then fcolor = ffcolor end
        if fbcolor ~= nil then bcolor = fbcolor end
        
    else
        if dtype == "string" then
            data = source
        elseif dtype == "number" then
            data = tostring( source )
        elseif dtype == "boolean" then
            data = tostring( source )
        elseif dtype == "table" then
            data = source
        else
            data = 'Unhandled'
            print( 'Collimator - resolveCell() - Unhandled data type: "' .. dtype .. '"' )
        end
        
    end
    
    return data, fcolor, bcolor
end




---Builds the entire collimated row string; this function does not support returning colors for the parts of the collimated data
---@param self Collimator
---@param nextColumnData function function( i:integer ): string
local function dataToString( self, nextColumnData )
    local size =  self.__size
    local result = ''
    local total = 0
    local colPad = self.padding
    local maxWidth = self.maxWidth
    local columns = self.columns
    
    for i = 1, size do
        local column = columns[ i ]
        
        local colWid = column.width
        if total + colWid > maxWidth then
            colWid = maxWidth - total
        end
        
        local data, fcolor, bcolor = resolveCell( column, nextColumnData( i ) )
        if type( data ) == "table" then
            data = table.concat( data, column.sep )
        end
        
        -- Truncate the string to the column width
        local text = ''
        local tLen = 0
        if data ~= '' then
            tLen = utf8.len( data )
            if tLen > colWid then
                text = utf8.sub( data, 1, colWid )
                tLen = colWid
            else
                text = data
            end
        end
        
        -- Add the string and padding to get to the next column
        result = result .. text .. string.rep( ' ', colWid - tLen )
        
        if colPad > 0 and i < size then
            result = result .. string.rep( ' ', colPad )
        end
        
        total = total + colWid
        if total >= maxWidth then break end
    end
    
    -- Columnated data for display
    return result
end




---Internal resolver for column headers
local function resolveHeader( column )
    -- Centre the header in the column space
    local text = column.header
    local colWid = column.width
    local tLen = utf8.len( text )
    local d = colWid - tLen
    if d > 2 then
        local h = d >> 1
        text = string.rep( ' ', h ) .. text
    end
    return text
end


---Get a collimated string of the headers
function Collimator:headersToString()
    if self.__headers == nil then
        -- Do it once, cuz it's slow
        self.__headers = dataToString( self, function( i ) return resolveHeader( self.columns[ i ] ) end )
    end
    return self.__headers
end


---Collimate an array (indexed table), must be same length as Collimator:getSize()
---@param array array Indexed table to collimate
---@return string collimated results
function Collimator:arrayToString( array )
    local size =  self.__size
    if array == nil or type( array ) ~= "table" or #array ~= size then return nil end
    return dataToString( self, function( i ) return array[ i ] end )
end

---Collimate a table (or userdata, resolvers must be valid for this Collimator
---@param t table Table to collimate
---@return string collimated results
function Collimator:tableToString( t )
    local size =  self.__size
    local tv = type( t )
    if t == nil or( tv ~= "table" and tv ~= "userdata" )then return nil end
    return dataToString( self, function( i ) return t end )
end








---Draw an individual text component of the data for this cell
---@param drawText function drawText( x, y, text, fcolor, bcolor )
---@param width integer maximum text length to draw (the actual text drawn will be truncated to this)
local function drawSubText( drawText, x, y, width, t, fcolor, bcolor )
    -- Truncate the string the column width
    if width <= 0 then return x, 0 end
    
    local text = ''
    local tLen = 0
    if t ~= '' then
        tLen = utf8.len( t )
        if tLen > width then
            text = utf8.sub( t, 1, width )
            tLen = width
        else
            text = t
        end
    end
    
    drawText( x, y, text, fcolor, bcolor )
    
    return x + tLen, width - tLen
end


---Draw a set of text components of the data for this cell
---@param drawText function drawText( x, y, text, fcolor, bcolor )
---@param width integer maximum text length to draw (the actual text drawn will be truncated to this)
local function drawSubArray( drawText, x, y, width, array, fcolor, bcolor, sep )
    
    local farray = type( fcolor ) == "table" and fcolor[ "r" ] == nil and fcolor[ 1 ] ~= nil and fcolor[ 1 ][ "r" ] ~= nil
    local barray = type( bcolor ) == "table" and bcolor[ "r" ] == nil and bcolor[ 1 ] ~= nil and bcolor[ 1 ][ "r" ] ~= nil
    
    local function getColors( idx )
        local dfc = fcolor
        local dbc = bcolor
        if farray then dfc = fcolor[ idx ] end
        if barray then dbc = bcolor[ idx ] end
        return dfc, dbc
    end
    
    for idx, data in pairs( array ) do
        local dtype = type( data )
        
        local dfc, dbc = getColors( idx )
        
        if idx > 1 then
            -- Insert the separator
            x, width = drawSubText( drawText, x, y, width, sep, dfc, dbc )
        end
        
        if dtype == "table" then
            x, width = drawSubArray( drawText, x, y, width, data, dfc, dbc, sep )
            
        elseif dtype == "string" then
            x, width = drawSubText( drawText, x, y, width, data, dfc, dbc )
            
        elseif dtype == "number" then
            x, width = drawSubText( drawText, x, y, width, tostring( data ), dfc, dbc )
            
        elseif dtype == "boolean" then
            x, width = drawSubText( drawText, x, y, width, tostring( data ), dfc, dbc )
            
        end
    end
    
    return x, width
end


---Draw all the collimated text components with optional individual colors
---@param self Collimator
---@param nextColumnData function function( i:integer ): string
local function drawData( self, x, y, nextColumnData )
    local size =  self.__size
    local colPad = self.padding
    local maxWidth = self.maxWidth
    local drawText = self.drawText
    local columns = self.columns
    
    for i = 1, size do
        local column = columns[ i ]
        
        local colWid = column.width
        if x + colWid > maxWidth then
            colWid = maxWidth - x
        end
        
        local data, fcolor, bcolor = resolveCell( column, nextColumnData( i ) )
        local dtype = type( data )
        if dtype == "table" then
            drawSubArray( drawText, x, y, colWid, data, fcolor, bcolor, column.sep )
            
        elseif dtype == "string" then
            drawSubText( drawText, x, y, colWid, data, fcolor, bcolor )
            
        elseif dtype == "number" then
            drawSubText( drawText, x, y, colWid, tostring( data ), fcolor, bcolor )
            
        elseif dtype == "boolean" then
            drawSubText( drawText, x, y, colWid, tostring( data ), fcolor, bcolor )
            
        end
        
        x = x + colWid + colPad
        if x >= maxWidth then break end
    end
    
end




---Draw the collimated headers
function Collimator:drawHeaders( x, y )
    drawData( self, x, y, function( i ) return resolveHeader( self.columns[ i ] ) end )
end


---Draw a collimated array (indexed table), must be same length as Collimator:getSize()
---@param x integer 
---@param y integer 
---@param array array Indexed table to collimate; array may be string or child tables that can be resolved (requires valid Column resolvers)
function Collimator:drawArray( x, y, array )
    local size =  self.__size
    if array == nil or type( array ) ~= "table" or #array ~= size then return end
    drawData( self, x, y, function( i ) return array[ i ] end )
end


---Draw a collimated table (or userdata), resolvers must be valid for this Collimator
---@param t table Table to collimate
---@return string collimated results
function Collimator:drawTable( x, y, t )
    local tv = type( t )
    if t == nil or( tv ~= "table" and tv ~= "userdata" )then return nil end
    drawData( self, x, y, function( i ) return t end )
end




Collimator.Column = Column
return Collimator