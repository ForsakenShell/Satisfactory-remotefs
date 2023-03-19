-- table extension functions




---Search through a table looking for the value and return the key, a bit bassakwards, sye
---@param t table
---@param value any
---@return any?: The key
function table.getKey( t, value )
    if t == nil or value == nil then
        return nil
    end
    
    for k, v in pairs( t ) do
        if v == value then
            return k
        end
    end
    
    return nil
end



---Can the given value be found in a table of { key, values } ?
---@param t table
---@param value any
---@return boolean
function table.hasValue( t, value )
    if t == nil or value == nil then
        return false
    end
    
    for _,v in pairs( t ) do
        if v == value then
            return true
        end
    end
    
    return false
end



---Counts how many key, value pairs as in an unindexed table.
-- Why would you want this?  Because sometimes you want to know how big an unindexed table is
---@param t table
---@return integer
function table.countKeyValuePairs( t )
    if t == nil or type( t ) ~= "table" then return 0 end
    local count = 0
    for k, v in pairs( t ) do
        count = count + 1
    end
    return count
end


---Gets the key, value at the indexed position.
---Why would you want to do this?  I don't know, it's your code.
---@param t table
---@param i integer
---@return any? key or nil
---@return any? value or nil
function table.getKeyValuePairByIndex( t, i )
    if t == nil or type( t ) ~= "table" then return nil, nil end
    local count = 0
    for k, v in pairs( t ) do
        count = count + 1
        if count == i then
            return k, v
        end
    end
    return nil, nil
end




---Create a new table by taking every key,value in one table and casting the value tonumber() for that key in the new table.
---@param t table tonumber() may result in nil or missing fields in the new table
---@return table: New able where all the keys will only have a number value
function table.tonumber( t )
    local result = {}
    for k,v in pairs( t ) do
        result[ k ] = tonumber( v )
    end
    return result
end



---Merges the key, values of t2 into t1
---@param t1 table
---@param t2 table
---@param m boolean?: Merge matching keys (default: true) or ignore matching keys (false: t1 will be preserved)
function table.merge( t1, t2, m )
    if t1 == nil or type( t1 ) ~= "table" then return end
    if t2 == nil or type( t2 ) ~= "table" then return end
    if m == nil or type( m ) ~= "boolean" then
        m = true
    end
    for k, v in pairs( t2 ) do
        if not m and t1[ k ] ~= nil then
        else
            -- Always merge or doesn't exist
            t1[ k ] = v
        end
    end
end

---Merges the values of t2 into t1
---@param t1 table
---@param t2 table
function table.imerge( t1, t2 )
    if t1 == nil or type( t1 ) ~= "table" then return end
    if t2 == nil or type( t2 ) ~= "table" then return end
    for _, v in ipairs( t2 ) do
        table.insert( t1, v )
    end
end



