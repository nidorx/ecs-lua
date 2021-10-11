
package.path = package.path .. ";modules/?.lua"
package.path = package.path .. ";src/?.lua"
local lu = require('luaunit')
local luacov = require("luacov")

-- tests
require("test/test_Archetype")
require("test/test_Component")
-- require("test/test_ECS")
require("test/test_Entity")
require("test/test_EntityRepository")
require("test/test_Event")
require("test/test_Query")
require("test/test_QueryResult")
-- require("test/test_RobloxLoopManager")
-- require("test/test_System")
require("test/test_SystemExecutor")
-- require("test/test_Timer")
-- require("test/test_Utility")
require("test/test_World")

os.exit(lu.LuaUnit.run())
