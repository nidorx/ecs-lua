
package.path = package.path .. ";modules/?.lua"
package.path = package.path .. ";src/?.lua"
-- package.path = package.path .. ";?/init.lua"
-- package.path = package.path .. ";../?.lua"
-- package.path = package.path .. ";./modules/luacov.lua"
-- package.path = package.path .. ";../modules/luaunit.lua"
local lu = require('luaunit')
local luacov = require("luacov")

-- tests
require("test/TestArchetype")
require("test/TestComponent")
require("test/TestEntity")
require("test/TestEntityRepository")
require("test/TestEvent")
require("test/TestQueryResult")

-- local runner = lu.LuaUnit.new()
-- runner:setOutputType("text")
-- os.exit( runner:runSuite() )
-- lu.LuaUnit.verbosity = 2

os.exit(lu.LuaUnit.run())
