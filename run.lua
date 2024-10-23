#!/usr/bin/env luajit
local path = require 'ext.path'
local table = require 'ext.table'

local LuaTokenizer = require 'parser.lua.tokenizer'
local LeftTokenizer = LuaTokenizer:subclass()
function LeftTokenizer:initSymbolsAndKeywords(...)
	LeftTokenizer.super.initSymbolsAndKeywords(self, ...)
	self.symbols:insert'->'
end

local LuaParser = require 'parser.lua.parser'
local LeftParser = LuaParser:subclass()
function LeftParser:buildTokenizer(data)
	return LeftTokenizer(data, self.version, self.useluajit)
end

--[[ doesn't work for explist ...
function LeftParser:parse_exp()	-- for lowest precedence
--function LeftParser:parse_subexp()   -- for highest precedence
	local a = self:parse_expr_precedenceTable(1)
	--local a = LeftParser.super.parse_subexp(self)
	if not a then return end
	if self:canbe('->', 'symbol') then
		local b = self:parse_exp()
		--local b = self:parse_subexp()
		return self:node('_call', b, a)
	end
	return a
end
--]]

function LeftParser:parse_arrowcall_rhs(args, prefixexp)
	while true do
		if self:canbe('[', 'symbol') then
			prefixexp = self:node('_index', prefixexp, (assert(self:parse_exp(), 'unexpected symbol')))
			self:mustbe(']', 'symbol')
			prefixexp:setspan{from = from, to = self:getloc()}
		elseif self:canbe('.', 'symbol') then
			local sfrom = self:getloc()
			prefixexp = self:node('_index',
				prefixexp,
				self:node('_string', self:mustbe(nil, 'name'))
					:setspan{from = sfrom, to = self:getloc()}
			)
			:setspan{from = from, to = self:getloc()}
		elseif self:canbe(':', 'symbol') then
			prefixexp = self:node('_indexself',
				prefixexp,
				self:mustbe(nil, 'name')
			):setspan{from = from, to = self:getloc()}
			return self:node('_call', prefixexp, table.unpack(args))
				:setspan{from = from, to = self:getloc()}
		else
			return self:node('_call', prefixexp, table.unpack(args))
				:setspan{from = from, to = self:getloc()}
		end
	end
end


--local level = 0
--local function tprint(...) print(('\t'):rep(level), ...) end

-- hmm now how to change the parser to use a lhs call ...
-- lots of options ...
-- insert a new operator?  but that's for exprs which are single entries of explists ...
-- modify parse_prefixexp (so we get free statment support as well) , but there might be problems of it not telling _par from _call ... maybe ...)  gtting problems tho
-- cheat: new prefix token for "expect an arglist , then a call" ... so the -> goes before the args, not after ...
function LeftParser:parse_prefixexp()
--tprint('parse_prefixexp', self.t.token)
--level=level+1
	-- me cheating more and giving a prefix to the call args ...
	-- can't use [ because [[ is a comment/string
	-- can't use ( because it interferes with parse_subexp's parse_prefixexp and then we can't use multiple explist
	-- can't use { because that's a table ...
	-- we need a prefix symbol that isn't already used
	-- can't use : that's for gotos
	-- can't use ~ # etc ...
	-- and we can' tuse anythign if we want to chain them
	-- now if we change parse_prefixexp's ( exp ) to a ( explist ) then it doesn't break old code (I hope) but allows new
	-- so in that case lets also throw in ->

	local prefixexp
	local from = self:getloc()

	if self:canbe('(', 'symbol') then
		local args = assert(self:parse_explist(), 'unexpected symbol')
		self:mustbe(')', 'symbol')

		-- [[ here we handle the new call operator
		if self:canbe('->', 'symbol') then
			-- now parse the function
			repeat
--tprint('args', args:unpack())
--tprint('token', self.t.token)
				--prefixexp = self:parse_prefixexp()
				prefixexp = self:parse_exp()
				--prefixexp = self:parse_var()

--tprint('rhs', prefixexp)
				prefixexp = self:parse_arrowcall_rhs(args, prefixexp)
--tprint('call', prefixexp)
				args = table{prefixexp}
			until not self:canbe('->', 'symbol')
--level=level-1
--tprint('returning', prefixexp)
			return prefixexp
		end
		--]]

		-- ( 1 2 3 ) ... should be an error for more than one unless we're using it in our new -> call operator
		assert(#args == 1, "expected ( exp ) , found more than one arg ...")
		prefixexp = self:node('_par', args[1])
			:setspan{from = from, to = self:getloc()}
--tprint('par prefixexp', prefixexp)
	elseif self:canbe(nil, 'name') then
		prefixexp = self:node('_var', self.lasttoken)
			:setspan{from = from, to = self:getloc()}
--tprint('name prefixexp', prefixexp)
	else
--level=level-1
--tprint('returning empty - prefixexp failed')
		return
	end

	while true do
		if self:canbe('[', 'symbol') then
			prefixexp = self:node('_index', prefixexp, (assert(self:parse_exp(), 'unexpected symbol')))
			self:mustbe(']', 'symbol')
			prefixexp:setspan{from = from, to = self:getloc()}
		elseif self:canbe('.', 'symbol') then
			local sfrom = self:getloc()
			prefixexp = self:node('_index',
				prefixexp,
				self:node('_string', self:mustbe(nil, 'name'))
					:setspan{from = sfrom, to = self:getloc()}
			)
			:setspan{from = from, to = self:getloc()}
		elseif self:canbe(':', 'symbol') then
			prefixexp = self:node('_indexself',
				prefixexp,
				self:mustbe(nil, 'name')
			):setspan{from = from, to = self:getloc()}
			local args = self:parse_args()
			if not args then error"function arguments expected" end
			prefixexp = self:node('_call', prefixexp, table.unpack(args))
				:setspan{from = from, to = self:getloc()}
		else
			local args = self:parse_args()
			if not args then break end

			prefixexp = self:node('_call', prefixexp, table.unpack(args))
				:setspan{from = from, to = self:getloc()}
		end
	end
--level=level-1
--tprint('returning func call prefixexp', prefixexp)
	return prefixexp
end

--local source = assert(..., "expected filename")
local source = ... or 'test.leftlua'
local data = assert(path(source):read())
local parser = LeftParser()
parser:setData(data, source)
tree = parser.tree

print()
print'tree'
print(tree)

print()
print'results'
result = tree:toLua()
print(result)
assert(load(result))()
