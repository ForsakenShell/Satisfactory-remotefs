-- string class extension functions



---Split a string that is deliminated by the separator
---@param str string String to split
---@param sep string? Separator to split string by; default: ','
---@return table: Array of split string elements
function string.split( str, sep )
    local pattern = string.format( '([^%s]+)', sep or ',' )
    
    local results = {}
    local _ = string.gsub( str, pattern,
        function( c )
            results[ #results + 1 ] = c
        end )
    
    return results
end


