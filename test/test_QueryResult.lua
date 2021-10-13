local lu = require('luaunit')

local Entity = require('Entity')
local Archetype = require('Archetype')
local Component = require('Component')
local QueryResult = require('QueryResult')


local Comp_A = Component.Create()
local Comp_B = Component.Create()
local Comp_B_Ql = Comp_B.Qualifier("Specialized")
local Comp_FSM = Component.Create()
local Comp_FSM_2 = Component.Create()
local Comp_FSM_2_Ql = Comp_FSM_2.Qualifier("Specialized")
local Comp_Other = Component.Create()

Comp_FSM.States = { Standing = "*", Walking  = "*", Running  = "*" }
Comp_FSM_2.States = { Standing = "*", Walking  = "*", Running  = "*" }

local comp_a = Comp_A()
local comp_b = Comp_B()
local comp_b_ql = Comp_B_Ql()
local comp_fsm_Standing = Comp_FSM()
local comp_fsm_Walking = Comp_FSM()
local comp_fsm_Running = Comp_FSM()
local comp_fsm_2_Standing = Comp_FSM_2()
local comp_fsm_2_Walking = Comp_FSM_2()
local comp_fsm_2_Running = Comp_FSM_2()
local comp_fsm_2_ql_Standing = Comp_FSM_2_Ql()
local comp_fsm_2_ql_Walking = Comp_FSM_2_Ql()
local comp_fsm_2_ql_Running = Comp_FSM_2_Ql()

comp_fsm_Standing:SetState("Standing")
comp_fsm_Walking:SetState("Walking")
comp_fsm_Running:SetState("Running")
comp_fsm_2_Standing:SetState("Standing")
comp_fsm_2_Walking:SetState("Walking")
comp_fsm_2_Running:SetState("Running")
comp_fsm_2_ql_Standing:SetState("Standing")
comp_fsm_2_ql_Walking:SetState("Walking")
comp_fsm_2_ql_Running:SetState("Running")

local entity_A = Entity.New(nil, {comp_a})
local entity_B = Entity.New(nil, {comp_b})
local entity_B_QL = Entity.New(nil, {comp_b_ql})
local entity_FSM_Standing = Entity.New(nil, {comp_fsm_Standing})
local entity_FSM_Walking = Entity.New(nil, {comp_fsm_Walking})
local entity_FSM_Running = Entity.New(nil, {comp_fsm_Running})
local entity_FSM_2_Standing = Entity.New(nil, {comp_fsm_2_Standing})
local entity_FSM_2_Walking = Entity.New(nil, {comp_fsm_2_Walking})
local entity_FSM_2_Running = Entity.New(nil, {comp_fsm_2_Running})
local entity_FSM_2_ql_Standing = Entity.New(nil, {comp_fsm_2_ql_Standing})
local entity_FSM_2_ql_Walking = Entity.New(nil, {comp_fsm_2_ql_Walking})
local entity_FSM_2_ql_Running = Entity.New(nil, {comp_fsm_2_ql_Running})

-- TO DEBUG
entity_A.Name = "entity_A"
entity_B.Name = "entity_B"
entity_B_QL.Name = "entity_B_QL"
entity_FSM_Standing.Name = "entity_FSM_Standing"
entity_FSM_Walking.Name = "entity_FSM_Walking"
entity_FSM_Running.Name = "entity_FSM_Running"
entity_FSM_2_Standing.Name = "entity_FSM_2_Standing"
entity_FSM_2_Walking.Name = "entity_FSM_2_Walking"
entity_FSM_2_Running.Name = "entity_FSM_2_Running"
entity_FSM_2_ql_Standing.Name = "entity_FSM_2_ql_Standing"
entity_FSM_2_ql_Walking.Name = "entity_FSM_2_ql_Walking"
entity_FSM_2_ql_Running.Name = "entity_FSM_2_ql_Running"

-- { ARCHETYPE_STORAGE<{[ENTITY]=true}>, ... }
local chunks = {
   { [entity_A] = true },
   { [entity_B] = true },
   { [entity_B_QL] = true },
   { [entity_FSM_Standing] = true, [entity_FSM_Walking] = true, [entity_FSM_Running] = true },
   { [entity_FSM_2_Standing] = true, [entity_FSM_2_Walking] = true, [entity_FSM_2_Running] = true },
   { [entity_FSM_2_ql_Standing] = true, [entity_FSM_2_ql_Walking] = true, [entity_FSM_2_ql_Running] = true }
}

TestQueryResult = {}

function TestQueryResult:test_ToArray()
   local result = QueryResult.New(chunks)

   local array = result:ToArray()
   lu.assertItemsEquals(array, {
      entity_A,
      entity_B,
      entity_B_QL,
      entity_FSM_Standing,
      entity_FSM_Walking,
      entity_FSM_Running,
      entity_FSM_2_Standing,
      entity_FSM_2_Walking,
      entity_FSM_2_Running,
      entity_FSM_2_ql_Standing,
      entity_FSM_2_ql_Walking,
      entity_FSM_2_ql_Running
   })
end

function TestQueryResult:test_Iterator()
   local result = QueryResult.New(chunks)

   local entities = {}
   local indexes = {}

   for count, entity in result:Iterator() do
      table.insert(entities, entity)
      table.insert(indexes, count)
   end

   lu.assertEquals(indexes, {1,2,3,4,5,6,7,8,9,10,11,12})
   lu.assertItemsEquals(entities, {
      entity_A,
      entity_B,
      entity_B_QL,
      entity_FSM_Standing,
      entity_FSM_Walking,
      entity_FSM_Running,
      entity_FSM_2_Standing,
      entity_FSM_2_Walking,
      entity_FSM_2_Running,
      entity_FSM_2_ql_Standing,
      entity_FSM_2_ql_Walking,
      entity_FSM_2_ql_Running
   })
end

local function spy(method, callback)
   return function(...)
      return callback(method, table.unpack({...}))
   end   
end

function TestQueryResult:test_AnyMatch_AllMatch_FindAny()
   local result = QueryResult.New(chunks)

   lu.assertIsTrue(result:AnyMatch(function(entity)
      return entity.archetype == entity_FSM_Standing.archetype
   end))

   local count = 0
   lu.assertIsFalse(result:AnyMatch(function(entity)
      count = count + 1
      return entity.archetype == Archetype.EMPTY
   end))
   lu.assertEquals(count, 12)


   lu.assertIsFalse(result:AllMatch(function(entity)
      return entity.archetype == entity_FSM_Standing.archetype
   end))

   -- short-circuiting terminal
   local count = 0
   lu.assertIsFalse(result:AllMatch(function(entity)
      count = count + 1
      return entity.archetype == Archetype.EMPTY
   end))
   lu.assertEquals(count, 1)

   -- short-circuiting terminal
   local count = 0
   result.Run = spy(result.Run, function(runOriginal, result, callback)
      return runOriginal(result, function(value)
         count = count + 1
         return callback(value)
      end)
   end)
   
   lu.assertNotIsNil(result:FindAny())
   lu.assertEquals(count, 1)
end



function TestQueryResult:test_ForEach()
   local result = QueryResult.New(chunks)

   local count = 0
   result:ForEach(function(entity)
      count = count + 1
   end)
   lu.assertEquals(count, 12)

   -- break
   count = 0
   result:ForEach(function(entity)
      count = count + 1
      if count == 5 then
         return true
      end
   end)
   lu.assertEquals(count, 5)   
end

function TestQueryResult:test_Filter_Map_Limit()
   local result = QueryResult.New(chunks)

   lu.assertIsFalse(
      result
         :Filter(function(entity)
            return entity.archetype == Archetype.EMPTY
         end)
         :AnyMatch(function(entity)
            return entity.archetype == entity_FSM_Standing.archetype
         end)
   )

   lu.assertIsTrue(
      result
         :Filter(function(entity)
            return entity.archetype == entity_FSM_Standing.archetype
         end)
         :AnyMatch(function(entity)
            return entity == entity_FSM_Walking
         end)
   )

   lu.assertItemsEquals(
      result
         :Filter(function(entity)
            return entity.archetype == entity_FSM_Standing.archetype
         end)
         :ToArray(), 
      {
         entity_FSM_Standing,
         entity_FSM_Walking,
         entity_FSM_Running
      }
   )

   lu.assertEquals(
      result
         :Filter(function(entity)
            return entity.archetype == Archetype.EMPTY
         end)
         :ToArray(), 
      {}
   )

   lu.assertItemsEquals(
      result
         :Filter(function(entity)
            return entity.archetype == entity_FSM_Standing.archetype
         end)
         :Map(function(entity)            
            return entity[Comp_FSM]:GetState()
         end)
         :ToArray(), 
      { "Standing", "Walking", "Running" }
   )

   lu.assertEquals(
      #(
         result
            :Filter(function(entity)
               return entity.archetype == entity_FSM_Standing.archetype
            end)
            :Limit(2)
            :ToArray()
      ), 
      2
   )

   lu.assertEquals(
      #(result:Limit(8):ToArray()), 
      8
   )

   -- total = 12
   lu.assertEquals(
      #(result:Limit(20):ToArray()), 
      12
   )
end

function TestQueryResult:test_Clauses()

   local clause_none_walking_running = Comp_FSM.In("Walking", "Running")
   clause_none_walking_running.IsNoneFilter = true

   local result = QueryResult.New(chunks, {clause_none_walking_running})
   lu.assertItemsEquals(result:ToArray(), {
      entity_A,
      entity_B,
      entity_B_QL,
      entity_FSM_Standing,
      entity_FSM_2_Standing,
      entity_FSM_2_Walking,
      entity_FSM_2_Running,
      entity_FSM_2_ql_Standing,
      entity_FSM_2_ql_Walking,
      entity_FSM_2_ql_Running
   })

   local clause_any_standing_running = Comp_FSM.In("Standing", "Running")
   clause_any_standing_running.IsAnyFilter = true

   local clause_any_walking_running_2 = Comp_FSM_2.In("Walking", "Running")
   clause_any_walking_running_2.IsAnyFilter = true

   local result = QueryResult.New(chunks, { clause_any_standing_running, clause_any_walking_running_2 })
   lu.assertItemsEquals(result:ToArray(), {
      entity_FSM_Standing,
      entity_FSM_Running,
      entity_FSM_2_Walking,
      entity_FSM_2_Running,
      entity_FSM_2_ql_Walking,
      entity_FSM_2_ql_Running,
   })

   local clause_any_standing_running = Comp_FSM.In("Standing", "Running")
   clause_any_standing_running.IsAnyFilter = true

   local clause_any_walking_running_2 = Comp_FSM_2.In("Walking", "Running")
   clause_any_walking_running_2.IsAnyFilter = true

   local clause_none_walking_running_2_ql = Comp_FSM_2_Ql.In("Walking", "Running")
   clause_none_walking_running_2_ql.IsNoneFilter = true

   local result = QueryResult.New(chunks, { clause_any_standing_running, clause_any_walking_running_2, clause_none_walking_running_2_ql })
   lu.assertItemsEquals(result:ToArray(), {
      entity_FSM_Standing,
      entity_FSM_Running,
      entity_FSM_2_Walking,
      entity_FSM_2_Running
   })

   local clause_any_walking_running_2_ql = Comp_FSM_2_Ql.In("Walking", "Running")
   clause_any_walking_running_2_ql.IsAnyFilter = true

   local result = QueryResult.New(chunks, { clause_any_standing_running, clause_any_walking_running_2_ql })
   lu.assertItemsEquals(result:ToArray(), {
      entity_FSM_Standing,
      entity_FSM_Running,
      entity_FSM_2_ql_Walking,
      entity_FSM_2_ql_Running,
   })
   
   local clause_all_standing_running = Comp_FSM.In("Standing", "Running")
   clause_all_standing_running.IsAllFilter = true

   local result = QueryResult.New(chunks, {clause_all_standing_running})
   lu.assertItemsEquals(result:ToArray(), {
      entity_FSM_Standing,
      entity_FSM_Running
   })   
end
