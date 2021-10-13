local lu = require('luaunit')

local EntityRepository = require('EntityRepository')

local function query(...)
   local archetypes = {...}
   local Query = {}
   function Query:Match(archetype)
      return table.find(archetypes, archetype) ~= nil
   end
   function Query:Result(chunks)
      return chunks
   end
   return Query
end

local function result(...)
   -- { ARCHETYPE_STORAGE<{[ENTITY]=true}>, ... }
   -- { { [ENTITY]=true } }
   local result = {}
   local archetypes = {}
   for i, entity in ipairs({...}) do
      if archetypes[entity.archetype] == nil then
         archetypes[entity.archetype] = {}
         table.insert(result, archetypes[entity.archetype])
      end
      archetypes[entity.archetype][entity] = true
   end
   return result
end

TestEntityRepository = {}

function TestEntityRepository:test_InsertRemoveUpdateQuery()

   local repo = EntityRepository.New()

   local ett_Foo_1 = { archetype = 'foo' }
   local ett_Foo_2 = { archetype = 'foo' }
   local ett_Bar_1 = { archetype = 'bar' }
   local ett_Bar_2 = { archetype = 'bar' }
   local ett_Baz_1 = { archetype = 'baz' }
   local ett_Baz_2 = { archetype = 'baz' }

   local q_Foo = query('foo')
   local q_Bar = query('bar')
   local q_Baz = query('baz')
   local q_Foo_Bar = query('foo', 'bar')
   local q_Foo_Baz = query('foo', 'baz')
   local q_Bar_Baz = query('bar', 'baz')
   local q_Foo_Bar_Baz = query('foo', 'bar', 'baz')

   repo:Insert(ett_Foo_1)
   repo:Insert(ett_Bar_1)
   repo:Insert(ett_Bar_2)
   repo:Insert(ett_Baz_1)
   lu.assertItemsEquals(repo:Query(q_Foo), result(ett_Foo_1))
   lu.assertItemsEquals(repo:Query(q_Bar), result(ett_Bar_1, ett_Bar_2))
   lu.assertItemsEquals(repo:Query(q_Baz), result(ett_Baz_1))
   lu.assertItemsEquals(repo:Query(q_Foo_Bar), result(ett_Foo_1, ett_Bar_1, ett_Bar_2))
   lu.assertItemsEquals(repo:Query(q_Foo_Baz), result(ett_Foo_1, ett_Baz_1))
   lu.assertItemsEquals(repo:Query(q_Bar_Baz), result(ett_Bar_1, ett_Bar_2, ett_Baz_1))
   lu.assertItemsEquals(repo:Query(q_Foo_Bar_Baz), result(ett_Foo_1, ett_Bar_1, ett_Bar_2, ett_Baz_1))

   repo:Insert(ett_Foo_1)
   repo:Insert(ett_Foo_2)
   repo:Insert(ett_Bar_1)
   repo:Insert(ett_Bar_2)
   repo:Insert(ett_Baz_1)
   repo:Insert(ett_Baz_2)
   lu.assertItemsEquals(repo:Query(q_Foo), result(ett_Foo_1, ett_Foo_2))
   lu.assertItemsEquals(repo:Query(q_Bar), result(ett_Bar_1, ett_Bar_2))
   lu.assertItemsEquals(repo:Query(q_Baz), result(ett_Baz_1, ett_Baz_2))
   lu.assertItemsEquals(repo:Query(q_Foo_Bar), result(ett_Foo_1, ett_Foo_2, ett_Bar_1, ett_Bar_2))
   lu.assertItemsEquals(repo:Query(q_Foo_Baz), result(ett_Foo_1, ett_Foo_2, ett_Baz_1, ett_Baz_2))
   lu.assertItemsEquals(repo:Query(q_Bar_Baz), result(ett_Bar_1, ett_Bar_2, ett_Baz_1, ett_Baz_2))
   lu.assertItemsEquals(repo:Query(q_Foo_Bar_Baz), result(ett_Foo_1, ett_Foo_2, ett_Bar_1, ett_Bar_2, ett_Baz_1, ett_Baz_2))

   repo:Remove(ett_Foo_1)
   repo:Remove(ett_Bar_1)
   repo:Remove(ett_Baz_1)
   repo:Remove(ett_Baz_2)
   repo:Remove('XPTO')
   lu.assertItemsEquals(repo:Query(q_Foo), result(ett_Foo_2))
   lu.assertItemsEquals(repo:Query(q_Bar), result(ett_Bar_2))
   lu.assertItemsEquals(repo:Query(q_Baz), result())
   lu.assertItemsEquals(repo:Query(q_Foo_Bar), result(ett_Foo_2, ett_Bar_2))
   lu.assertItemsEquals(repo:Query(q_Foo_Baz), result(ett_Foo_2))
   lu.assertItemsEquals(repo:Query(q_Bar_Baz), result(ett_Bar_2))
   lu.assertItemsEquals(repo:Query(q_Foo_Bar_Baz), result(ett_Foo_2, ett_Bar_2))

   -- update
   ett_Foo_2.archetype = 'bar'
   ett_Bar_2.archetype = 'baz'
   repo:Insert(ett_Foo_2)
   repo:Update(ett_Bar_2)
   lu.assertItemsEquals(repo:Query(q_Foo), result())
   lu.assertItemsEquals(repo:Query(q_Bar), result(ett_Foo_2))
   lu.assertItemsEquals(repo:Query(q_Baz), result(ett_Bar_2))
   lu.assertItemsEquals(repo:Query(q_Foo_Bar), result(ett_Foo_2))
   lu.assertItemsEquals(repo:Query(q_Foo_Baz), result(ett_Bar_2))
   lu.assertItemsEquals(repo:Query(q_Bar_Baz), result(ett_Foo_2, ett_Bar_2))
   lu.assertItemsEquals(repo:Query(q_Foo_Bar_Baz), result(ett_Foo_2, ett_Bar_2))
end
