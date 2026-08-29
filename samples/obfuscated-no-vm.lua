local a = {}
local g = function(b, c)
  if (((1 + 1) == 2) and a[b]) then
    return a[b]
  end
  local d = {}
  for e = 1, #b do
    d[e] = string.char(bit32.bxor(b[e], c))
  end
  local f = table.concat(d)
  a[b] = f
  return f
end
local Players = game:GetService(g({10, 54, 59, 35, 63, 40, 41}, 90))
local h = Players.LocalPlayer
if (((15 * 15) == 225) and h) then
  print((g({10, 54, 59, 35, 63, 40, 122, 60, 53, 47, 52, 62, 96, 122}, 90) .. h.Name))
  print((g({15, 41, 63, 40, 19, 62, 96, 122}, 90) .. h.UserId))
  print((g({25, 50, 59, 40, 59, 57, 46, 63, 40, 122, 63, 34, 51, 41, 46, 41, 96, 122}, 90) .. tostring((h.Character ~= nil))))
else
  print(g({20, 53, 122, 42, 54, 59, 35, 63, 40, 122, 60, 53, 47, 52, 62}, 90))
end
wait(1)
print(g({9, 57, 40, 51, 42, 46, 122, 63, 34, 63, 57, 47, 46, 63, 62, 122, 41, 47, 57, 57, 63, 41, 41, 60, 47, 54, 54, 35, 123}, 90))