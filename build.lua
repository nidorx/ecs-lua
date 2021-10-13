

local OUTPUT_CONCAT = "ECS_concat"

local OUTPUT_MINIFIED = "ECS"

local SRC_FILES = {
   "Archetype",
   "Component",
   "ComponentFSM",
   "ECS",
   "Entity",
   "EntityRepository",
   "Event",
   "Query",
   "QueryResult",
   "RobloxLoopManager",
   "System",
   "SystemExecutor",
   "Timer",
   "Utility",
   "World"
}

local HEADER = [[
	ECS-Lua v2.0.0 [2021-10-02 17:25]

	ECS-Lua is a tiny and easy to use ECS (Entity Component System) engine for
	game development

	This is a minified version of ECS-Lua, to see the full source code visit
	https://github.com/nidorx/roblox-ecs

	------------------------------------------------------------------------------

	MIT License

	Copyright (c) 2021 Alex Rodin

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.]]

HEADER = "--[[\n"..HEADER.."\n]]\n"

package.path = package.path .. ";modules/?.lua"

local function concat()
   local concatContent = {
      HEADER,
      "local __M__, __F__ = {}, {}",
      "local function __REQUIRE__(m)",
      "   if (not __M__[m]) then",
      "      __M__[m] = { r = __F__[m]() }",
      "   end",
      "   return __M__[m].r",
      "end",   
      "",   
   }
   
   for i,name in ipairs(SRC_FILES) do
      local sourceFile = io.open("./src/"..name..".lua", "r")
      if not sourceFile then
         error("Could not open the input file `" .. OUTPUT_MINIFIED .. "`", 0)
      end
   
      local content = sourceFile:read( "*a" )
   
      for _,oname in ipairs(SRC_FILES) do
         content = content:gsub('require[(]["\']'..oname..'["\'][)]', '__REQUIRE__("'..oname..'")')
      end
   
      table.insert(concatContent, table.concat({
         '__F__["'..name..'"] = function()',
         ("   -- src/"..name..".lua\n"..content):gsub("\n", "\n   "),
         "end",
         "",
      }, "\n"))
      sourceFile:close()
   end
   
   table.insert(concatContent, 'return __REQUIRE__("ECS")')
   
   -- write ECS_concat.lua
   local fileConcat = io.open(OUTPUT_CONCAT..".lua", "w" )
   fileConcat:write( table.concat(concatContent, "\n"))
   fileConcat:close()  
   
   -- teste import
   local ecsConcat = require(OUTPUT_CONCAT)
   _G.ECS = nil
end

local function minify()
   local min = require('minify')

   local sourceFile = io.open(OUTPUT_CONCAT..".lua", 'r')
   if not sourceFile then
      error("Could not open the input file `" .. OUTPUT_CONCAT..".lua" .. "`", 0)
   end

   local data = sourceFile:read('*all')
   local ast = min.CreateLuaParser(data)
   local global_scope, root_scope = min.AddVariableInfo(ast)

   min.MinifyVariables(global_scope, root_scope)
   min.StripAst(ast)
   local minifiedContent = min.AstToString(ast)

   -- write ECS.lua
   local fileMinified = io.open(OUTPUT_MINIFIED..".lua", "w" )
   fileMinified:write(HEADER .. minifiedContent)
   fileMinified:close()

   -- teste import
   local ecsMinified = require(OUTPUT_MINIFIED)
   _G.ECS = nil
end

concat()
minify()
