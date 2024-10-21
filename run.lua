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

--local source = assert(..., "expected filename")
local source = ... or 'test.leftlua'
local data = assert(path(source):read())
local parser = LeftParser()
parser:setData(data, source)
tree = parser.tree
result = tree:toLua()
assert(load(result))()
