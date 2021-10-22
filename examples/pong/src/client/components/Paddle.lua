local Paddle = _G.ECS.Component({
   side = "left",
   hits = 0,
   target = 0,    -- -1 = bottom, 0 = middle, 1 = top
   position = 0   -- -1 = bottom, 0 = middle, 1 = top
})

return Paddle
