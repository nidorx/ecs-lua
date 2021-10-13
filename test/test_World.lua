local lu = require('luaunit')

local World = require('World')
local Query = require('Query')
local System = require('System')
local Component = require('Component')

-- mock
World.LoopManager = {
   Register = function(world)
      return function ()
         
      end
   end
}


TestWorld = {}

function TestWorld:test_SystemWhitoutQuery()
   local Comp_A = Component.Create(0)
   local Comp_B = Component.Create(0)
   local Comp_C = Component.Create(0)
   local Comp_D = Component.Create(0)

   local calledInitialize = 0
   local calledShouldUpdate = 0
   local calledUpdate = 0
   local calledOnEnter = 0
   local calledOnExit = 0
   local calledOnRemove = 0
   local calledOnDestroy = 0
   
   local systemConfig = { value = 1 }


   lu.assertError(function()
      -- empty step
      System.Create()
   end)

   lu.assertError(function()
      -- invalid step
      System.Create('xpto')
   end)

   local System_A = System.Create('process', 1, function()
      calledUpdate = calledUpdate + 1
   end)

   function System_A:Initialize()
      calledInitialize = calledInitialize + 1
      lu.assertEquals(self._config, systemConfig)
      lu.assertEquals(self.GetType(), System_A)
   end

   function System_A:ShouldUpdate(config)
      calledShouldUpdate = calledShouldUpdate + 1
      return true
   end

   function System_A:OnEnter(Time, entity)
      calledOnEnter = calledOnEnter + 1
   end

   function System_A:OnExit(Time, entity)
      calledOnExit = calledOnExit + 1
   end

   function System_A:OnRemove(Time, entity)
      calledOnRemove = calledOnRemove + 1
   end

   function System_A:OnDestroy()
      calledOnDestroy = calledOnDestroy + 1
   end


   local System_B = System.Create('transform', -100, Query.All(Comp_B))

   function System_B:OnEnter(Time, entity)
      calledOnEnter = calledOnEnter + 1
   end

   function System_B:OnExit(Time, entity)
      calledOnExit = calledOnExit + 1
   end

   function System_B:OnRemove(Time, entity)
      calledOnRemove = calledOnRemove + 1
   end

   function System_B:OnDestroy()
      calledOnDestroy = calledOnDestroy + 1
   end

   
   local world = World.New({System_B}, 60)
   world:AddSystem(System_A, systemConfig)


   local entityC = world:Entity(Comp_C(1))

   local System_C = System.Create('transform', 20, Query.All(Comp_C))

   function System_C:Update(Time)
      calledUpdate = calledUpdate + 1
      lu.assertItemsEquals(self:Result():ToArray(), {entityC})
   end

   world:AddSystem(System_C)
   

   lu.assertEquals(world:GetFrequency() , 60)
   
   world:SetFrequency(30) 
   lu.assertEquals(world:GetFrequency() , 30)

   lu.assertEquals(calledInitialize, 1)
   lu.assertEquals(calledShouldUpdate, 0)
   lu.assertEquals(calledUpdate, 0)
   lu.assertEquals(calledOnEnter, 0)
   lu.assertEquals(calledOnExit, 0)
   lu.assertEquals(calledOnRemove, 0)

   world:Update('process', 0.0334 * 1)
   world:Update('transform', 0.0335 * 1 + 0.001)
   world:Update('render', 0.0336 * 1 + 0.002)
   lu.assertEquals(calledInitialize, 1)
   lu.assertEquals(calledShouldUpdate, 1)
   lu.assertEquals(calledUpdate, 2)
   lu.assertEquals(calledOnEnter, 0)
   lu.assertEquals(calledOnExit, 0)
   lu.assertEquals(calledOnRemove, 0)
   

   local entityA = world:Entity(Comp_A(1))
   world:Update('process', 0.0334 * 2)
   world:Update('transform', 0.0335 * 2 + 0.001)
   world:Update('render', 0.0336 * 2 + 0.002)
   lu.assertEquals(calledInitialize, 1)
   lu.assertEquals(calledShouldUpdate, 2)
   lu.assertEquals(calledUpdate, 4)
   lu.assertEquals(calledOnEnter, 0)
   lu.assertEquals(calledOnExit, 0)
   lu.assertEquals(calledOnRemove, 0)
   lu.assertItemsEquals(world:Exec(Query.All(Comp_A)):ToArray(), {entityA})
   lu.assertItemsEquals(world:Exec(Query.All(Comp_B)):ToArray(), {})


   local entityB = world:Entity(Comp_B(1))
   world:Update('process', 0.0334 * 3)
   local entityD = world:Entity(Comp_D(1))
   world:Update('transform', 0.0335 * 3 + 0.001)
   world:Update('render', 0.0336 * 3 + 0.002)
   lu.assertEquals(calledInitialize, 1)
   lu.assertEquals(calledShouldUpdate, 3)
   lu.assertEquals(calledUpdate, 6)
   lu.assertEquals(calledOnEnter, 1)
   lu.assertEquals(calledOnExit, 0)
   lu.assertEquals(calledOnRemove, 0)
   lu.assertItemsEquals(world:Exec(Query.All(Comp_A)):ToArray(), {entityA})
   lu.assertItemsEquals(world:Exec(Query.All(Comp_B)):ToArray(), {entityB})
  
   entityA[Comp_B] = {value = 2}
   world:Update('process', 0.0334 * 4)
   world:Update('transform', 0.0335 * 4 + 0.001)
   world:Update('render', 0.0336 * 4 + 0.002)
   lu.assertEquals(calledInitialize, 1)
   lu.assertEquals(calledShouldUpdate, 4)
   lu.assertEquals(calledUpdate, 8)
   lu.assertEquals(calledOnEnter, 2)
   lu.assertEquals(calledOnExit, 0)
   lu.assertEquals(calledOnRemove, 0)
   lu.assertItemsEquals(world:Exec(Query.All(Comp_A)):ToArray(), {entityA})
   lu.assertItemsEquals(world:Exec(Query.All(Comp_B)):ToArray(), {entityA, entityB})

   entityA[Comp_B] = nil
   world:Update('process', 0.0334 * 5)
   world:Update('transform', 0.0335 * 5 + 0.001)
   world:Update('render', 0.0336 * 5 + 0.002)
   lu.assertEquals(calledInitialize, 1)
   lu.assertEquals(calledShouldUpdate, 5)
   lu.assertEquals(calledUpdate, 10)
   lu.assertEquals(calledOnEnter, 2)
   lu.assertEquals(calledOnExit, 1)
   lu.assertEquals(calledOnRemove, 0)
   lu.assertItemsEquals(world:Exec(Query.All(Comp_A)):ToArray(), {entityA})
   lu.assertItemsEquals(world:Exec(Query.All(Comp_B)):ToArray(), {entityB})

   world:Remove(entityA)
   world:Remove(entityA) -- no result
   world:Update('process', 0.0334 * 6)
   world:Update('transform', 0.0335 * 6 + 0.001)
   world:Update('render', 0.0336 * 6 + 0.002)
   lu.assertEquals(calledInitialize, 1)
   lu.assertEquals(calledShouldUpdate, 6)
   lu.assertEquals(calledUpdate, 12)
   lu.assertEquals(calledOnEnter, 2)
   lu.assertEquals(calledOnExit, 1)
   lu.assertEquals(calledOnRemove, 0)
   lu.assertItemsEquals(world:Exec(Query.All(Comp_A)):ToArray(), {})
   lu.assertItemsEquals(world:Exec(Query.All(Comp_B)):ToArray(), {entityB})

   world:Remove(entityB)
   world:Update('process', 0.0334 * 7)
   world:Update('transform', 0.0335 * 7 + 0.001)
   world:Update('render', 0.0336 * 7 + 0.002)
   lu.assertEquals(calledInitialize, 1)
   lu.assertEquals(calledShouldUpdate, 7)
   lu.assertEquals(calledUpdate, 14)
   lu.assertEquals(calledOnEnter, 2)
   lu.assertEquals(calledOnExit, 1)
   lu.assertEquals(calledOnRemove, 1)
   lu.assertItemsEquals(world:Exec(Query.All(Comp_A)):ToArray(), {})
   lu.assertItemsEquals(world:Exec(Query.All(Comp_B)):ToArray(), {})

   -- add and remove before update
   local entityB = world:Entity(Comp_B(1))
   world:Remove(entityB)
   world:Update('process', 0.0334 * 8)
   world:Update('transform', 0.0335 * 8 + 0.001)
   world:Update('render', 0.0336 * 8 + 0.002)
   lu.assertEquals(calledInitialize, 1)
   lu.assertEquals(calledShouldUpdate, 8)
   lu.assertEquals(calledUpdate, 16)
   lu.assertEquals(calledOnEnter, 2)
   lu.assertEquals(calledOnExit, 1)
   lu.assertEquals(calledOnRemove, 1)
   lu.assertEquals(calledOnDestroy, 0)
   lu.assertItemsEquals(world:Exec(Query.All(Comp_A)):ToArray(), {})
   lu.assertItemsEquals(world:Exec(Query.All(Comp_B)):ToArray(), {})
   
   
   world:Destroy()
   lu.assertEquals(calledOnDestroy, 2)

end
