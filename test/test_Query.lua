local lu = require('luaunit')

local Query = require('Query')
local Archetype = require('Archetype')
local Component = require('Component')

local Comp_A = Component.Create()
local Comp_B = Component.Create()
local Comp_B_QL = Comp_B.Qualifier("Specialized")
local Comp_FSM = Component.Create()
local Comp_FSM_QL = Comp_FSM.Qualifier("Specialized")

Comp_FSM.States = { Standing = "*", Walking  = "*", Running  = "*" }

local archetype_A = Archetype.Of({Comp_A})
local archetype_B = Archetype.Of({Comp_B})
local archetype_A_B = Archetype.Of({Comp_A, Comp_B})
local archetype_B_QL = Archetype.Of({Comp_B_QL})
local archetype_FSM = Archetype.Of({Comp_FSM})
local archetype_FSM_QL = Archetype.Of({Comp_FSM_QL})

TestQuery = {}

function TestQuery:test_Match()
   
   -- all
   local all_A = Query({ Comp_A })
   local all_A_B = Query({ Comp_A, Comp_B })
   local all_B_QL = Query.All(Comp_B_QL).Build()
   lu.assertIsTrue(all_A:Match(archetype_A))
   lu.assertIsTrue(all_A_B:Match(archetype_A_B))
   lu.assertIsTrue(all_B_QL:Match(archetype_B_QL))
   lu.assertIsFalse(all_A_B:Match(archetype_FSM))
   -- all (cache result)
   lu.assertIsTrue(all_A:Match(archetype_A))
   lu.assertIsTrue(all_A_B:Match(archetype_A_B))
   lu.assertIsTrue(all_B_QL:Match(archetype_B_QL))
   lu.assertIsFalse(all_A_B:Match(archetype_FSM))

   -- any
   local any_A = Query(nil, { Comp_A })
   local any_B = Query(nil, { Comp_B })
   local any_A_B = Query.Any(Comp_A, Comp_B).Build()
   lu.assertIsTrue(any_A:Match(archetype_A_B))
   lu.assertIsTrue(any_B:Match(archetype_A_B))
   lu.assertIsTrue(any_A_B:Match(archetype_A_B))
   lu.assertIsFalse(any_A_B:Match(archetype_FSM))
   -- any (cache result)
   lu.assertIsTrue(any_A:Match(archetype_A_B))
   lu.assertIsTrue(any_B:Match(archetype_A_B))
   lu.assertIsTrue(any_A_B:Match(archetype_A_B))
   lu.assertIsFalse(any_A_B:Match(archetype_FSM))

   -- none
   local none_A = Query(nil, nil, { Comp_A })
   local none_B = Query.None(Comp_B).Build()
   lu.assertIsFalse(none_A:Match(archetype_A_B))
   lu.assertIsFalse(none_B:Match(archetype_A_B))
   -- none (cache result)
   lu.assertIsFalse(none_A:Match(archetype_A_B))
   lu.assertIsFalse(none_B:Match(archetype_A_B))

   -- clause
   local all_A = Query({ Comp_FSM.In("Standing") })
   lu.assertIsTrue(all_A:Match(archetype_FSM))
   lu.assertIsTrue(all_A:Match(archetype_FSM_QL))


   -- result
   lu.assertNotIsNil(all_A:Result({}))
end
