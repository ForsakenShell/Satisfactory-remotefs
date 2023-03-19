--- Created by Willis.
--- DateTime: 11/12/2021 11:39 pm
--- Class to represent Adjacency Matrix

local UPDATED = "22/02/2023 5:00pm"
print( "\nInitialising Adjacency Matrix\n\nLast Update: ".. UPDATED .. "\n" )

require( "/lib/PriorityQueue.lua" )


AdjacencyMatrix = {}
AdjacencyMatrix.__index = AdjacencyMatrix
setmetatable(AdjacencyMatrix, {__call = function(cls,...) return cls.new(...) end,})


local min_comparator = function(a, b)
    return b < a
end


---Constructor for Adjacency matrix
---@param n number: The size (n by n) of the matrix
function AdjacencyMatrix.new(n, debug)
    
    local self = setmetatable({}, AdjacencyMatrix)
    self.size = n
    self.mapping = {}
    self.__debug = debug

    local matrix = {}
    for i=1,n do
        matrix[i] = {}
        for j=1,n do
            matrix[i][j] = 0
        end
    end

    self.__adjacency_matrix = matrix
    return self
end


---Grows the AdjacencyMatrix to include the vertex
---@param vert number: The vertex in question
function AdjacencyMatrix:grow_to(vert)
    while self.size < vert do
        self:add_vertex()
    end
end


---Adds a new vertex
function AdjacencyMatrix:add_vertex()
    
    self.size = self.size + 1
    
    self.__adjacency_matrix[self.size] = {}
    
    for i=1, self.size do
        self.__adjacency_matrix[i][self.size] = 0
        self.__adjacency_matrix[self.size][i] = 0
    end
    
    
    return self.size
end


---Connect two vertices with an edge
---@param vert1 number: The first vertex
---@param vert2 number: The second vertex
---@param directed boolean: (default:true) This is a one way connection of vert1->vert2, do NOT connect vert2->vert1
function AdjacencyMatrix:connect( vert1, vert2, directed )
    directed = directed or true
    self:grow_to( vert1 )
    self:grow_to( vert2 )
    self.__adjacency_matrix[vert1][vert2] = 1
    if not directed then
        self.__adjacency_matrix[vert2][vert1] = 1
    end
end

function AdjacencyMatrix:reset_connections_for( vert, directed )
    directed = directed or true
    self:grow_to( vert )
    for i = 1, self.size do
        self.__adjacency_matrix[vert][i] = 0
        if not directed then
            self.__adjacency_matrix[i][vert] = 0
        end
    end
end


--- Assigns a location to the vertex
---@param vert number: value of the vertex
---@param location table: Table representation of x,y,z coordinates.
function AdjacencyMatrix:assign_location(vert, location)
    self:grow_to( vert )
    self.mapping[vert] = location
end


--- Get the weight between two vertices
---@param vert number: The vertex
---@return table: {vertex number, weight number}: Table with vertex-weight as key-value pair.
function AdjacencyMatrix:get_neighbours(vert)
    local neighbours = {}
    local counter = 1
    for i, value in ipairs(self.__adjacency_matrix[vert]) do
        if value == 1 then
            neighbours[counter] = i
            counter = counter + 1
        end
    end

    return neighbours
end



--- Calculates the euclidean distance between two vertices
---@param vert1 number: The first vertex
---@param vert2 number: The second vertex
---@return number: The euclidean distance
function AdjacencyMatrix:euclidean_dist(vert1, vert2)

    if self.__debug then
        print(vert1)
        print(vert2)
    end

    local v1 = self.mapping[vert1]
    local v2 = self.mapping[vert2]
    if self.__debug then
        print(v1)
        print(v2)
    end
    if v1 == nil or v2 == nil then
        return math.huge
    end
    -- vertex distance is the difference in their values, not the sum of - does Willis not know math?
    local result = math.sqrt( ( v1[ "x" ] - v2[ "x" ] ) ^ 2
                            + ( v1[ "y" ] - v2[ "y" ] ) ^ 2
                            + ( v1[ "z" ] - v2[ "z" ] ) ^ 2 )
    if self.__debug then
        print(result)
    end
    return result
end


--- Generates the shortest path to connect origin and target.
---@param origin number: The origin vertex
---@param target number: The end target vertex
---@return table: The vertices that connect origin to target (1 = target, ..., #path = origin)
function AdjacencyMatrix:generate_path(origin, target)
    
    self:grow_to( origin )
    self:grow_to( target )
    
    local previousNodes = self:A_star(origin, target)
    local path = {target}
    local current = target
    while previousNodes[current] ~= nil do
        current = previousNodes[current]
        path[#path + 1] = current
    end
    
    return path
end




--- Implements A* algorithm by use of pseudocode (https://en.wikipedia.org/wiki/A*_search_algorithm#Implementation_details)
---@param start number: The starting vertex
---@param goal number: The final destination
---@return table: A list that keeps track of all the previous nodes visited.
function AdjacencyMatrix:A_star(start, goal)

    local openSet = PriorityQueue.new(min_comparator)

    local previousNodes = {}
    local gScore = {}
    local fScore = {}
    setmetatable(gScore, {__index = function () return math.huge end})
    setmetatable(fScore, {__index = function () return math.huge end})

    gScore[start] = 0
    fScore[start] = self:euclidean_dist(start, goal)

    openSet:Add(start, fScore[start])

    while openSet:Size() ~= 0 do
        local current = openSet:Pop()
        if current == goal then
            return previousNodes
        end

        local neighbours = self:get_neighbours(current)

        for _, neighbour in ipairs(neighbours) do
            local tentative_gScore = gScore[current] + self:euclidean_dist(current, neighbour)
            if tentative_gScore < gScore[neighbour] then
                previousNodes[neighbour] = current
                gScore[neighbour] = tentative_gScore
                fScore[neighbour] = tentative_gScore + self:euclidean_dist(neighbour, goal)
                if not openSet:contains(neighbour) then
                    openSet:Add(neighbour, fScore[neighbour])
                end
            end
        end

    end
    return previousNodes
end



--- Prints the matrix out nicely
function AdjacencyMatrix:print()
    local spacer = "  "
    local col_header_format = "     "
    for i = 1, #self.__adjacency_matrix do
        col_header_format = col_header_format..i..spacer
    end
    print(col_header_format)

    for row in pairs(self.__adjacency_matrix) do
        local row_format = spacer
        row_format = row_format..row..spacer
        for _, value in ipairs(self.__adjacency_matrix[row]) do
            row_format = row_format..value..spacer
        end
        print(row_format)
    end
end
