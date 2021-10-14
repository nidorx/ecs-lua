local lu = require('luaunit')

local Event = require('Event')
local Entity = require('Entity')
local Component = require('Component')
local Archetype = require('Archetype')


TestEntity = {}

local Comp_A = Component.Create({ Name = 'a' })
Comp_A.Name = "A"

local Comp_B = Component.Create({ Name = 'b' })
Comp_B.Name = "B"

local Comp_C = Component.Create({ Name = 'c' })
Comp_C.Name = "C"

local comp_a = Comp_A()
local comp_b = Comp_B()
local comp_c = Comp_C()

local archetype_A = Archetype.Of({ Comp_A })
local archetype_B = Archetype.Of({ Comp_B })
local archetype_C = Archetype.Of({ Comp_C })
local archetype_A_B = archetype_A:With(Comp_B)
local archetype_A_C = archetype_A:With(Comp_C)
local archetype_B_C = archetype_B:With(Comp_C)
local archetype_A_B_C = archetype_A_B:With(Comp_C)

function TestEntity:test_Constructor()
   lu.assertEquals(Entity.New(nil).archetype, Archetype.EMPTY)
   lu.assertEquals(Entity.New(nil, {comp_a}).archetype, archetype_A)
   lu.assertEquals(Entity.New(nil, {comp_b}).archetype, archetype_B)
   lu.assertEquals(Entity.New(nil, {comp_c}).archetype, archetype_C)
   lu.assertEquals(Entity.New(nil, {comp_a, comp_b}).archetype, archetype_A_B)
   lu.assertEquals(Entity.New(nil, {comp_a, comp_c}).archetype, archetype_A_C)
   lu.assertEquals(Entity.New(nil, {comp_b, comp_c}).archetype, archetype_B_C)
   lu.assertEquals(Entity.New(nil, {comp_a, comp_b, comp_c}).archetype, archetype_A_B_C)
end

--[[
   [GET]
   01) comp1 = entity[CompType1]
   02) comp1 = entity:Get(CompType1)
   03) comps = entity[{CompType1, CompType2, ...}]
   04) comps = entity:Get({CompType1, CompType2, ...})
]]
function TestEntity:test_Get()

   local Object = {}

   local entity = Entity.New(nil, {comp_a, comp_b, comp_c})

   -- 01) comp1 = entity[CompType1]
   lu.assertEquals(entity[Comp_A], comp_a)
   lu.assertEquals(entity[Comp_B], comp_b)
   lu.assertEquals(entity[Comp_C], comp_c)

   -- 02) comp1 = entity:Get(CompType1)
   lu.assertEquals(entity:Get(Comp_A), comp_a)
   lu.assertEquals(entity:Get(Comp_B), comp_b)
   lu.assertEquals(entity:Get(Comp_C), comp_c)

   -- 03) comp1, comp2, comp3 = entity:Get(CompType1, CompType2, CompType3)
   lu.assertEquals(entity:Get({}), nil)
   lu.assertEquals(entity:Get(Object, "XPTO"), nil)
   lu.assertEquals({entity:Get(Comp_A)}, {comp_a})
   lu.assertEquals({entity:Get(Comp_B)}, {comp_b})
   lu.assertEquals({entity:Get(Comp_C)}, {comp_c})
   lu.assertEquals({entity:Get(Comp_A, Comp_B)}, {comp_a, comp_b})
   lu.assertEquals({entity:Get(Comp_A, Comp_C)}, {comp_a, comp_c})
   lu.assertEquals({entity:Get(Comp_B, Comp_C)}, {comp_b, comp_c})
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a, comp_b, comp_c})
   lu.assertEquals({entity:Get(Comp_A, Comp_C, Comp_B)}, {comp_a, comp_c, comp_b})
   lu.assertEquals({entity:Get(Comp_A, Comp_C, Comp_B)}, {comp_a, comp_c, comp_b})
   lu.assertEquals({entity:Get(Comp_A, Comp_C, Comp_B, Object)}, {comp_a, comp_c, comp_b})
   lu.assertEquals({entity:Get(Comp_A, Comp_C, Comp_B, "XPTO")}, {comp_a, comp_c, comp_b})
end

--[[
   [UNSET]
   01) enity:Unset(comp1)
   02) entity[CompType1] = nil
   03) enity:Unset(CompType1)
   04) enity:Unset(comp1, comp1, ...)
   05) enity:Unset(CompType1, CompType2, ...)
]]
function TestEntity:test_Unset()

   local Object = {}   
   local event = Event.New()

   local eventEntity = nil
   local eventArchetypeOld = nil
   event:Connect(function(entity, old)
      eventEntity = entity
      eventArchetypeOld = old
   end)
   
   -- 01) enity:Unset(comp1)
   local entity = Entity.New(event, {comp_a, comp_b, comp_c})
   entity:Unset(Object)
   lu.assertEquals(eventEntity, nil)
   lu.assertEquals(eventArchetypeOld, nil)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a, comp_b, comp_c})

   entity:Unset(comp_a)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B_C)
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_b, comp_c})

   entity:Unset(comp_b)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_c})

   entity:Unset(comp_c)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {})

   -- 02) entity[CompType1] = nil
   entity = Entity.New(event, {comp_a, comp_b, comp_c})
   entity[Object] = nil
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a, comp_b, comp_c})

   entity[Comp_A] = nil
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B_C)
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_b, comp_c})

   entity[Comp_B] = nil
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_c})

   entity[Comp_C] = nil
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {})

   -- 03) enity:Unset(CompType1)
   entity = Entity.New(event, {comp_a, comp_b, comp_c})
   entity:Unset(Object)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a, comp_b, comp_c})

   entity:Unset(Comp_A)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B_C)
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_b, comp_c})

   entity:Unset(Comp_B)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_c})

   entity:Unset(Comp_C)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {})

   -- 04) enity:Unset(comp1, comp1, ...)
   entity = Entity.New(event, {comp_a, comp_b, comp_c})
   entity:Unset(Object)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a, comp_b, comp_c})

   entity:Unset(comp_a)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B_C)
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_b, comp_c})

   entity:Unset(comp_b)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_c})

   entity:Unset(comp_c)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {})

   -- 05) enity:Unset(CompType1, CompType2, ...)
   entity = Entity.New(event, {comp_a, comp_b, comp_c})
   entity:Unset(Comp_A)
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_b, comp_c})

   entity:Unset(Comp_B)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_c})

   entity[Comp_C] = nil
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {})
end

--[[
   [SET]
   01) entity[CompType1] = nil
   02) entity[CompType1] = value
   03) entity:Set(CompType1, nil)   
   04) entity:Set(CompType1, value)
   05) entity:Set(comp1)
   06) entity:Set(comp1, comp2, ...)
]]
function TestEntity:test_Set()

   local Object = {}

   local event = Event.New()

   local eventEntity = nil
   local eventArchetypeOld = nil
   event:Connect(function(entity, old)
      eventEntity = entity
      eventArchetypeOld = old
   end)
   
   --  05) entity:Set(comp1)
   local entity = Entity.New(event)
   entity:Set(Object)
   lu.assertEquals(eventEntity, nil)
   lu.assertEquals(eventArchetypeOld, nil)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {})

   entity:Set(comp_a)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, Archetype.EMPTY)
   lu.assertEquals(entity.archetype, archetype_A)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a})

   entity:Set(comp_b)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A)
   lu.assertEquals(entity.archetype, archetype_A_B)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a, comp_b})

   entity:Set(comp_c)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a, comp_b, comp_c})

   -- 01) entity[CompType1] = nil
   -- @see TestEntity:test_Unset()

   -- 03) entity:Set(CompType1, nil)   
   entity = Entity.New(event, {comp_a, comp_b, comp_c})
   entity:Set(Object, nil)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a, comp_b, comp_c})

   entity:Set(Comp_A, nil)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B_C)
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_b, comp_c})

   entity:Set(Comp_B, nil)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_c})

   entity:Set(Comp_C, nil)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {})

   -- 02) entity[CompType1] = value
   entity = Entity.New(event)
   entity[Object] = "XPTO"
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {})

   entity[Comp_A] = comp_a
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, Archetype.EMPTY)
   lu.assertEquals(entity.archetype, archetype_A)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a})

   entity[Comp_B] = comp_b
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A)
   lu.assertEquals(entity.archetype, archetype_A_B)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a, comp_b})

   entity[Comp_C] = comp_c
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a, comp_b, comp_c})

   entity[Comp_C] = { Name = 'NEW C' }
   lu.assertEquals({entity:Get(Comp_A, Comp_B)}, {comp_a, comp_b})
   lu.assertEquals(entity[Comp_C]:GetType(), Comp_C)
   lu.assertEquals(entity[Comp_C].Name, 'NEW C')
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   -- NO EVENT CALL (SAME ARCHETYPE archetype_A_B_C)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B)

   -- 04) entity:Set(CompType1, value)
   entity = Entity.New(event)
   entity:Set(Object, "XPTO")
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {})

   entity:Set(Comp_A, comp_a)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, Archetype.EMPTY)
   lu.assertEquals(entity.archetype, archetype_A)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a})

   entity:Set(Comp_B, comp_b)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A)
   lu.assertEquals(entity.archetype, archetype_A_B)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a, comp_b})

   entity:Set(Comp_C, comp_c)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a, comp_b, comp_c})

   entity:Set(Comp_C, { Name = 'NEW C' })
   lu.assertEquals({entity:Get(Comp_A, Comp_B)}, {comp_a, comp_b})
   lu.assertEquals(entity[Comp_C]:GetType(), Comp_C)
   lu.assertEquals(entity[Comp_C].Name, 'NEW C')
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   -- NO EVENT CALL (SAME ARCHETYPE archetype_A_B_C)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B)

   -- 06) entity:Set(comp1, comp2, ...)
   entity = Entity.New(event)
   entity:Set(Object)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {})

   entity:Set(comp_a)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, Archetype.EMPTY)
   lu.assertEquals(entity.archetype, archetype_A)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a})

   entity:Set(comp_b, comp_c)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals({entity:Get(Comp_A, Comp_B, Comp_C)}, {comp_a, comp_b, comp_c})
end

function TestEntity:test_RawSet()
   local Object = {}

   local event = Event.New()
   
   --  05) entity:Set(comp1)
   local entity = Entity.New(event)
   entity.Name = "Player"
   entity["NetworkId"] = 33
   entity[Object] = "XPTO"

   lu.assertEquals(entity.Name, "Player")
   lu.assertEquals(entity.NetworkId, 33)
   lu.assertEquals(entity[Object], "XPTO")
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
end

function TestEntity:test_Qualifiers()

   local event = Event.New()

   local HealthBuff = Component.Create({ percent = 0 })
   local HealthBuffLevel = HealthBuff.Qualifier("Level")
   local HealthBuffMission = HealthBuff.Qualifier("Mission")
   local OtherComp = Component.Create({ value = 0 })


   local function doTest(instanciate)

      local entity = Entity.New(event)
      
      local buff, buffLevel, buffMission, other = instanciate(entity)

      lu.assertItemsEquals(entity:GetAll(HealthBuff), {buff, buffLevel, buffMission})
      lu.assertItemsEquals(entity:GetAll(HealthBuffLevel), {buff, buffLevel, buffMission})
      lu.assertItemsEquals(entity:GetAll(HealthBuffMission), {buff, buffLevel, buffMission})
      lu.assertItemsEquals(entity:GetAll(OtherComp), {other})
      lu.assertItemsEquals(entity:GetAll(), {other, buff, buffLevel, buffMission})


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
      
      -- unset
      entity[HealthBuffLevel] = nil
      lu.assertItemsEquals(entity:GetAll(HealthBuff), {buff, buffMission})
      lu.assertItemsEquals(entity:GetAll(HealthBuffLevel), {buff, buffMission})
      lu.assertItemsEquals(entity:GetAll(HealthBuffMission), {buff, buffMission})
      lu.assertItemsEquals(entity:GetAll(OtherComp), {other})
      lu.assertItemsEquals(entity:GetAll(), {other, buff, buffMission})
      lu.assertEquals(buff:QualifiedAll(), {
         ["Primary"] = buff, ["Mission"] = buffMission
      })
      lu.assertEquals(buffLevel:QualifiedAll(), {
         ["Level"] = buffLevel
      })
      lu.assertEquals(buffMission:QualifiedAll(), {
         ["Primary"] = buff, ["Mission"] = buffMission
      })

      -- unset
      entity:Unset(HealthBuff)
      lu.assertItemsEquals(entity:GetAll(HealthBuff), {buffMission})
      lu.assertItemsEquals(entity:GetAll(HealthBuffLevel), {buffMission})
      lu.assertItemsEquals(entity:GetAll(HealthBuffMission), {buffMission})
      lu.assertItemsEquals(entity:GetAll(OtherComp), {other})
      lu.assertItemsEquals(entity:GetAll(), {other, buffMission})      
      lu.assertEquals(buff:QualifiedAll(), {
         ["Primary"] = buff
      })
      lu.assertEquals(buffLevel:QualifiedAll(), {
         ["Level"] = buffLevel
      })
      lu.assertEquals(buffMission:QualifiedAll(), {
         ["Mission"] = buffMission
      })

      -- again 
      local buff, buffLevel, buffMission, other = instanciate(entity)
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
      
      -- unset
      entity[HealthBuffLevel] = nil
      lu.assertItemsEquals(entity:GetAll(HealthBuff), {buff, buffMission})
      lu.assertItemsEquals(entity:GetAll(HealthBuffLevel), {buff, buffMission})
      lu.assertItemsEquals(entity:GetAll(HealthBuffMission), {buff, buffMission})
      lu.assertItemsEquals(entity:GetAll(OtherComp), {other})
      lu.assertItemsEquals(entity:GetAll(), {other, buff, buffMission})
      lu.assertEquals(buff:QualifiedAll(), {
         ["Primary"] = buff, ["Mission"] = buffMission
      })
      lu.assertEquals(buffLevel:QualifiedAll(), {
         ["Level"] = buffLevel
      })
      lu.assertEquals(buffMission:QualifiedAll(), {
         ["Primary"] = buff, ["Mission"] = buffMission
      })

      -- unset
      entity:Unset(HealthBuff)
      lu.assertItemsEquals(entity:GetAll(HealthBuff), {buffMission})
      lu.assertItemsEquals(entity:GetAll(HealthBuffLevel), {buffMission})
      lu.assertItemsEquals(entity:GetAll(HealthBuffMission), {buffMission})
      lu.assertItemsEquals(entity:GetAll(OtherComp), {other})
      lu.assertItemsEquals(entity:GetAll(), {other, buffMission})      
      lu.assertEquals(buff:QualifiedAll(), {
         ["Primary"] = buff
      })
      lu.assertEquals(buffLevel:QualifiedAll(), {
         ["Level"] = buffLevel
      })
      lu.assertEquals(buffMission:QualifiedAll(), {
         ["Mission"] = buffMission
      })
   end

   doTest(function(entity)
      local buff = HealthBuff()
      local buffLevel = HealthBuffLevel()
      local buffMission = HealthBuffMission()
      local other = OtherComp()

      entity:Set(buff)
      entity:Set(buffLevel)
      entity:Set(buffMission)
      entity:Set(other)

      return buff, buffLevel, buffMission, other
   end)

   doTest(function(entity)
      local buff = HealthBuff()
      local buffLevel = HealthBuffLevel()
      local buffMission = HealthBuffMission()
      local other = OtherComp()

      entity[HealthBuff] = buff
      entity[HealthBuffLevel] = buffLevel
      entity[HealthBuffMission] = buffMission
      entity[OtherComp] = other

      return buff, buffLevel, buffMission, other
   end)

   doTest(function(entity)

      entity[HealthBuff] = {}
      entity[HealthBuffLevel] = {}
      entity[HealthBuffMission] = {}
      entity[OtherComp] = {}

      return entity[HealthBuff], entity[HealthBuffLevel] , entity[HealthBuffMission], entity[OtherComp]
   end)
   
end
