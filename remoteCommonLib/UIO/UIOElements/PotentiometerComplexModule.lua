-- UI class for dealing with "Complex" Potentiometer Modules


local UIO = require( "/UIO/UIO.lua", EEPROM.Remote.CommonLib )
if UIO.UIOElements.PotentiometerComplexModule ~= nil then return UIO.UIOElements.PotentiometerComplexModule end


local ClassGroup = require( "/lib/classgroups.lua", EEPROM.Remote.CommonLib )




---@class PotentiometerComplexModule:UIOElement
local PotentiometerComplexModule = UIO.UIOElement.template(
    "PotentiometerComplexModule",
    ClassGroup.Modules.Potentiometers.Complex.All,
    { "valueChanged" },
    {
        -- Class Constants
        -- Instance data
        ____setColor = function( proxy, r, g, b, a ) end,
    }
)
UIO.UIOElements.PotentiometerComplexModule = PotentiometerComplexModule




-- The core functions of a UIOElement this can handle


function PotentiometerComplexModule:setForeColor( color )
    self.____setColor( self.target, color.r, color.g, color.b, color.a )
end


function PotentiometerComplexModule:setValue( value )
    self.target.value = value
end
function PotentiometerComplexModule:getValue()
    return self.target.value
end


function PotentiometerComplexModule:setMin( min )
    self.target.min = min
end
function PotentiometerComplexModule:getMin()
    return self.target.min
end


function PotentiometerComplexModule:setMax( max )
    self.target.max = max
end
function PotentiometerComplexModule:getMax()
    return self.target.max
end




---Create an UIO.UIOElement for a Panel Button Module
---@param potentiometer userdata The potentiometer
---@return PotentiometerComplexModule The UIOElement or nil
function PotentiometerComplexModule.create( potentiometer )
    local uio = UIO.UIOElement.create(
        PotentiometerComplexModule,
        potentiometer,
        {
        }
    )
    if uio == nil then return nil end
    
    local sc = potentiometer[ "setColor" ]
    if sc ~= nil then
        uio.____setColor = sc
    end
    
    return uio
end




return PotentiometerComplexModule