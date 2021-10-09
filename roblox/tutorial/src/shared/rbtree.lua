--[[
   Red Black Trees ()

   (C) 2020  Alex Rodin <contato@alexrodin.info>

   Based on https://github.com/sjnam/lua-rbtree/blob/master/rbtree.lua

   Links
      https://en.wikipedia.org/wiki/Red%E2%80%93black_tree
      https://adtinfo.org/libavl.html/Red_002dBlack-Trees.html
--]]

-- colors
local BLACK = 0
local RED   = 1

-- https://en.wikipedia.org/wiki/Sentinel_node
local RB_SENTINEL = { key = 0, color = BLACK }

local function __rb_rotate_left(tree, node)
   local right = node.right
   node.right = right.left

   if right.left ~= RB_SENTINEL then
       right.left.parent = node
   end

   right.parent = node.parent

   if node.parent == RB_SENTINEL then
       tree.root = right
   elseif node == node.parent.left then
       node.parent.left = right
   else
       node.parent.right = right
   end

   right.left = node
   node.parent = right
end

local function __rb_rotate_right(tree, node)
   local left = node.left
   node.left = left.right

   if left.right ~= RB_SENTINEL then
       left.right.parent = node
   end

   left.parent = node.parent

   if node.parent == RB_SENTINEL then
       tree.root = left
   elseif node == node.parent.right then
       node.parent.right = left
   else
       node.parent.left = left
   end

   left.right = node
   node.parent = left
end

--[[
   Usado na remoção de nós, faz a substituição de um nó pele seu filho
]]
local function __rb_replace(tree, node, child)
   if node.parent == RB_SENTINEL then
      tree.root = child
   elseif node == node.parent.left then
      node.parent.left = child
   else
      node.parent.right = child
   end
   child.parent = node.parent
end

--[[
   Obtém o nó mais a esquerda (o menor valor) a partir de um nó da árvore

   Se buscar a partir do root, obtém o menor valor de toda a arvore
]]
local function rb_minimum(node)
   while node.left ~= RB_SENTINEL do
      node = node.left
   end
   return node
end

--[[
   A partir de um nó da árvore, obtém o nó seguinte
]]
local function rb_next(node)
   if node == RB_SENTINEL then
      return nil
   end

   if node.parent == node then
      return nil
   end

   -- If we have a right-hand child, go down and then left as far as we can
   if node.right ~= RB_SENTINEL then
		return rb_minimum(node.right)
   end

   local parent

   -- No right-hand children. Everything down and left is smaller than us, so any 'next'
   -- node must be in the general direction of our parent. Go up the tree; any time the
   -- ancestor is a right-hand child of its parent, keep going up. First time it's a
   -- left-hand child of its parent, said parent is our 'next' node.
   while true do
      parent = node.parent
      if parent == RB_SENTINEL then
         return nil
      end
      if node == parent.right then
         node = parent
      else
         break
      end
   end

   return parent
end

--[[
   Insere um nó em uma árvore
]]
local function rb_insert(tree, node)
   local parent = RB_SENTINEL
   local root  = tree.root

   while root ~= RB_SENTINEL do
      parent = root
      if node.key < root.key then
         root = root.left
      else
         root = root.right
      end
   end

   node.parent = parent

   if parent == RB_SENTINEL then
      tree.root = node
   elseif node.key < parent.key then
      parent.left = node
   else
      parent.right = node
   end

   node.left   = RB_SENTINEL
   node.right  = RB_SENTINEL
   node.color  = RED

   -- insert-fixup
   while node.parent.color == RED do
      if node.parent == node.parent.parent.left then
         parent = node.parent.parent.right
         if parent.color == RED then
            node.parent.color = BLACK
            parent.color = BLACK
            node.parent.parent.color = RED
            node = node.parent.parent
         else
            if node == node.parent.right then
               node = node.parent
               __rb_rotate_left(tree, node)
            end
            node.parent.color = BLACK
            node.parent.parent.color = RED
            __rb_rotate_right(tree, node.parent.parent)
         end
      else
         parent = node.parent.parent.left
         if parent.color == RED then
            node.parent.color = BLACK
            parent.color = BLACK
            node.parent.parent.color = RED
            node = node.parent.parent
         else
            if node == node.parent.left then
               node = node.parent
               __rb_rotate_right(tree, node)
            end
            node.parent.color = BLACK
            node.parent.parent.color = RED
            __rb_rotate_left(tree, node.parent.parent)
         end
      end
   end

   tree.root.color = BLACK
end

--[[
   Remove um nó de uma árvore
]]
local function rb_delete(tree, node)
   if node == RB_SENTINEL then
      return
   end

   local x, w
   local y_original_color = node.color

   if node.left == RB_SENTINEL then
      x = node.right
      __rb_replace(tree, node, node.right)

   elseif node.right == RB_SENTINEL then
      x = node.left
      __rb_replace(tree, node, node.left)

   else
      local y = rb_minimum(node.right)
      y_original_color = y.color
      x = y.right
      if y.parent == node then
         x.parent = y
      else
         __rb_replace(tree, y, y.right)
         y.right = node.right
         y.right.parent = y
      end
      __rb_replace(tree, node, y)
      y.left = node.left
      y.left.parent = y
      y.color = node.color
   end

   if y_original_color ~= BLACK then
      return
   end

   -- delete-fixup
   while x ~= tree.root and x.color == BLACK do
      if x == x.parent.left then
         w = x.parent.right
         if w.color == RED then
            w.color = BLACK
            x.parent.color = RED
            __rb_rotate_left(tree, x.parent)
            w = x.parent.right
         end
         if w.left.color == BLACK and w.right.color == BLACK then
            w.color = RED
            x = x.parent
         else
            if w.right.color == BLACK then
               w.left.color = BLACK
               w.color = RED
               __rb_rotate_right(tree, w)
               w = x.parent.right
            end
            w.color = x.parent.color
            x.parent.color = BLACK
            w.right.color = BLACK
            __rb_rotate_left(tree, x.parent)
            x = tree.root
         end
      else
         w = x.parent.left
         if w.color == RED then
            w.color = BLACK
            x.parent.color = RED
            __rb_rotate_right(tree, x.parent)
            w = x.parent.left
         end
         if w.right.color == BLACK and w.left.color == BLACK then
            w.color = RED
            x = x.parent
         else
            if w.left.color == BLACK then
               w.right.color = BLACK
               w.color = RED
               __rb_rotate_left(tree, w)
               w = x.parent.left
            end
            w.color = x.parent.color
            x.parent.color = BLACK
            w.left.color = BLACK
            __rb_rotate_right(tree, x.parent)
            x = tree.root
         end
      end
   end

   x.color = BLACK
end

--[[
   Obtém um nó a partir da key

   Chaves menores estão a esquerda da arvore, valores maiores estão na direita
]]
local function rb_get(tree, key)
   local node = tree.root
   while node ~= RB_SENTINEL and key ~= node.key do
      if key < node.key then
         node = node.left
      else
         node = node.right
      end
   end
   return node
end

--[[
   Returns the first node (in sort order) of the tree
]]
local function rb_first(tree)
   if tree.root == RB_SENTINEL then
      return nil
   end
   return rb_minimum(tree.root)
end

--[[
   Itera em toda a árvore retornando a lista de nós que se aplicam na função teste
]]
local function rb_filter(tree, testFn)
   local nodes = {}
   local node = rb_first(tree)
   while node ~= nil do
      if testFn(node) then
         table.insert(nodes, node)
      end
      node = rb_next(node)
   end
   return nodes
end

--[[
   Obtém todos os nós da árvore
]]
local function rb_all(tree)
   local nodes = {}
   local node = rb_first(tree)
   while node ~= nil do
      table.insert(nodes, node)
      node = rb_next(node)
   end
   return nodes
end

--[[
   Cria uma nova árvore

   Returns
      struct Tree {
         root:    Node     - Tree's root.
         count:   Number   - Number of items in tree
      };
]]
local function rb_create()
   return {
      root  = RB_SENTINEL,
      count = 0
   }
end

--[[
   Cria um novo nó para a árvore

   Returns
      struct Node {
         key      : Number
         data     : any
         parent   : Node
         left     : Node
         right    : Node
         color    : BLACK=0, RED=1
      }
]]
local function rb_node(key, data)
   return {
      key   = key,
      data  = data
   }
end

--- teste
local tree = rb_create()

rb_insert(tree, rb_node(1, 'one'))
rb_insert(tree, rb_node(4, 'four'))
rb_insert(tree, rb_node(5, 'five'))
rb_insert(tree, rb_node(9, 'nine'))
rb_insert(tree, rb_node(3, 'three'))
rb_insert(tree, rb_node(0, 'zero'))
rb_insert(tree, rb_node(2, 'two'))
rb_insert(tree, rb_node(8, 'eight'))
rb_insert(tree, rb_node(6, 'six'))
rb_insert(tree, rb_node(7, 'seven'))

print('-- MUST PRINT 0')
local node = rb_first(tree)
print('#', node.key, node.data)

print('-- MUST PRINT FROM 0 TO 9')
local listp = rb_filter(tree, function(node)
   print('#', node.key, node.data)
   return node.key % 2 == 0
end)

local listi = rb_filter(tree, function(node)
   return node.key % 2 ~= 0
end)

print('-- MUST PRINT EVEN NUMBERS')
for _, node in ipairs(listp) do
   print('#', node.key, node.data)
end

print('-- MUST PRINT ODD NUMBERS')
for _,node in ipairs(listi) do
   print('#', node.key, node.data)
end

print('-- MUST ONLY PRINT ODD NUMBERS')
for _,node in ipairs(listp) do
   rb_delete(tree, node)
end
rb_filter(tree, function(node)
   print('#', node.key, node.data)
   return false
end)

print('-- MUST PRINT 1')
local node = rb_first(tree)
print('#', node.key, node.data)

print('-- SHOULD NOT PRINT ANYTHING')
for _,node in ipairs(listi) do
   rb_delete(tree, node)
end
rb_filter(tree, function(node)
   print('#', node.key, node.data)
   return false
end)

return {
   rb_create   = rb_create, 
   rb_node     = rb_node, 
   rb_first    = rb_first, 
   rb_filter   = rb_filter,
   rb_minimum  = rb_minimum,
   rb_next     = rb_next
}