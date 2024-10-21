#!/usr/bin/env luajit
local path = require 'ext.path'

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

-- hmm now how to change the parser to use a lhs call ...
-- lots of options ...
-- insert a new operator?  but that's for exprs which are single entries of explists ...
-- modify parse_prefixexp (so we get free statment support as well) , but there might be problems of it not telling _par from _call ... maybe ...)  gtting problems tho
-- cheat: new prefix token for "expect an arglist , then a call" ... so the -> goes before the args, not after ... 
function LeftParser:parse_prefixexp()
	if self:canbe('->', 'symbol') then
		local args = self:parse_args()
		if not args then error("expected -> arglist") end
		
		-- now parse a function lhs
	
		local prefixexp
		local from = self:getloc()

		if self:canbe('(', 'symbol') then
			local exp = assert(self:parse_exp(), 'unexpected symbol')
			self:mustbe(')', 'symbol')
			prefixexp = self:node('_par', exp)
				:setspan{from = from, to = self:getloc()}
		elseif self:canbe(nil, 'name') then
			prefixexp = self:node('_var', self.lasttoken)
				:setspan{from = from, to = self:getloc()}
		else
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
				prefixexp = self:node('_call', prefixexp, table.unpack(args))
					:setspan{from = from, to = self:getloc()}
				break
			else
				prefixexp = self:node('_call', prefixexp, table.unpack(args))
					:setspan{from = from, to = self:getloc()}
				break
			end
		end

		return prefixexp
	else
		return LeftParser.super.parse_prefixexp(self)
	end
end


--local source = assert(..., "expected filename")
local source = ... or 'test.leftlua'
local data = assert(path(source):read())
local parser = LeftParser()
parser:setData(data, source)
tree = parser.tree
print'tree'
print(tree)
print'results'
result = tree:toLua()
assert(load(result))()
