local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

return ECS.Component('Firing', function(firedAt)
   if firedAt == nil then
      error("firedAt is required")
   end

   return firedAt
end)
