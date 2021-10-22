
local Utility = {}

function Utility.map(x, inMin, inMax, outMin, outMax)
   return (x - inMin)*(outMax - outMin)/(inMax - inMin) + outMin
end

function Utility.lerp(v0, v1, t)
   return (1-t)*v0 + t*v1
end

return Utility
