local ECS = {}

local Query, System, Component,  = ECS.Query, ECS.System, ECS.Component,


local Transform = Component({
   Position = Vector3.new(),
   Rotation = Vector3.new()
})

local IsActive = Component(nil, true)

local MovementSystem = System('proccess', 100, Query.All({Transform, IsActive}))

MovementSystem.After = {OtherSystem}
MovementSystem.Before = {TransformSystem}

function MovementSystem:Initialize()
   print("Initialized")
end

function MovementSystem:ShouldUpdate(Time)
   return true
end

function MovementSystem:PreUpdate(Time)
   return true
end

function MovementSystem:Update(Time, dirty)
   self:ForEach(function(entity)
      
   end)
end

function MovementSystem:PostUpdate(Time, interpolation)
   
end

function MovementSystem:OnEnter(time)
   local world = self.world
   local query = Query.All({IsActive})
   
   world:Exec(query):ForEach(function(entity)
      local transform = Transform()
      transform.Position = Vector3.new(50, 50, 50)

      entity:Set(transform)
      entity:Set(Transform, transform)
      entity[Transform] = transform

      local isActive = entity:Get(IsActive)
      local isActive = entity[IsActive]
   end)
end


local world = ECS.World({MovementSystem}, 60, false)
world:AddSystem(MovementSystem, 10, { types = 'xto' })
world:SetFrequency(30)

world:Destroy()


-- ShouldUpdate(time: number, interpolation:number): void
--    It allows informing if the update methods of this system should be invoked
-- BeforeUpdate(time: number, interpolation:number): void
--    Invoked before updating entities available for this system.
--    It is only invoked when there are entities with the characteristics
--    expected by this system
-- Update: function(time, dirty, entity, index, [component_N_items...]) -> boolean
--    Invoked in updates, limited to the value set in the "frequency" attribute
-- AfterUpdate(time: number, interpolation:number): void
-- OnEnter(time, entity, index, [component_N_items...]) -> boolean
-- OnExit(time, entity, index, [component_N_items...]) -> boolean
-- OnRemove(time, enity, index, [component_N_items...])







local Archetype1 = {}
local ComponentName = {}
local ComponentTransform = {}

local entity1 = {}
local entity2 = {}



local Entity = {}

function Entity.Create(world, ...)
   local components = {...}
end

function Entity:Get(cType)
   return self._data[cType]
end

function Entity:Set(cType, value)
   return self._data[cType]
end


entity1[ComponentName]
