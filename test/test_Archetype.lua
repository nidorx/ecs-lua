local lu = require('luaunit')

local Archetype = require('Archetype')

TestArchetype = {}

local SEQ = 1
local function newCompId()
   SEQ = SEQ+1
   return SEQ
end

function TestArchetype:test_Should_ReturnSame()

   local version = Archetype.Version()

   local ComponentA = { Id = newCompId(), IsCType = true }
   local ComponentB = { Id = newCompId(), IsCType = true }
   local ComponentC = { Id = newCompId(), }
   
   local ComponentS = { Id = newCompId(), IsCType = true }
   local ComponentQ = { Id = newCompId(), IsCType = true, IsQualifier = true, SuperClass = ComponentS }
   
   local archetypeA = Archetype.Of({ ComponentA, ComponentQ, ComponentB, ComponentC })
   local archetypeB = Archetype.Of({ ComponentC, ComponentA, ComponentQ, ComponentB })

   lu.assertNotIsNil(archetypeA)
   lu.assertNotIsNil(archetypeB)

   lu.assertEquals(archetypeA, archetypeB)

   lu.assertIsTrue(archetypeA:Has(ComponentA))
   lu.assertIsTrue(archetypeA:Has(ComponentB))

   lu.assertIsTrue(archetypeA:Has(ComponentS))
   lu.assertIsTrue(archetypeA:Has(ComponentQ))

   lu.assertIsFalse(archetypeA:Has(ComponentC))
   
   lu.assertNotEquals(version, Archetype.Version())
end

function TestArchetype:test_Should_Create_With_Component()

   local ComponentA = { Id = newCompId(), IsCType = true }
   local ComponentB = { Id = newCompId(), IsCType = true }
   local ComponentC = { Id = newCompId(), }
   local ComponentD = { Id = newCompId(), IsCType = true }

   local archetypeA = Archetype.Of({ ComponentA, ComponentB, ComponentC })
   local archetypeB = Archetype.Of({ ComponentA, ComponentB, ComponentC, ComponentD })
   local archetypeC = archetypeA:With(ComponentD)
   local archetypeD = archetypeB:With(ComponentD)

   lu.assertNotIsNil(archetypeA)
   lu.assertNotIsNil(archetypeB)
   lu.assertNotIsNil(archetypeC)
   lu.assertNotIsNil(archetypeD)

   lu.assertEquals(archetypeB, archetypeC)
   lu.assertEquals(archetypeB, archetypeD)

   
   lu.assertIsTrue(archetypeB:Has(ComponentD))
   lu.assertIsFalse(archetypeA:Has(ComponentD))
end

function TestArchetype:test_Should_Create_WithAll_Components()

   local ComponentA = { Id = newCompId(), IsCType = true }
   local ComponentB = { Id = newCompId(), IsCType = true }
   local ComponentC = { Id = newCompId(), }
   local ComponentD = { Id = newCompId(), IsCType = true }
   local ComponentE = { Id = newCompId(), IsCType = true }

   local archetypeA = Archetype.Of({ ComponentA, ComponentB, ComponentC })
   local archetypeB = Archetype.Of({ ComponentA, ComponentB, ComponentC, ComponentD, ComponentE })
   local archetypeC = archetypeA:WithAll({ ComponentD, ComponentE })
   local archetypeD = archetypeB:WithAll({ ComponentD, ComponentE })

   lu.assertNotIsNil(archetypeA)
   lu.assertNotIsNil(archetypeB)
   lu.assertNotIsNil(archetypeC)
   lu.assertNotIsNil(archetypeD)

   lu.assertEquals(archetypeB, archetypeC)
   lu.assertEquals(archetypeB, archetypeD)

   lu.assertIsTrue(archetypeB:Has(ComponentD))
   lu.assertIsTrue(archetypeB:Has(ComponentE))
   lu.assertIsFalse(archetypeA:Has(ComponentD))
   lu.assertIsFalse(archetypeA:Has(ComponentE))
end


function TestArchetype:test_Should_Create_Without_Component()

   local ComponentA = { Id = newCompId(), IsCType = true }
   local ComponentB = { Id = newCompId(), IsCType = true }
   local ComponentC = { Id = newCompId(), }
   local ComponentD = { Id = newCompId(), IsCType = true }

   local archetypeA = Archetype.Of({ ComponentA, ComponentB, ComponentC })
   local archetypeB = Archetype.Of({ ComponentA, ComponentB, ComponentC, ComponentD })
   local archetypeC = archetypeB:Without(ComponentD)
   local archetypeD = archetypeA:Without(ComponentD)

   lu.assertNotIsNil(archetypeA)
   lu.assertNotIsNil(archetypeB)
   lu.assertNotIsNil(archetypeC)
   lu.assertNotIsNil(archetypeD)

   lu.assertEquals(archetypeA, archetypeC)
   lu.assertEquals(archetypeA, archetypeD)

   lu.assertIsTrue(archetypeB:Has(ComponentD))
   lu.assertIsFalse(archetypeA:Has(ComponentD))
end

function TestArchetype:test_Should_Create_WithoutAll_Components()

   local ComponentA = { Id = newCompId(), IsCType = true }
   local ComponentB = { Id = newCompId(), IsCType = true }
   local ComponentC = { Id = newCompId(), }
   local ComponentD = { Id = newCompId(), IsCType = true }
   local ComponentE = { Id = newCompId(), IsCType = true }

   local archetypeA = Archetype.Of({ ComponentA, ComponentB, ComponentC })
   local archetypeB = Archetype.Of({ ComponentA, ComponentB, ComponentC, ComponentD, ComponentE })
   local archetypeC = archetypeB:WithoutAll({ ComponentD, ComponentE })
   local archetypeD = archetypeA:WithoutAll({ ComponentD, ComponentE })

   lu.assertNotIsNil(archetypeA)
   lu.assertNotIsNil(archetypeB)
   lu.assertNotIsNil(archetypeC)
   lu.assertNotIsNil(archetypeD)

   lu.assertEquals(archetypeA, archetypeC)
   lu.assertEquals(archetypeA, archetypeD)

   lu.assertIsTrue(archetypeB:Has(ComponentD))
   lu.assertIsTrue(archetypeB:Has(ComponentE))
   lu.assertIsFalse(archetypeA:Has(ComponentD))
   lu.assertIsFalse(archetypeA:Has(ComponentE))
end
