local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

return ECS.RegisterComponent('Firing', function(firedAt)
   if firedAt == nil then
      error("firedAt is required")
   end

   return firedAt
end)