local input = arg[1] or "dohledavky.tsv"
local src = io.open(input,"r")
if not src then
  print [[
    použití:
    texlua printpujcene.lua tabulka s publikacemi < kodykfiltrace

    vypíše tabulku s publikacemi s odfiltrovanými záznamy, jejichž čárový kód byl
    v souboru kodykfiltraci
    ]]
  os.exit()
end
local kody = {}
for line in src:lines() do
  local ck = line:match("(259[0-9]+)")
  if ck then
    kody[ck] = line
  end
end

src:close()

for line in io.lines() do
  local ck = line:match("(259[0-9]+)")
  if kody[ck] then kody[ck] = nil 
    -- print("mame", ck)
  else
    -- print("nemame", ck)
  end
end

local i = 0
for _, line in pairs(kody) do
  i = i + 1
  print(line)
end
-- print(i)
