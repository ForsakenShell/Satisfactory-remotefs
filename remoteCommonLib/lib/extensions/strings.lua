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


---Extract a boolean from a string
---@param s string the string
---@param default boolean the default value if s does not equal "true" or "false" or isn't a string; default: nil
---@return boolean
function toboolean( s, default )
    if type( s ) == "string" then   -- never trust usercode, not even your own.
        s = string.lower( s )       -- also never trust the player, even yourself!
        if s == 'true' then return true end
        if s == 'false' then return false end
    end
    return default
end




