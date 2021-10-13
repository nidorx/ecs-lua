local lu = require('luaunit')

local System = require('System')
local SystemExecutor = require('SystemExecutor')

TestSystemExecutor = {}

function TestSystemExecutor:test_ExecProcessTransformRender()
   local steps = {
      render = 'ExecRender', 
      process = 'ExecProcess',
      transform = 'ExecTransform'
   }

   for step, method in pairs(steps) do      
      local world = { version = 10 }   
      local log = {}
   
      local system1 = {
         Step = step,
         Order = 1,
         Update = function()
            table.insert(log, 1)
         end,
         version = 0,
         ShouldUpdate = function()
            return true
         end
      }

      local system2 = {
         Step = step,
         Order = 2,
         Update = function()
            table.insert(log, 2)
         end,
         version = 0,
         ShouldUpdate = function()
            return false
         end
      }
      
      local system3 = {
         Step = step,
         Order = 3,
         Update = function()
            table.insert(log, 3)
         end,
         version = 0,
         ShouldUpdate = function()
            return true
         end
      }
   
      local executor = SystemExecutor.New(world, {system1, system2, system3})   
      executor[method](executor, {})
   
      lu.assertEquals(log, {1, 3})  
      lu.assertEquals(system1.version, 11)  
      lu.assertEquals(system2.version, 0)  
      lu.assertEquals(system3.version, 12)  
   end
end

function TestSystemExecutor:test_Coroutine()

   
   local log = {}
   local value = 0

   local co = coroutine.create(function ()	
      -- https://github.com/wahern/cqueues/issues/231#issuecomment-562838785
      local i, len = 0, 10000-1
      -- while i <= len do
      --    i = i + 1
      --    if i%1000 == 0 then
      --       print( "Before yield", i, value)
      --       coroutine.yield()	
      --       print( "After yield", i, value)
      --    end	
      -- end
      for i=1,3000 do		
         if i%1000 == 0 then
            table.insert(log, i)
            table.insert(log, value)
            coroutine.yield()	
            table.insert(log, value)
         end		
      end
   end)
   
   coroutine.resume(co)
   lu.assertEquals(log, {1000, 0})
   value = 1

   coroutine.resume(co)
   lu.assertEquals(log, {1000, 0, 1, 2000, 1})
   value = 2

   coroutine.resume(co)
   lu.assertEquals(log, {1000, 0, 1, 2000, 1, 2, 3000, 2})
   value = 3

   coroutine.resume(co)
   lu.assertEquals(log, {1000, 0, 1, 2000, 1, 2, 3000, 2, 3})
   value = 3
end

function TestSystemExecutor:test_ExecTasks()
   local steps = {
      render = 'ExecRender', 
      process = 'ExecProcess',
      transform = 'ExecTransform'
   }

   local world = { version = 10 }   
   local log = {}
   local logBeforeYield = {}
   local logAfterYield = {}

   local Task_A = System.Create('task', function()
      -- delay execution to ensure test flow
      local i = 0
      while i <= 4000 do
         i = i + 1
         if i%1000 == 0 then
            table.insert(logBeforeYield, i)
            coroutine.yield()
            table.insert(logAfterYield, i+1)
         end
      end
      
      table.insert(log, 'A')
      lu.assertEquals(logBeforeYield, {1000, 2000, 3000, 4000})
      lu.assertEquals(logAfterYield, {1001, 2001, 3001, 4001})
   end)

   local Task_B = System.Create('task', function()
      table.insert(log, 'B')
   end)

   local Task_C = System.Create('task', function()
      table.insert(log, 'C')
   end)

   local Task_D = System.Create('task', function()
      table.insert(log, 'D')
   end)

   local Task_E = System.Create('task', function()
      table.insert(log, 'E')
   end)

   local Task_F = System.Create('task', function()
      table.insert(log, 'F')
   end)

   local Task_G = System.Create('task', function()
      table.insert(log, 'G')
   end)
   

   local Task_H = System.Create('task', function(self)
      table.insert(log, 'H')
   end)

   --[[
      ┌─┐      ┌─┐            ┌─┐
      │A│◄─────┤C│◄────┬──────┤F│◄────┐
      └─┘      └┬┘     │      └┬┘     │
                │     ┌┴┐      │     ┌┴┐
           ┌────┘     │E│◄─────┘     │H│
           │          └┬┘            └┬┘
           │           │              │
      ┌─┐  │   ┌─┐     │      ┌─┐     │
      │B│◄─┴───┤D│◄────┴──────┤G│◄────┘
      └─┘      └─┘            └─┘

      A - has no dependency
      B - has no dependency
      C - Depends on A,B
      D - Depends on B
      E - Depends on A,B,C,D
      F - Depends on A,B,C,D,E
      G - Depends on B,D
      H - Depends on A,B,C,D,E,F,G

      Completion order will be B,D,G,A,C,E,F,H      
   ]]
   Task_A.Before = {Task_C}
   Task_B.Before = {Task_D}
   Task_C.After = {Task_B}
   Task_D.Before = {Task_G}
   Task_F.After = {Task_E}
   Task_E.After = {Task_D, Task_C}
   Task_C.Before = {Task_F}
   Task_H.After = {Task_F, Task_G}
   
   local task_a = Task_A.New(world, {})
   local task_b = Task_B.New(world, {})
   local task_c = Task_C.New(world, {})
   local task_d = Task_D.New(world, {})
   local task_e = Task_E.New(world, {})
   local task_f = Task_F.New(world, {})
   local task_g = Task_G.New(world, {})
   local task_h = Task_H.New(world, {})

   local executor = SystemExecutor.New(world, {task_a, task_b, task_c, task_d, task_e, task_f, task_g, task_h})

   executor:ScheduleTasks({})
   
   local MaxExecutionTime = 0.5
   executor:ExecTasks(MaxExecutionTime)

   lu.assertEquals(log, {'B','D','G','A','C','E','F','H'}) 
   lu.assertEquals(logBeforeYield, {1000, 2000, 3000, 4000})  
   lu.assertEquals(logAfterYield, {1001, 2001, 3001, 4001})   
end

function TestSystemExecutor:test_ExecOnEnter()
   local world = { version = 10 }   
      
   local changedEntities = {
      [{id = 1, archetype='Arch_1'}] = 'Arch_0',
      [{id = 2, archetype='Arch_1'}] = 'Arch_0',
      [{id = 3, archetype='Arch_2'}] = 'Arch_1',
      [{id = 4, archetype='Arch_3'}] = 'Arch_1',
      [{id = 5, archetype='Arch_3'}] = 'Arch_3',
      [{id = 6, archetype='Arch_3'}] = 'Arch_0',
   }

   local log = {
      Arch_1 = {},
      Arch_2 = {},
      Arch_3 = {},
   }
   local logExpected = {
      Arch_1 = { ["1_1"] = true, ["1_2"] = true},
      Arch_2 = {},
      Arch_3 = { ["3_4"] = true, ["3_6"] = true},
   }

   local systemArch1 = {
      Step = 'process',
      Order = 1,
      OnEnter = function(s, Time, entity)
         log.Arch_1["1_"..entity.id] = true
      end,
      version = 0,
      Query = {
         isQuery = true,
         Match = function(s, archetypeNew)
            return archetypeNew == 'Arch_1'
         end
      }
   }

   local systemNoQuery = {
      Step = 'process',
      Order = 2,
      OnEnter = function(s, Time, entity)
         log.Arch_1["2_"..entity.id] = true
      end,
      version = 0
   }

   local systemArch3 = {
      Step = 'process',
      Order = 3,
      OnEnter = function(s, Time, entity)
         log.Arch_3["3_"..entity.id] = true
      end,
      version = 0,
      Query = {
         isQuery = true,
         Match = function(s, archetypeNew)
            return archetypeNew == 'Arch_3'
         end
      }
   }

   local executor = SystemExecutor.New(world, {systemArch1, systemNoQuery, systemArch3})   

   

   executor:ExecOnExitEnter({}, changedEntities)
   lu.assertEquals(log, logExpected)  
   lu.assertEquals(systemArch1.version, 12)  
   lu.assertEquals(systemNoQuery.version, 0)  
   lu.assertEquals(systemArch3.version, 14)  
   lu.assertEquals(world.version, 14)  


   executor:ExecOnExitEnter({}, changedEntities)
   lu.assertEquals(log, logExpected)  
   lu.assertEquals(systemArch1.version, 16)  
   lu.assertEquals(systemNoQuery.version, 0)  
   lu.assertEquals(systemArch3.version, 18)  
   lu.assertEquals(world.version, 18)  

   executor:ExecOnExitEnter({}, {})
   lu.assertEquals(log, logExpected)  
   lu.assertEquals(systemArch1.version, 16)  
   lu.assertEquals(systemNoQuery.version, 0)  
   lu.assertEquals(systemArch3.version, 18)  
   lu.assertEquals(world.version, 18)
end

function TestSystemExecutor:test_ExecOnExit()
   local world = { version = 10 }   
      
   local changedEntities = {
      [{id = 1, archetype='Arch_1'}] = 'Arch_0',
      [{id = 2, archetype='Arch_1'}] = 'Arch_3',
      [{id = 3, archetype='Arch_2'}] = 'Arch_1',
      [{id = 4, archetype='Arch_3'}] = 'Arch_1',
      [{id = 5, archetype='Arch_2'}] = 'Arch_3',
      [{id = 6, archetype='Arch_3'}] = 'Arch_3',
   }

   local log = {
      Arch_1 = {},
      Arch_2 = {},
      Arch_3 = {},
   }
   local logExpected = {
      Arch_1 = { ["1_3"] = true, ["1_4"] = true},
      Arch_2 = {},
      Arch_3 = { ["3_2"] = true, ["3_5"] = true},
   }

   local systemArch1 = {
      Step = 'process',
      Order = 1,
      OnExit = function(s, Time, entity)
         log.Arch_1["1_"..entity.id] = true
      end,
      version = 0,
      Query = {
         isQuery = true,
         Match = function(s, archetypeNew)
            return archetypeNew == 'Arch_1'
         end
      }
   }

   local systemNoQuery = {
      Step = 'process',
      Order = 2,
      OnExit = function(s, Time, entity)
         log.Arch_1["2_"..entity.id] = true
      end,
      version = 0
   }

   local systemArch3 = {
      Step = 'process',
      Order = 3,
      OnExit = function(s, Time, entity)
         log.Arch_3["3_"..entity.id] = true
      end,
      version = 0,
      Query = {
         isQuery = true,
         Match = function(s, archetypeNew)
            return archetypeNew == 'Arch_3'
         end
      }
   }

   local executor = SystemExecutor.New(world, {systemArch1, systemNoQuery, systemArch3})   

   executor:ExecOnExitEnter({}, changedEntities)
   lu.assertEquals(log, logExpected)  
   lu.assertEquals(systemArch1.version, 12)  
   lu.assertEquals(systemNoQuery.version, 0)  
   lu.assertEquals(systemArch3.version, 14)  
   lu.assertEquals(world.version, 14)  


   executor:ExecOnExitEnter({}, changedEntities)
   lu.assertEquals(log, logExpected)  
   lu.assertEquals(systemArch1.version, 16)  
   lu.assertEquals(systemNoQuery.version, 0)  
   lu.assertEquals(systemArch3.version, 18)  
   lu.assertEquals(world.version, 18)  

   executor:ExecOnExitEnter({}, {})
   lu.assertEquals(log, logExpected)  
   lu.assertEquals(systemArch1.version, 16)  
   lu.assertEquals(systemNoQuery.version, 0)  
   lu.assertEquals(systemArch3.version, 18)  
   lu.assertEquals(world.version, 18)
end

function TestSystemExecutor:test_ExecOnRemove()
   local world = { version = 10 }   
      
   local removedEntities = {
      [{id = 1, archetype='Arch_1'}] = 'Arch_0',
      [{id = 2, archetype='Arch_1'}] = 'Arch_0',
      [{id = 3, archetype='Arch_2'}] = 'Arch_1',
      [{id = 4, archetype='Arch_2'}] = 'Arch_1',
      [{id = 5, archetype='Arch_0'}] = 'Arch_3',
      [{id = 6, archetype='Arch_0'}] = 'Arch_3',
   }

   local log = {
      Arch_1 = {},
      Arch_2 = {},
      Arch_3 = {},
   }
   local logExpected = {
      Arch_1 = { ["1_3"] = true, ["1_4"] = true},
      Arch_2 = {},
      Arch_3 = { ["3_5"] = true, ["3_6"] = true},
   }

   local systemArch1 = {
      Step = 'process',
      Order = 1,
      OnRemove = function(s, Time, entity)
         log.Arch_1["1_"..entity.id] = true
      end,
      version = 0,
      Query = {
         isQuery = true,
         Match = function(s, archetypeNew)
            return archetypeNew == 'Arch_1'
         end
      }
   }

   local systemNoQuery = {
      Step = 'process',
      Order = 2,
      OnRemove = function(s, Time, entity)
         log.Arch_1["2_"..entity.id] = true
      end,
      version = 0
   }

   local systemArch3 = {
      Step = 'process',
      Order = 3,
      OnRemove = function(s, Time, entity)
         log.Arch_3["3_"..entity.id] = true
      end,
      version = 0,
      Query = {
         isQuery = true,
         Match = function(s, archetypeNew)
            return archetypeNew == 'Arch_3'
         end
      }
   }

   local executor = SystemExecutor.New(world, {systemArch1, systemNoQuery, systemArch3})   

   executor:ExecOnRemove({}, removedEntities)
   lu.assertEquals(log, logExpected)  
   lu.assertEquals(systemArch1.version, 12)  
   lu.assertEquals(systemNoQuery.version, 0)  
   lu.assertEquals(systemArch3.version, 14)  
   lu.assertEquals(world.version, 14)  


   executor:ExecOnRemove({}, removedEntities)
   lu.assertEquals(log, logExpected)  
   lu.assertEquals(systemArch1.version, 16)  
   lu.assertEquals(systemNoQuery.version, 0)  
   lu.assertEquals(systemArch3.version, 18)  
   lu.assertEquals(world.version, 18)  

   executor:ExecOnRemove({}, {})
   lu.assertEquals(log, logExpected)  
   lu.assertEquals(systemArch1.version, 16)  
   lu.assertEquals(systemNoQuery.version, 0)  
   lu.assertEquals(systemArch3.version, 18)  
   lu.assertEquals(world.version, 18)
end
