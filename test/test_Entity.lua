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

   -- 03) comps = entity[{CompType1, CompType2, ...}]
   lu.assertEquals(entity[{}], {})
   lu.assertEquals(entity[{Object, "XPTO"}], {})
   lu.assertEquals(entity[{Comp_A}], {comp_a})
   lu.assertEquals(entity[{Comp_B}], {comp_b})
   lu.assertEquals(entity[{Comp_C}], {comp_c})
   lu.assertEquals(entity[{Comp_A, Comp_B}], {comp_a, comp_b})
   lu.assertEquals(entity[{Comp_A, Comp_C}], {comp_a, comp_c})
   lu.assertEquals(entity[{Comp_B, Comp_C}], {comp_b, comp_c})
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})
   lu.assertEquals(entity[{Comp_A, Comp_C, Comp_B}], {comp_a, comp_c, comp_b})
   lu.assertEquals(entity[{Comp_A, Comp_C, Comp_B}], {comp_a, comp_c, comp_b})
   lu.assertEquals(entity[{Comp_A, Comp_C, Comp_B, Object}], {comp_a, comp_c, comp_b})
   lu.assertEquals(entity[{Comp_A, Comp_C, Comp_B, "XPTO"}], {comp_a, comp_c, comp_b})

   -- 04) comps = entity:Get({CompType1, CompType2, ...})
   lu.assertEquals(entity:Get({}), {})
   lu.assertEquals(entity:Get({Object, "XPTO"}), {})
   lu.assertEquals(entity:Get({Comp_A}), {comp_a})
   lu.assertEquals(entity:Get({Comp_B}), {comp_b})
   lu.assertEquals(entity:Get({Comp_C}), {comp_c})
   lu.assertEquals(entity:Get({Comp_A, Comp_B}), {comp_a, comp_b})
   lu.assertEquals(entity:Get({Comp_A, Comp_C}), {comp_a, comp_c})
   lu.assertEquals(entity:Get({Comp_B, Comp_C}), {comp_b, comp_c})
   lu.assertEquals(entity:Get({Comp_A, Comp_B, Comp_C}), {comp_a, comp_b, comp_c})
   lu.assertEquals(entity:Get({Comp_A, Comp_C, Comp_B}), {comp_a, comp_c, comp_b})
   lu.assertEquals(entity:Get({Comp_A, Comp_C, Comp_B}), {comp_a, comp_c, comp_b})
   lu.assertEquals(entity:Get({Comp_A, Comp_C, Comp_B, Object}), {comp_a, comp_c, comp_b})
   lu.assertEquals(entity:Get({Comp_A, Comp_C, Comp_B, "XPTO"}), {comp_a, comp_c, comp_b})
end

--[[
   [UNSET]
   01) enity:Unset(comp1)
   02) entity[CompType1] = nil
   03) enity:Unset(CompType1)
   04) enity:Unset({comp1, comp1, ...})
   05) enity:Unset({CompType1, CompType2, ...})
   06) entity[{CompType1, CompType2}] = nil
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
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})

   entity:Unset(comp_a)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B_C)
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_b, comp_c})

   entity:Unset(comp_b)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_c})

   entity:Unset(comp_c)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})

   -- 02) entity[CompType1] = nil
   entity = Entity.New(event, {comp_a, comp_b, comp_c})
   entity[Object] = nil
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})

   entity[Comp_A] = nil
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B_C)
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_b, comp_c})

   entity[Comp_B] = nil
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_c})

   entity[Comp_C] = nil
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})

   -- 03) enity:Unset(CompType1)
   entity = Entity.New(event, {comp_a, comp_b, comp_c})
   entity:Unset(Object)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})

   entity:Unset(Comp_A)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B_C)
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_b, comp_c})

   entity:Unset(Comp_B)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_c})

   entity:Unset(Comp_C)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})

   -- 04) enity:Unset({comp1, comp1, ...})
   entity = Entity.New(event, {comp_a, comp_b, comp_c})
   entity:Unset({Object})
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})

   entity:Unset({comp_a})
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B_C)
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_b, comp_c})

   entity:Unset({comp_b})
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_c})

   entity:Unset({comp_c})
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})

   -- 05) enity:Unset({CompType1, CompType2, ...})
   entity = Entity.New(event, {comp_a, comp_b, comp_c})
   entity:Unset({Comp_A})
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_b, comp_c})

   entity:Unset({Comp_B})
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_c})

   entity:Unset({Comp_C})
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})

   -- 06) entity[{CompType1, CompType2}] = nil
   entity = Entity.New(event, {comp_a, comp_b, comp_c})
   entity[{Object}] = nil
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})
   lu.assertEquals(entity.archetype, archetype_A_B_C)

   entity[{Comp_A}] = nil
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B_C)
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_b, comp_c})

   entity[{Comp_B}] = nil
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_c})

   entity[{Comp_C}] = nil
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})
end

--[[
   [SET]
   01) entity:Set(comp1)
   02) entity[CompType1] = nil
   03) entity:Set(CompType1, nil)   
   04) entity[CompType1] = value
   05) entity:Set(CompType1, value)
   06) entity:Set({comp1, comp2, ...})
   07) entity[{CompType1, CompType2, ...}] = nil
   08) entity:Set({CompType1, CompType2, ...}, nil)
   09) entity[{CompType1, CompType2, ...}] = {value1, value2, ...}
   10) entity:Set({CompType1, CompType2, ...}, {value1, value2, ...})
   11) entity[{CompType1, CompType2, ...}] = {nil, value2, ...}
   12) entity:Set({CompType1, CompType2, ...}, {nil, value2, ...})
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
   
   --  01) entity:Set(comp1)
   local entity = Entity.New(event)
   entity:Set(Object)
   lu.assertEquals(eventEntity, nil)
   lu.assertEquals(eventArchetypeOld, nil)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})

   entity:Set(comp_a)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, Archetype.EMPTY)
   lu.assertEquals(entity.archetype, archetype_A)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a})

   entity:Set(comp_b)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A)
   lu.assertEquals(entity.archetype, archetype_A_B)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b})

   entity:Set(comp_c)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})

   -- 02) entity[CompType1] = nil
   -- @see TestEntity:test_Unset()

   -- 03) entity:Set(CompType1, nil)   
   entity = Entity.New(event, {comp_a, comp_b, comp_c})
   entity:Set(Object, nil)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})

   entity:Set(Comp_A, nil)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B_C)
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_b, comp_c})

   entity:Set(Comp_B, nil)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_c})

   entity:Set(Comp_C, nil)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})

   -- 04) entity[CompType1] = value
   entity = Entity.New(event)
   entity[Object] = "XPTO"
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})

   entity[Comp_A] = comp_a
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, Archetype.EMPTY)
   lu.assertEquals(entity.archetype, archetype_A)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a})

   entity[Comp_B] = comp_b
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A)
   lu.assertEquals(entity.archetype, archetype_A_B)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b})

   entity[Comp_C] = comp_c
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})

   entity[Comp_C] = { Name = 'NEW C' }
   lu.assertEquals(entity[{Comp_A, Comp_B}], {comp_a, comp_b})
   lu.assertEquals(entity[{Comp_C}][1]:GetType(), Comp_C)
   lu.assertEquals(entity[{Comp_C}][1].Name, 'NEW C')
   lu.assertNotEquals(entity[{Comp_C}], {comp_c})
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   -- NO EVENT CALL (SAME ARCHETYPE archetype_A_B_C)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B)

   -- 05) entity:Set(CompType1, value)
   entity = Entity.New(event)
   entity:Set(Object, "XPTO")
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})

   entity:Set(Comp_A, comp_a)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, Archetype.EMPTY)
   lu.assertEquals(entity.archetype, archetype_A)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a})

   entity:Set(Comp_B, comp_b)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A)
   lu.assertEquals(entity.archetype, archetype_A_B)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b})

   entity:Set(Comp_C, comp_c)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})

   entity:Set(Comp_C, { Name = 'NEW C' })
   lu.assertEquals(entity[{Comp_A, Comp_B}], {comp_a, comp_b})
   lu.assertEquals(entity[{Comp_C}][1]:GetType(), Comp_C)
   lu.assertEquals(entity[{Comp_C}][1].Name, 'NEW C')
   lu.assertNotEquals(entity[{Comp_C}], {comp_c})
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   -- NO EVENT CALL (SAME ARCHETYPE archetype_A_B_C)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B)

   -- 06) entity:Set({comp1, comp2, ...})
   entity = Entity.New(event)
   entity:Set({Object})
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})

   entity:Set({comp_a})
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, Archetype.EMPTY)
   lu.assertEquals(entity.archetype, archetype_A)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a})

   entity:Set({comp_b, comp_c})
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})

   -- 07) entity[{CompType1, CompType2, ...}] = nil
   -- @see TestEntity:test_Unset()

   -- 08) entity:Set({CompType1, CompType2, ...}, nil)
   entity = Entity.New(event, {comp_a, comp_b, comp_c})
   entity:Set({Object}, nil)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})

   entity:Set({Comp_A}, nil)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A_B_C)
   lu.assertEquals(entity.archetype, archetype_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_b, comp_c})

   entity:Set({Comp_B}, nil)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B_C)
   lu.assertEquals(entity.archetype, archetype_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_c})

   entity:Set({Comp_C}, nil)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_C)
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})

   -- 09) entity[{CompType1, CompType2, ...}] = {value1, value2, ...}
   entity = Entity.New(event)
   entity[{Object}] = {"XPTO"}
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})

   entity[{Comp_A}] = {comp_a}
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, Archetype.EMPTY)
   lu.assertEquals(entity.archetype, archetype_A)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a})

   entity[{Comp_B, Comp_C}] = {comp_b, comp_c}
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})

   entity[{Comp_C}] = {{ Name = 'NEW C' }}
   lu.assertEquals(entity[{Comp_A, Comp_B}], {comp_a, comp_b})
   lu.assertEquals(entity[{Comp_C}][1]:GetType(), Comp_C)
   lu.assertEquals(entity[{Comp_C}][1].Name, 'NEW C')
   lu.assertNotEquals(entity[{Comp_C}], {comp_c})
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   -- NO EVENT CALL (SAME ARCHETYPE archetype_A_B_C)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A)

   -- 10) entity:Set({CompType1, CompType2, ...}, {value1, value2, ...})
   entity = Entity.New(event)
   entity:Set({Object}, {"XPTO"})
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {})

   entity:Set({Comp_A}, {comp_a})
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, Archetype.EMPTY)
   lu.assertEquals(entity.archetype, archetype_A)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a})

   entity:Set({Comp_B, Comp_C}, {comp_b, comp_c})
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A)
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_b, comp_c})

   entity:Set({Comp_C}, {{ Name = 'NEW C' }})
   lu.assertEquals(entity[{Comp_A, Comp_B}], {comp_a, comp_b})
   lu.assertEquals(entity[{Comp_C}][1]:GetType(), Comp_C)
   lu.assertEquals(entity[{Comp_C}][1].Name, 'NEW C')
   lu.assertNotEquals(entity[{Comp_C}], {comp_c})
   lu.assertEquals(entity.archetype, archetype_A_B_C)
   -- NO EVENT CALL (SAME ARCHETYPE archetype_A_B_C)
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A)

   -- 11) entity[{CompType1, CompType2, ...}] = {nil, value2, ...}
   entity = Entity.New(event, {comp_a})
   lu.assertEquals(entity.archetype, archetype_A)

   entity[{Comp_A, Comp_B}] = {nil, comp_b}
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_A)
   lu.assertEquals(entity.archetype, archetype_B)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_b})

   entity[{Comp_A, Comp_B, Comp_C}] = {comp_a, nil, comp_c}
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B)
   lu.assertEquals(entity.archetype, archetype_A_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_c})

   -- 12) entity:Set({CompType1, CompType2, ...}, {nil, value2, ...})
   entity = Entity.New(event, {comp_a})
   entity:Set({Comp_A, Comp_B}, {nil, comp_b})
   lu.assertEquals(entity.archetype, archetype_B)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_b})

   entity:Set({Comp_A, Comp_B, Comp_C}, {comp_a, nil, comp_c})
   lu.assertEquals(eventEntity, entity)
   lu.assertEquals(eventArchetypeOld, archetype_B)
   lu.assertEquals(entity.archetype, archetype_A_C)
   lu.assertEquals(entity[{Comp_A, Comp_B, Comp_C}], {comp_a, comp_c})
end

function TestEntity:test_RawSet()
   local Object = {}

   local event = Event.New()
   
   --  01) entity:Set(comp1)
   local entity = Entity.New(event)
   entity.Name = "Player"
   entity["NetworkId"] = 33
   entity[Object] = "XPTO"

   lu.assertEquals(entity.Name, "Player")
   lu.assertEquals(entity.NetworkId, 33)
   lu.assertEquals(entity[Object], "XPTO")
   lu.assertEquals(entity.archetype, Archetype.EMPTY)
end
