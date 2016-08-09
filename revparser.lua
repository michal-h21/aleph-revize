#!/usr/bin/env texlua
kpse.set_program_name("luatex")
local lapp = require "lapp-mk4"

local msg = [[
  -t,--tex Výstup v TeXu
	-p,--preskacka Signatury byly načítané na přeskáčku
  <command>  (string) Příkaz
  <kody>     (string) Zpracovávaný adresář se souborem config.lua
Možné příkazy
   navic     - najde záznamy načtené při revizi, které nejsou v xml souboru z 
               alephu většinou jsou to špatné kódy nebo jednotky z jiných 
               lokací nebo signatur. Vypíše i jednotky okolo, aby šly líp 
               hledat.
   dupl      - víckrát načtené čárové kódy
   chyby     - chyby z xml souboru - hlavně nenačtené kódy
   signatury - signatury které nebyly načtené v řadě - můžou být špatně 
               založené. Parametr -p se může použít pokud byly načítaní 
               obráceně. Metoda hledání není přesná, je třeba kontrola v 
               souboru načtených čk.
               Je možné zadat pozice od kud kam se má jaká metoda použít:
               ./revparser.lua -p signatury 1 1330  - byly načítané obráceně
               ./revparser.lua signatury 1330 2440  - správně načtené
   kody      - vytiskne seznam jednotek seřazených podle toho, jak byly načtené                jejich čárové kódy. Užitečné pro kontroly a dohledávky
   sig2      - pro studovnu, vytiskne špatně zařazené 2. signatury

Soubor config.lua:
	Musí exportovat pole config:
	config = {
		chyby  = "soubor s vygenerovanými chybami z alephu, ve formátu TSV",
		kody   = "načtené kódy z revize",
    lokace = "zracovávaná lokace",
    xml    = "xml výstup z Alephu",
    prefix = "Počáteční písmena zpracovávané signatury"
	}
]]

 hlavicka = ""
 paticka  = ""
 separator = "\t"
 newline = ""
 escape = function(s) return s end

function tableHead(msgs)
	print(table.concat(msgs,separator) ..  newline)
end

function tableFoot()
end
function tablePrint(tbl,msgs)
	tableHead(msgs)
	for _,radek in pairs(tbl) do
		print(escape(table.concat(radek, separator)) .. newline)
	end
	tableFoot()
end
local args = lapp(msg)

conffile  = args.kody
dir =      string.gsub(conffile:gsub("/config.lua$",""),'/','') ..'/'
conffile  = dir ..  "config.lua"
dofile(conffile)
filename  = dir .. config.kody
csvfile   = config.chyby and (dir .. config.chyby) or nil
if args.tex then
	hlavicka = [[
\documentclass{article}
\usepackage[czech]{babel}
\usepackage[T1]{fontenc}
\usepackage{tgschola}
\usepackage[utf8]{inputenc}
\usepackage{longtable}
\begin{document}
	]]
	paticka = [[
\end{document}
	]]

		escape = function(t) 
			return string.gsub(t,"[$]",".")
		end
	newline = '\\\\'
	separator = ' & '
	tableHead = function(msgs)
		print ('\\begin{longtable}{'.. string.rep("l",#msgs) ..'}')
	  print(escape(table.concat(msgs,separator)) ..  newline)
	end
	tableFoot = function()
print('\\end{longtable}')
	end
end

print(hlavicka)
local i = os.clock()

function addZaznam(aleph)
	local v = aleph or {}
	local ck = v[2]
	local nazev = v[4] --unicode.utf8.sub(v[4],2,22)
	local signatura = v[3]
	local lokace = v[7]
	local status = v[8]
	local chyba = v[9]
  local sig2 = v[10]
	local boxy = p[ck] or {{box = "Nenačteno"}}
	local t = {}
	for _,p in pairs(boxy) do
		table.insert(t,p.koje)
	end
	boxy = table.concat(t,"; ")
	return {ck, signatura, boxy, sig2, nazev, lokace, status, chyba}
end

function rev_pos(filename)
	local f = io.open(filename,"r") or error("Nemůžu načíst soubor s kódy: "..filename)
	local codes = {}
	for line in f:lines() do
		local code, koje = line:match("([^@]+)@%s*(.*)%s*")
		table.insert(codes,{code = code, koje = koje})
	end
	return codes
end

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

function loadTSV(filename)
	local f = io.open(filename,"r")
	local t = {}
	for line in f:lines() do
		local l = {}
		for s in line:gmatch('([^\t]+)') do
			local p = s:gsub('[$&]','.') 
			table.insert(l,p)
		end
    t[l[2]] = l
		--table.insert(t,l)
	end
	return t
end

function duplicity(codes)
	-- POčítání duplicit - vyhodit do samostatný funkce
	local dupl = {}
	for k,v in pairs(codes) do
		--print(k, #v)
		if #v > 1 then 
			--print("Duplicita :",k)
			dupl[k] = v
		end
	end
	return dupl 
end

-- Funkce na hledání duplikátů s rozdílnejma 2. signaturama
function dvoji(codes)
	local dupl = {}
	for k, v in pairs(codes) do 
		local last = v[1].koje
		for _,s in pairs(v) do
			local s = s.koje
			if s ~= last then 
				dupl[k] = v
			end
			last = s
			--print(s)
		end
	end
	return dupl
end

function split_sg(sig,prefix)
	return sig:match('"('..prefix..')([0-9]+)/?([0-9%.%-a%,P%;% %/]*)([^0-9]*)"')
end
p = rev_parse(filename)
local hlavicka = {"Čárový kód", "Signatura", "Box", "Sig 2", "Název", "Lokace", "Status", "Chyba"}
chybkody = {}
chybkody["CH-1"] = "ČK není v nasnímaných ČK dané revize"
chybkody["CH-2"] = "ČK je v nasnímaných ČK dané revize a současně je vypůjčen"
chybkody["CH-3"] = "ČK je vyřazen"
chybkody["CH-4"] = "ČK je vyřazen a současně je vypůjčen"
chybkody["CH-5"] = "Dokument je z jiné Sbírky"
chybkody["CH-6"] = "ČK je v nasnimaných ČK dané revize a současně je vyřazen"
chybkody["CH-7"] = "Nasmínamý ČK se statusem Grantová výp."

if args.command == "dupl" then
	local d = duplicity(p)
	local j = loadTSV(csvfile)
	local cv = {}
	for _,v in pairs(j) do
		cv[v[2]] = v
	end
	local j = {}
	local m = {"Čárový kód","Signatura", "2. signatura","Název", "pozice"}
	for k,v in pairs(d) do
		--print(k,v[1])
		local last = v[1].pos
		local c = {}
		local t = false
		local zaz = cv[k] or {}
		local sig = zaz[3] or "Chybí"
		local naz = zaz[4] or ".Chybí"
		naz = unicode.utf8.sub(naz,2,22)
		for _,n in pairs(v) do
			local pos = n.pos
			if math.abs(pos - last) > 1 then t = true end
   		table.insert(c,{k,sig,n.koje,naz, n.pos})
			last = pos
		end
		if t then for _,q in pairs(c) do table.insert(j,q) end end
	end
	tablePrint(j,m)
	--local 
elseif args.command == "dvoje" then
	local x = duplicity(p)
	local d = dvoji(x)
	local j = {}
	local m = {"Čárový kód","2. signatura"}
	for k,v in pairs(d) do
		--print(k,v[1])
		table.insert(j,{k,table.concat(v,";")})
	end
	tablePrint(j,m)
elseif args.command == "csv" then
	local tableHead = function(a,j)
		print('\\begin{tabular}{llp{12em}lllll}')
	end
	local j = loadTSV(csvfile) 
	tablePrint(j,{"","","","","",""})
elseif args.command == 'chyby' then
	local j = loadTSV(csvfile)
	local t ={}
	local k=  {}
  for _,v in pairs(j) do
    v[9] = string.gsub(v[9],'"','')
		if v[9] ~='OK!' then -- and v[7] == 'Rett-studovna' then
			--local s = unicode.utf8.sub(v[4],1,9)
			--local p = {v[2],v[3],s,v[8],v[9]}
			local chyby = {}
			for c in v[9]:gmatch('([^%s"]+)') do
				local chyba = chybkody[c] or c
				table.insert(chyby,chyba)
			end
			v[9] = table.concat(chyby,"; ")
			table.insert(t,addZaznam(v))
		end
	end
	--local m = {"Čárový kód","signatura","Název","cosi"} 
	tablePrint(t,hlavicka)
elseif args.command == 'navic' then
	print "Kódy načtené při revizi, ale chybějící ve vygenerovaném souboru z Alephu"
	local j = loadTSV(csvfile)
	local out = {}
	local ck = {}
	for k,v in pairs(j) do
		--print (v[2])
		ck[v[2]] = v
	end
	local p = rev_pos(filename)
	local function printCodes(start,fin)
		--print(start,fin)
		if fin < 6 and fin > 0 then start = 1 
		elseif fin < 1 then return 
		elseif fin > #p then fin = #p
		end	
	  for i = start,fin do
			local car = p[i].code
			local v = ck[car]
			if v then
			  local s = unicode.utf8.sub(v[4],2,22)
			  table.insert(out,{v[2],v[3],s})
			else

			end
		end
	end
	for k,v in pairs(p) do
		if not ck[v.code] then 
			printCodes(k - 6,k -1)
			table.insert(out,{v.code, v.koje,"neznámý kód"}) 
			printCodes(k + 1,k +5)
			table.insert(out,{"-----","-----","-----"})
		end
	end
	tablePrint(out,{"Čárový kód","Signatura","Název", "X"})
elseif args.command == "stud" then
	local j = loadTSV(csvfile)
	local t = {}
	for k,v in pairs(j) do
		if v[7] == '"Rett-studovna"' and p[v[2]] then
			table.insert(t,addZaznam(v))
		end
	end
	tablePrint(t, hlavicka)
elseif args.command == "kody" then
	local j = loadTSV(csvfile)
	table.insert(hlavicka,1,"Pozice")
	local f = rev_pos(filename)
	local t = {}
	for k,v in pairs(f) do
		local c = j[v.code]
		if c then
			local j = addZaznam(c)
			j[3] = v.koje
			table.insert(j,1,k)
		  table.insert(t,j) 
		else
			table.insert(t,{k,v.code,v.koje,"Nenalezeno v Alephu"})
	  end
	end
	tablePrint(t,hlavicka)
elseif args.command == "signatury" then
	local k = rev_pos(filename)
	local j = loadTSV(csvfile)
	local prefix = config.prefix
	local t = {}
	local chyby = {}
	for pos,v in pairs(k) do
		local z = j[v.code] 
		if z then
		  local sig = z[3]
		  local pref,num,dil,pis = split_sg(sig,prefix)
      if not pref or pref == ""  then pref, num = sig:match("\"([A-Za-z]+)([0-9]+)") end
			if pref~=prefix then
        print("wtf", pref, sig)
		    table.insert(chyby,{"Chybná signatura",pos,sig,pref,num,dil,pis})
			else
				table.insert(t,{num = num, pos = pos, code = v.code})
		  end
		else
			table.insert(chyby,{"Nemohu najít záznam ke kódu: ",pos,v.code})
		end
	end
	tablePrint(chyby,{"Zpráva","Pozice","Čárový kód","","","","","",""})
	local ch = {}

	local chyba_insert= function(v)
				local zaz = j[v.code]
				if zaz then
				  local sig = zaz[3]
				  local nazev = unicode.utf8.sub(zaz[4],2,22)
  			  return {"Chybná pozice", v.pos, v.code,sig,nazev}
				else
					return {"Nemůžu najít záznam",v.code,v.pos}
				end
	end
	local start = tonumber(args[1]) or 1
	local konec = tonumber(args[2]) or #t
	local prah = 10000 
  if args.preskacka then 
		local br = t[start].num
		local last = br
		local rada = 0
		for i = start, konec do
			local v = t[i]
			local num = v.num
			if last < num or math.abs(last - num) > prah  then
				table.insert(ch,chyba_insert(v))
			end
			last = num
		end
	else
		local last = t[start].num
		for i=start,konec do 
			local v = t[i]
			local num = v.num
			if num < last or math.abs(last - num) > prah then
				table.insert(ch,chyba_insert(v))
			end
			last = num
		end
	end
	tablePrint(ch,{"Zpráva","Pozice","ČK","Signatura","Název"})
elseif args.command == "sig2" then
    local lower =  unicode.utf8.lower
    local gsub = unicode.utf8.gsub
    local cache = {}
    local diacritics = {["á"]="a", ["č"] = "c", ["ď"] = "d", ["é"] = "e", ["ě"] = "e", ["í"] = "i", ["ň"] = "n", ["ó"] = "o", ["ř"] = "r", ["š"] = "s", ["ť"] = "t", ["ú"] = "u", ["ů"]= "u", ["ž"] = "z"}
    local normalize = function(s)
      if cache[s] then return cache[s] end
      local x = lower(s)
      x = x:gsub(" ", "")
      x = gsub(x,".", function(a)
        return diacritics[a] or a
      end)
      cache[s] = x
      return x
    end

      
		local j= loadTSV(csvfile)
		local ch = {}
		for _,z in pairs(j) do 
			local s = z[10]:match('([^"]+)')
			local ck = z[2]
			local k = p[ck]
			local nacteno =  {}
			local shoda = false
			if k then
				for _, v in pairs(k) do
					--for m,v in pairs(c) do
						if type(v) == "table" then
   						table.insert(nacteno, v.koje)
	   					--print(ck,v.koje,s)
              local koj = normalize(v.koje)
              local ns = normalize(s)
              -- print(koj, ns)
		  				if koj == ns then
			  				shoda = true
				  		end
						end
					--end 
				end
				if shoda == false then
          --local sig = z[3]
					--local nazev = unicode.utf8.sub(z[4],2,22)
					local i = addZaznam(z)
					-- table.insert(i,3,s)
					table.insert(ch,i)--{ck,sig,nazev, s, table.concat(nacteno,', ')})
				end
		  end
		end
		tablePrint(ch, {"Čk","Signatura", "Název", "2 signatura","Načteno"})

else
	print("Neznámý příkaz: ".. args.command)
	print(msg)
end
--print("Počet záznamů "..#p)
print(paticka)
