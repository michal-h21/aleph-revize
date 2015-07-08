#!/usr/bin/env texlua
local conffile = arg[1]
if not conffile then 
	print [[Musíte zadat název zpracovávaného adresáře, ve kterém je umístěný 
	soubor config.lua s cestou k zpracovávaným souborům]]
	return false
end
dir =      string.gsub(conffile:gsub("/config.lua$",""),'/','') ..'/'
conffile  = dir ..  "config.lua"
dofile(conffile)
--local t = date.microtime(
--print(config.xml)
function rev_parse(filename)
	local f = io.open(filename,"r")
	local codes = {}
	local pos = 1
	for line in f:lines() do
		local code, koje = line:match("([^@]+)@%s*(.*)%s*")
		--print(code, koje)
		--local codes[code] = codes[code] and {codes[code],koje} or koje
		if codes[code] then
			table.insert(codes[code],{koje = koje,pos = pos})
		else
			codes[code] = {{koje = koje,pos = pos}}
		end
		pos = pos + 1
	end
	return codes
end



local filename = dir .. config.xml
local f = io.open(filename,"r")
local i = 0
local sec1 = 0
local codes = rev_parse(dir .. config.kody)
local x = os.clock()
local zaznamy = {}
local zaz =  nil
local c = 0
local pattern = "<[^>]+>([^<]+)"
local function makeZaz(s)
	return s:match(pattern)
end
local ck = ""
local  i = 0 
local akce = {}
akce[3]   = "ck"
akce[6]   = "status"
akce[75]  = "citace"
akce[15]  = "lokace"
akce[17]  = "signatura"
akce[20]  = "signatura2"
akce[118] = "pujceno"
akce[5]   = "material"

for line in f:lines() do
	if zaz then c = c + 1 end
	--i = i + string.len(line)
	if line == "<section-02>" then 
		sec1 =  sec1+1 
		if zaz then 
			table.insert(zaznamy, zaz)
		end
		zaz = {}
		c = 0
	end
	--[[
	if c == 75 then zaz["citace"] = makeZaz(line) 
	elseif c == 3 then 
		ck = makeZaz(line)
		zaz["ck"] = ck
	elseif c == 118 then 
		zaz.pujceno = makeZaz(line)
	end
	--]]
	local ak = akce[c]
	if ak then zaz[ak] = makeZaz(line) end 
end
f:close()
function print_zaz(v)
	local function add_quotes(s)
		local s = s or '-'
    if s == '' then s = '-' end
		return '"' .. s ..'"'
	end
	local ck = v.ck
	local pozice = v.pos
	local status = add_quotes(v.status)
	local lokace = add_quotes(v.lokace)
	local poznamka = add_quotes(v.poznamka) or '"-"'
  local citace = add_quotes(v.citace)
	local signatura = add_quotes(v.signatura)
	local signatura2 = add_quotes(v.signatura2)
	local chyba = v.chyba  -- or add_quotes("OK!")
	local material = add_quotes(v.material)
	local pujceno = add_quotes(v.pujceno)
	if #chyba == 0 then table.insert(chyba,"OK!") end
	print(pozice, ck, signatura, citace, add_quotes("-"), poznamka, lokace, status,add_quotes(table.concat(chyba,' ')),signatura2, material, pujceno)
end 
local y = os.clock()
local p = 0

-- Kódy chyb:
-- CH-1 ČK není v nasnímaných ČK dané revize"
-- CH-2 ČK je v nasnímaných ČK dané revize a současně je vypůjčen"
-- CH-3 ČK je vyřazen"
-- CH-4 ČK je vyřazen a současně je vypůjčen"
-- CH-5 Dokument je z jiné Sbírky"
-- CH-6 ČK je v nasnimaných ČK dané revize a současně je vyřazen"


for k,v in pairs(zaznamy) do
	local function add_chyba(ch)
		table.insert(v.chyba,ch)
	end
	v.chyba = {}
	local ck = v.ck
	v.pos = k
	if codes[ck] then
		if v.pujceno ~="N" then 
			add_chyba("CH-2")
			p = p + 1
			--print (k,v.ck, v.citace, v.pujceno)
		end
		if v.status == "Vyřazeno" then add_chyba("CH-6") 
		elseif v.status == "Grantová výp." then add_chyba("CH-7")
		end
	else
		--print (k,v.ck, v.citace, v.pujceno)
		--print_zaz(v)
		if v.pujceno ~="Y" and v.status ~= "Vyřazeno" then
  		add_chyba("CH-1")
		end
		--if v.status = ""
	end
	if v.status == "Vyřazeno" then 
		if v.pujceno == "N" then
			add_chyba("CH-3")
		else
			add_chyba("CH-4")
		end
	end
	if v.lokace ~= config.lokace then add_chyba("CH-5") end
end

--print(string.format("Parsing  time: %.2f\n",  y - x))
--print(string.format("Printing time: %.2f\n", os.clock() - y))
for _,v in pairs(zaznamy) do
	print_zaz(v)
end

local j = 0
--for _,_  in pairs(codes) do j = j+ 1 end
--print("Počet záznamů a počet načtenejch", i - p,j)
