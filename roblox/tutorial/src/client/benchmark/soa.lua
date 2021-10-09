
local case = {
   name = 'Struct of Arrays vs. Array of Structs'
}

-- produce equal sequences of numbers for both tests
local RANDOM_SEED = os.time()

local Player = {}
Player.__index = Player

function Player.new(name, health, location, velocity, acceleration)
   return setmetatable({
      name = name,
      health = health,
      location = location,
      velocity = velocity,
      acceleration = acceleration,
   }, Player)
end

function case.genOOP(size)
   math.randomseed(RANDOM_SEED)
   local players = table.create(size)

   for i = 1, size do
      players[i] = Player.new(
         string.format("player_name_%s", i),
         100.0,
         {x = math.random(0, 10.0), y = math.random(0, 10.0)},
         {x = math.random(0, 10.0), y = math.random(0, 10.0)},
         {x = math.random(0, 10.0), y = math.random(0, 10.0)}
      )
   end

   return players
end

function case.genDOP(size)
   math.randomseed(RANDOM_SEED)

   local names = table.create(size)
   local health = table.create(size)
   local locations = table.create(size)
   local velocities = table.create(size)
   local accelerations = table.create(size)

   for i = 1, size do
      names[i]          = string.format("player_name_%s", i)
      health[i]         = 100.0
      locations[i]      = {math.random(0, 10.0), math.random(0, 10.0)}
      velocities[i]     = {math.random(0, 10.0), math.random(0, 10.0)}
      accelerations[i]  = {math.random(0, 10.0), math.random(0, 10.0)}
   end

   return {
      names = names,
      health = health,
      locations = locations,
      velocities = velocities,
      accelerations = accelerations
  }
end

function case.runOOP(players)
   for i, player in ipairs(players) do

      if player.location.x > 100 or  player.location.y > 100 then
         player.location = {x = 0, y = 0}
      end

      player.location = {
         x = player.location.x + player.velocity.x,
         y = player.location.y + player.velocity.y
      }

      if player.velocity.x > 100 or  player.velocity.y > 100 then
         player.velocity = {x = 0, y = 0}
      end
      
      player.velocity = {
         x = player.velocity.x + player.acceleration.x,
         y = player.velocity.y + player.acceleration.y
      }

   end
end

function case.runDOP(world)
   local locations = world.locations
   local velocities = world.velocities
   local accelerations = world.accelerations
   for i, location in ipairs(locations) do

      if location[1] > 100 or location[2] > 100 then
         locations[i] = {0, 0}
      end

      locations[i]  = {
         location[1] + velocities[i][1],
         location[2] + velocities[i][2]
      }

      if velocities[i][1] > 100 or velocities[i][2] > 100 then
         velocities[i] = {0, 0}
      end

      velocities[i]  = {
         velocities[i][1] + accelerations[i][1],
         velocities[i][2] + accelerations[i][2]
      }
   end
end

return case
