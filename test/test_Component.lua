local lu = require('luaunit')

function sleep(a)
   local sec = tonumber(os.clock() + a); 
   while (os.clock() < sec) do 
   end 
end

local Component = require('Component')

TestComponent = {}

-- function TestComponent:setUp()      
--    self.em = EntityManager.New()
-- end

function TestComponent:test_GetType()
   local Comp_A = Component.Create()
   local Comp_B = Component.Create()
   local Comp_C = Component.Create()

   local comp_a = Comp_A()
   local comp_b = Comp_B()
   local comp_c = Comp_C()

   lu.assertEquals(comp_a:GetType(), Comp_A)
   lu.assertEquals(comp_b:GetType(), Comp_B)
   lu.assertEquals(comp_c:GetType(), Comp_C)
end

function TestComponent:test_Value()

   local ComponentClass = Component.Create("foo")

   local component1 = ComponentClass()
   local component2 = ComponentClass("bar")

   lu.assertEquals(component1.value, "foo")
   lu.assertEquals(component2.value, "bar")
end

function TestComponent:test_Should_UseTemplate_Table()

   local ComponentClass = Component.Create({
      Level1 = {
         Level2 = {
            Level3 = {
               value = 00
            }
         }
      }
   })

   local component1 = ComponentClass()
   local component2 = ComponentClass()

   lu.assertEquals(component1.Level1.Level2.Level3.value, 00)
   lu.assertEquals(component2.Level1.Level2.Level3.value, 00)

   component1.Level1.Level2.Level3.value = 11
   component2.Level1.Level2.Level3.value = 22

   lu.assertEquals(component1.Level1.Level2.Level3.value, 11)
   lu.assertEquals(component2.Level1.Level2.Level3.value, 22)


   lu.assertEquals(component1:GetType(), ComponentClass)
end

function TestComponent:test_Should_UseTemplate_Function()

   local ComponentClass = Component.Create(function()
      return {
         Level1 = {
            Level2 = {
               Level3 = {
                  value = 00
               }
            }
         }
      }
   end)

   local component1 = ComponentClass()
   local component2 = ComponentClass()

   lu.assertEquals(component1.Level1.Level2.Level3.value, 00)
   lu.assertEquals(component2.Level1.Level2.Level3.value, 00)

   component1.Level1.Level2.Level3.value = 11
   component2.Level1.Level2.Level3.value = 22

   lu.assertEquals(component1.Level1.Level2.Level3.value, 11)
   lu.assertEquals(component2.Level1.Level2.Level3.value, 22)
end

function TestComponent:test_Should_CreateQualifier()

   local HealthBuff = Component.Create({ Percent = 0 })
   local HealthBuffLevel = HealthBuff.Qualifier("Level")
   local HealthBuffMission = HealthBuff.Qualifier("Mission")
   
   -- same object
   local HealthBuffMissionCopy1 = HealthBuff.Qualifier("Mission")
   local HealthBuffMissionCopy2 = HealthBuffMission.Qualifier("Mission")
   local HealthBuffMissionCopy3 = HealthBuff.Qualifier(HealthBuffMissionCopy1)
   lu.assertEquals(HealthBuffMission, HealthBuffMissionCopy1)
   lu.assertEquals(HealthBuffMission, HealthBuffMissionCopy2)
   lu.assertEquals(HealthBuffMission, HealthBuffMissionCopy3)


   local OtherComponent = Component.Create({ Percent = 0 })
   lu.assertIsNil(HealthBuff.Qualifier(OtherComponent))
   lu.assertIsNil(HealthBuff.Qualifier({}))

   lu.assertItemsEquals(HealthBuff.Qualifiers(), {HealthBuff, HealthBuffLevel, HealthBuffMission})
   lu.assertItemsEquals(HealthBuffLevel.Qualifiers(), {HealthBuff, HealthBuffLevel, HealthBuffMission})
   lu.assertItemsEquals(HealthBuffMission.Qualifiers(), {HealthBuffLevel, HealthBuffMission, HealthBuff })

   lu.assertItemsEquals(HealthBuff.Qualifiers("Level", "Mission"), {HealthBuffLevel, HealthBuffMission})
   lu.assertItemsEquals(HealthBuffLevel.Qualifiers("Primary", "Mission"), {HealthBuff, HealthBuffMission})
   lu.assertItemsEquals(HealthBuffMission.Qualifiers("Primary", "Level"), {HealthBuff, HealthBuffLevel })

   local function mergeCase(mergeFn)      
      local buff = HealthBuff()
      local buffLevel = HealthBuffLevel()
      local buffMission = HealthBuffMission()

      lu.assertEquals(buff:GetType(), HealthBuff)
      lu.assertEquals(buffLevel:GetType(), HealthBuffLevel)
      lu.assertEquals(buffMission:GetType(), HealthBuffMission)

      lu.assertIsTrue(buff:Is(HealthBuff))
      lu.assertIsTrue(buffLevel:Is(HealthBuff))
      lu.assertIsTrue(buffLevel:Is(HealthBuffLevel))
      lu.assertIsTrue(buffMission:Is(HealthBuff))
      lu.assertIsTrue(buffMission:Is(HealthBuffMission))
      
      -- merge all
      mergeFn(buff, buffLevel, buffMission)
      
      -- tem de ignorar esse merge
      local OtherComponent = Component.Create({ value = 0 })
      local other = OtherComponent()
      buff:Merge(other)

      -- get primary
      lu.assertEquals(buff:Primary(), buff)
      lu.assertEquals(buffLevel:Primary(), buff)
      lu.assertEquals(buffMission:Primary(), buff)

      -- get qualified
      lu.assertEquals(buff:Qualified("Primary"), buff)
      lu.assertEquals(buffLevel:Qualified("Primary"), buff)
      lu.assertEquals(buffMission:Qualified("Primary"), buff)

      lu.assertEquals(buff:Qualified("Level"), buffLevel)
      lu.assertEquals(buffLevel:Qualified("Level"), buffLevel)
      lu.assertEquals(buffMission:Qualified("Level"), buffLevel)

      lu.assertEquals(buff:Qualified("Mission"), buffMission)
      lu.assertEquals(buffLevel:Qualified("Mission"), buffMission)
      lu.assertEquals(buffMission:Qualified("Mission"), buffMission)

      -- all
      lu.assertEquals(buff:QualifiedAll(), {
         ["Primary"] = buff, ["Level"] = buffLevel, ["Mission"] = buffMission
      })
      lu.assertEquals(buffLevel:QualifiedAll(), {
         ["Primary"] = buff, ["Level"] = buffLevel, ["Mission"] = buffMission
      })
      lu.assertEquals(buffMission:QualifiedAll(), {
         ["Primary"] = buff, ["Level"] = buffLevel, ["Mission"] = buffMission
      })
   end

   mergeCase(function(buff, buffLevel, buffMission)
      buff:Merge(buff)
      buff:Merge(buffLevel)
      buff:Merge(buffMission)
   end)

   mergeCase(function(buff, buffLevel, buffMission)
      buffLevel:Merge(buff)
      buffMission:Merge(buffLevel)
      buff:Merge(buffMission)
   end)

   mergeCase(function(buff, buffLevel, buffMission)
      buffLevel:Merge(buffMission)
      buffLevel:Merge(buff)
   end)

   mergeCase(function(buff, buffLevel, buffMission)
      buffLevel:Merge(buff)
      buffLevel:Merge(buffMission)
   end)   
end

----------------------------------------------------------------------------
-- FSM - Finite State Machine
----------------------------------------------------------------------------

function TestComponent:test_Should_CreateFSM()

   local Movement = Component.Create({ Speed = 0 })

   local MovementB = Movement.Qualifier("Sub")

   --  [Standing] <---> [Walking] <---> [Running]
   Movement.States = {
      Standing = {"Walking"},
      Walking  = "*",
      Running  = {"Walking", "Running"},
      Other    = {"Other"}
   }

   -- ignored
   MovementB.States = { Standing = {"Walking"} }

   lu.assertEquals(Movement.States, {
      Standing = {"Walking"},
      Walking  = "*",
      Running  = {"Walking"},
      Other    = "*"
   })

   lu.assertEquals(MovementB.States, Movement.States)

   Movement.StateInitial = "Standing"

   local CountCall

   Movement.Case = {
      Standing = function(self, previous)
         CountCall.Standing = CountCall.Standing + 1
         CountCall.From[previous] = CountCall.From[previous] + 1
      end,
      Walking = function(self, previous)
         CountCall.Walking = CountCall.Walking + 1
         CountCall.From[previous] = CountCall.From[previous] + 1
      end,
      Running = function(self, previous)
         CountCall.Running = CountCall.Running + 1
         CountCall.From[previous] = CountCall.From[previous] + 1
      end
   }

   local function resetCountCaseCall()
      CountCall = {
         Standing = 0,
         Walking  = 0,
         Running  = 0,
         From = {
            Standing = 0,
            Walking  = 0,
            Running  = 0 
         }
      }
      sleep(0.1)
   end

   -- ECS.Query.All(Movement.In("Standing"))

   local movement = Movement()

   lu.assertEquals(movement:GetState(), "Standing")
   lu.assertEquals(movement:GetPrevState(), nil)

   local oldStateTime = 0

   resetCountCaseCall()
   movement:SetState("Walking")
   lu.assertEquals(movement:GetState(), "Walking")
   lu.assertEquals(movement:GetPrevState(), "Standing")
   local newStateTime = movement:GetStateTime()
   lu.assertNotEquals(oldStateTime, newStateTime)
   oldStateTime = newStateTime

   lu.assertEquals(CountCall.Standing, 0)
   lu.assertEquals(CountCall.Walking, 1)
   lu.assertEquals(CountCall.Running, 0)
   lu.assertEquals(CountCall.From.Standing, 1)
   lu.assertEquals(CountCall.From.Walking, 0)
   lu.assertEquals(CountCall.From.Running, 0)

   resetCountCaseCall()
   movement:SetState("Running")
   lu.assertEquals(movement:GetState(), "Running")
   lu.assertEquals(movement:GetPrevState(), "Walking")
   newStateTime = movement:GetStateTime()
   lu.assertNotEquals(oldStateTime, newStateTime)
   oldStateTime = newStateTime
   lu.assertEquals(CountCall.Standing, 0)
   lu.assertEquals(CountCall.Walking, 0)
   lu.assertEquals(CountCall.Running, 1)
   lu.assertEquals(CountCall.From.Standing, 0)
   lu.assertEquals(CountCall.From.Walking, 1)
   lu.assertEquals(CountCall.From.Running, 0)

   resetCountCaseCall()
   movement:SetState("Walking")
   lu.assertEquals(movement:GetState(), "Walking")
   lu.assertEquals(movement:GetPrevState(), "Running")
   newStateTime = movement:GetStateTime()
   lu.assertNotEquals(oldStateTime, newStateTime)
   oldStateTime = newStateTime
   lu.assertEquals(CountCall.Standing, 0)
   lu.assertEquals(CountCall.Walking, 1)
   lu.assertEquals(CountCall.Running, 0)
   lu.assertEquals(CountCall.From.Standing, 0)
   lu.assertEquals(CountCall.From.Walking, 0)
   lu.assertEquals(CountCall.From.Running, 1)

   resetCountCaseCall()
   movement:SetState("Standing")
   lu.assertEquals(movement:GetState(), "Standing")
   lu.assertEquals(movement:GetPrevState(), "Walking")
   newStateTime = movement:GetStateTime()
   lu.assertNotEquals(oldStateTime, newStateTime)
   oldStateTime = newStateTime
   lu.assertEquals(CountCall.Standing, 1)
   lu.assertEquals(CountCall.Walking, 0)
   lu.assertEquals(CountCall.Running, 0)
   lu.assertEquals(CountCall.From.Standing, 0)
   lu.assertEquals(CountCall.From.Walking, 1)
   lu.assertEquals(CountCall.From.Running, 0)

   resetCountCaseCall()
   movement:SetState("Running")
   lu.assertEquals(movement:GetState(), "Standing")
   lu.assertEquals(movement:GetPrevState(), "Walking")
   lu.assertEquals(oldStateTime, movement:GetStateTime())
   lu.assertEquals(CountCall.Standing, 0)
   lu.assertEquals(CountCall.Walking, 0)
   lu.assertEquals(CountCall.Running, 0)
   lu.assertEquals(CountCall.From.Standing, 0)
   lu.assertEquals(CountCall.From.Walking, 0)
   lu.assertEquals(CountCall.From.Running, 0)

   resetCountCaseCall()
   movement:SetState(nil)
   lu.assertEquals(movement:GetState(), "Standing")
   lu.assertEquals(movement:GetPrevState(), "Walking")
   lu.assertEquals(oldStateTime, movement:GetStateTime())
   lu.assertEquals(CountCall.Standing, 0)
   lu.assertEquals(CountCall.Walking, 0)
   lu.assertEquals(CountCall.Running, 0)
   lu.assertEquals(CountCall.From.Standing, 0)
   lu.assertEquals(CountCall.From.Walking, 0)
   lu.assertEquals(CountCall.From.Running, 0)

   resetCountCaseCall()
   movement:SetState("INVALID_STATE")
   lu.assertEquals(movement:GetState(), "Standing")
   lu.assertEquals(movement:GetPrevState(), "Walking")
   lu.assertEquals(oldStateTime, movement:GetStateTime())
   lu.assertEquals(CountCall.Standing, 0)
   lu.assertEquals(CountCall.Walking, 0)
   lu.assertEquals(CountCall.Running, 0)
   lu.assertEquals(CountCall.From.Standing, 0)
   lu.assertEquals(CountCall.From.Walking, 0)
   lu.assertEquals(CountCall.From.Running, 0)
end

function TestComponent:test_Should_QueryFSM_InState()
   
   local function execClause(clause, entity)
      return clause.Filter(entity, clause.Config)
   end

   local Movement = Component.Create({ Speed = 0 })
   Movement.States = {
      Standing = "*",
      Walking  = "*",
      Running  = "*"
   }
   local MovementB = Movement.Qualifier("Specialized")
   lu.assertNotEquals(Movement, MovementB)

   local ett_Standing = {
      [Movement] = Movement()
   }  
   ett_Standing[Movement]:SetState("Standing")

   local ett_Standing_Walking = {
      [Movement] = Movement(),
      [MovementB] = MovementB(),
   }   
   ett_Standing_Walking[Movement]:Merge(ett_Standing_Walking[MovementB])
   ett_Standing_Walking[Movement]:SetState("Standing")
   ett_Standing_Walking[MovementB]:SetState("Walking")
   
   local ett_Running = {
      [Movement] = Movement(),
   }  
   ett_Running[Movement]:SetState("Running")

   -- clause superClass
   local clause_Walking = Movement.In("Walking")
   local clause_Running = Movement.In("Running")
   local clause_Walking_Running = Movement.In("Walking", "Running")

   lu.assertIsTrue(execClause(clause_Walking, ett_Standing_Walking))
   lu.assertIsTrue(execClause(clause_Running, ett_Running))
   lu.assertIsTrue(execClause(clause_Walking_Running, ett_Running))

   lu.assertIsFalse(execClause(clause_Walking, ett_Standing))
   lu.assertIsFalse(execClause(clause_Walking, ett_Running))
   lu.assertIsFalse(execClause(clause_Walking_Running, ett_Standing))

   -- clause qualifiedClass
   local clause_b_Walking = MovementB.In("Walking")
   local clause_b_Running = MovementB.In("Running")
   local clause_b_Walking_Running = MovementB.In("Walking", "Running")

   lu.assertIsTrue(execClause(clause_b_Walking, ett_Standing_Walking))
   lu.assertIsTrue(execClause(clause_b_Walking_Running, ett_Standing_Walking))

   lu.assertIsFalse(execClause(clause_b_Running, ett_Running))
   lu.assertIsFalse(execClause(clause_b_Walking_Running, ett_Running))
   lu.assertIsFalse(execClause(clause_b_Walking, ett_Standing))
   lu.assertIsFalse(execClause(clause_b_Walking, ett_Running))
   lu.assertIsFalse(execClause(clause_b_Walking_Running, ett_Standing))

   -- clause all
   lu.assertEquals(Movement.In(), { Components = {Movement} })
   lu.assertEquals(MovementB.In(), { Components = {MovementB} })

   -- ignores OtherComponent
   local OtherComponent = Component.Create({ Percent = 0 })
   OtherComponent.States = {
      Standing = "*",
      Walking  = "*",
      Running  = "*"
   }
   local ett_other_co = {
      [OtherComponent] = OtherComponent(),
   }  
   ett_other_co[OtherComponent]:SetState("Walking")
   lu.assertIsFalse(execClause(clause_b_Walking, ett_other_co))
   lu.assertIsFalse(execClause(clause_b_Walking_Running, ett_other_co))
end

-- local Movement = ECS.Component({ Speed = 0 })
-- Movement.States = {
--    Standing = "*",
--    Walking  = {"Standing", "Running"},
--    Running  = {"Walking"}
-- }

-- Movement.Case = {
--    Standing = function(self, previous)
--       self.Speed = 0
--    end,
--    Walking = function(self, previous)
--       self.Speed = 5
--    end,
--    Running = function(self, previous)
--       self.Speed = 10
--    end
-- }

-- ECS.Query.All(Movement.In("Standing"))

-- local movement = entity[Movement]
-- movement:GetState() -> "Running"
-- movement:SetState("Walking")
-- movement:GetPrevState()
-- movement:GetStateTime()

-- if movement:GetState() == "Standing" then
--    movement.Speed = 0
-- end
