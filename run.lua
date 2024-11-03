#!/usr/bin/env luajit
local path = require 'ext.path'
local table = require 'ext.table'
local assert = require 'ext.assert'

local LuaTokenizer = require 'parser.lua.tokenizer'
local LeftTokenizer = LuaTokenizer:subclass()
function LeftTokenizer:initSymbolsAndKeywords(...)
	LeftTokenizer.super.initSymbolsAndKeywords(self, ...)
	self.symbols:insert'->'	-- lhs call
	self.symbols:insert'=>'	-- lhs assign
end

local LuaParser = require 'parser.lua.parser'
local LeftParser = LuaParser:subclass()
function LeftParser:buildTokenizer(data)
	return LeftTokenizer(data, self.version, self.useluajit)
end

function LeftParser:parse_stat()
	if self.version >= '5.2' then
		repeat until not self:canbe(';', 'symbol')
	end
	local from = self:getloc()
	if self:canbe('local', 'keyword') then
		local ffrom = self:getloc()
		if self:canbe('function', 'keyword') then
			local namevar = assert(self:parse_var(), {msg='expected name'})
			return self:node('_local', {
				self:makeFunction(
					namevar,
					table.unpack((assert(self:parse_funcbody(), {msg="expected function body"})))
				):setspan{from = ffrom , to = self:getloc()}
			}):setspan{from = from , to = self:getloc()}
		else
			local afrom = self:getloc()

			local namelist
			local explist = self:parse_explist()
			if explist then
				if self:canbe('=>', 'symbol') then
					namelist = assert(self:parse_attnamelist(), {msg="expected attr name list"})
				else
					-- then explist must be a bunch of _var definitions
					for i=1,#explist do
						assert.is(explist[i], self.ast._var)
					end
					namelist = explist
					explist = nil
				end

				if explist then
					local assign = self:node('_assign', namelist, explist)
						:setspan{from = ffrom, to = self:getloc()}
					return self:node('_local', {assign})
						:setspan{from = from, to = self:getloc()}
				else
					return self:node('_local', namelist)
						:setspan{from = from, to = self:getloc()}
				end
			end
		end
	elseif self:canbe('function', 'keyword') then
		local funcname = self:parse_funcname()
		return self:makeFunction(funcname, table.unpack((assert(self:parse_funcbody(), {msg="expected function body"}))))
			:setspan{from = from , to = self:getloc()}
	elseif self:canbe('for', 'keyword') then
		local explist = assert(self:parse_explist(), {msg="expected exp list"})
		if self:canbe('=>', 'symbol') then
			local namelist = assert(self:parse_namelist(), {msg="expected name list"})
			assert.eq(#namelist, 1, {msg="expected only one name in for loop"})
			assert.ge(#explist, 2, {msg="bad for loop"})
			assert.le(#explist, 3, {msg="bad for loop"})
			self:mustbe('do', 'keyword')
			local block = assert(self:parse_block'for =', {msg="for loop expected block"})
			self:mustbe('end', 'keyword')
			return self:node('_foreq', namelist[1], explist[1], explist[2], explist[3], table.unpack(block))
				:setspan{from = from, to = self:getloc()}
		elseif self:canbe('in', 'keyword') then
			local namelist = assert(self:parse_namelist(), {msg="expected name list"})
			self:mustbe('do', 'keyword')
			local block = assert(self:parse_block'for in', {msg="expected block"})
			self:mustbe('end', 'keyword')
			return self:node('_forin', namelist, explist, table.unpack(block))
				:setspan{from = from, to = self:getloc()}
		else
			error{msg="'=' or 'in' expected"}
		end
	elseif self:canbe('if', 'keyword') then
		local cond = assert(self:parse_exp(), {msg="unexpected symbol"})
		self:mustbe('then', 'keyword')
		local block = self:parse_block()
		local stmts = table(block)
		-- ...and add elseifs and else to this
		local efrom = self:getloc()
		while self:canbe('elseif', 'keyword') do
			local cond = assert(self:parse_exp(), {msg='unexpected symbol'})
			self:mustbe('then', 'keyword')
			stmts:insert(
				self:node('_elseif', cond, table.unpack((assert(self:parse_block(), {msg='expected block'}))))
					:setspan{from = efrom, to = self:getloc()}
			)
			efrom = self:getloc()
		end
		if self:canbe('else', 'keyword') then
			stmts:insert(
				self:node('_else', table.unpack((assert(self:parse_block(), {msg='expected block'}))))
					:setspan{from = efrom, to = self:getloc()}
			)
		end
		self:mustbe('end', 'keyword')
		return self:node('_if', cond, table.unpack(stmts))
			:setspan{from = from, to = self:getloc()}
	elseif self:canbe('repeat', 'keyword') then
		local block = assert(self:parse_block'repeat', {msg='expected block'})
		self:mustbe('until', 'keyword')
		return self:node(
			'_repeat',
			(assert(self:parse_exp(), {msg='unexpected symbol'})),
			table.unpack(block)
		):setspan{from = from, to = self:getloc()}
	elseif self:canbe('while', 'keyword') then
		local cond = assert(self:parse_exp(), {msg='unexpected symbol'})
		self:mustbe('do', 'keyword')
		local block = assert(self:parse_block'while', {msg='expected block'})
		self:mustbe('end', 'keyword')
		return self:node('_while', cond, table.unpack(block))
			:setspan{from = from, to = self:getloc()}
	elseif self:canbe('do', 'keyword') then
		local block = assert(self:parse_block(), {msg='expected block'})
		self:mustbe('end', 'keyword')
		return self:node('_do', table.unpack(block))
			:setspan{from = from, to = self:getloc()}
	elseif self.version >= '5.2' then
		if self:canbe('goto', 'keyword') then
			local name = self:mustbe(nil, 'name')
			local g = self:node('_goto', name)
				:setspan{from = from, to = self:getloc()}
			self.gotos[name] = g
			return g
		-- lua5.2+ break is a statement, so you can have multiple breaks in a row with no syntax error
		elseif self:canbe('break', 'keyword') then
			return self:parse_break()
				:setspan{from = from, to = self:getloc()}
		elseif self:canbe('::', 'symbol') then
			local name = self:mustbe(nil, 'name')
			local l = self:node('_label', name)
			self.labels[name] = true
			self:mustbe('::', 'symbol')
			return l:setspan{from = from, to = self:getloc()}
		end
	end

	local args = self:parse_args()
	if args then
		if self:canbe('=>', 'symbol') then
			local prefixexp = self:parse_prefixexp()
			local vars = table{prefixexp}
			while self:canbe(',', 'symbol') do
				local var = assert(self:parse_prefixexp(), {msg='expected expr'})
				assert.ne(var.type, 'call', {msg="syntax error"})
				vars:insert(var)
			end
			return self:node('_assign', vars, args)
				:setspan{from = from, to = self:getloc()}
		elseif self:canbe('->', 'symbol') then
			local prefixexp
			repeat
				prefixexp = self:parse_exp()

				prefixexp = self:parse_arrowcall_rhs(args, prefixexp)
				args = table{prefixexp}
			until not self:canbe('->', 'symbol')
			return prefixexp
		else
			error{msg="after stmt args, expected => or ->"}
		end
	end
end


--[[ doesn't work for explist ...
--function LeftParser:parse_exp()	-- for lowest precedence
function LeftParser:parse_subexp()   -- for highest precedence
	--local a = self:parse_expr_precedenceTable(1)
	local a = LeftParser.super.parse_subexp(self)
	if not a then return end
	if self:canbe('->', 'symbol') then
		--local b = self:parse_exp()
		local b = self:parse_subexp()
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
--[[
		elseif self:canbe(':', 'symbol') then
			prefixexp = self:node('_indexself',
				prefixexp,
				self:mustbe(nil, 'name')
			):setspan{from = from, to = self:getloc()}
			return self:node('_call', prefixexp, table.unpack(args))
				:setspan{from = from, to = self:getloc()}
--]]
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
	else
		prefixexp = self:parse_var()
		if not prefixexp then return end
	end

-- [[ old calling style
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
--[=[
		elseif self:canbe(':', 'symbol') then
			prefixexp = self:node('_indexself',
				prefixexp,
				self:mustbe(nil, 'name')
			):setspan{from = from, to = self:getloc()}
			local args = self:parse_args()
			if not args then error"function arguments expected" end
			prefixexp = self:node('_call', prefixexp, table.unpack(args))
				:setspan{from = from, to = self:getloc()}
--]=]
		else
			local args = self:parse_args()
			if not args then break end

			prefixexp = self:node('_call', prefixexp, table.unpack(args))
				:setspan{from = from, to = self:getloc()}
		end
	end
--]]
--level=level-1
--tprint('returning func call prefixexp', prefixexp)
	return prefixexp
end

function LeftParser:parse_field()
	local from = self:getloc()

	local valexp = self:parse_exp()
	if not valexp then return end

	if not self:canbe('=>', 'symbol') then
		return valexp
	end

	local keyexp
	if self:canbe('[', 'symbol') then
		keyexp = assert(self:parse_exp(), {msg='unexpected symbol'})
		self:mustbe(']', 'symbol')
	else
		keyexp = assert(self:parse_var(), {msg='expected name'})
		-- convert from _var to _string
		keyexp = self:node('_string', keyexp.name):setspan(keyexp.span)
	end
	return self:node('_assign', {keyexp}, {valexp})
		:setspan{from = from, to = self:getloc()}
end



--local source = assert(..., "expected filename")
local source = ... or 'test.leftlua'
local data = assert(path(source):read())
local parser = LeftParser()
assert(parser:setData(data, source))
tree = parser.tree

print()
print'tree'
print(tree)

print()
print'results'
result = tree:toLua()
print(result)
assert(load(result))()
