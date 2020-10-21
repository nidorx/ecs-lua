local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

return ECS.Component.register('Firing', function(data)
   if data == nil then
      error("Data is required")
   end

   if data.FiredAt == nil then
      error("FiredAt is required")
   end

   return data
end)