local Parser = {}
Parser.__index = Parser

local Grammar = require(script.Parent.Grammar)
local AST = require(script.Parent.AST)

local function match(parser: Parser, rule: Grammar.GrammaticalRule, data: { AST.Element }, offset: number, stack: { [Grammar.GrammaticalRule]: string }): (boolean, { AST.Element }, number)
	if rule.class == "custom" then
		if offset > #data then
			return
		end
		local elements = {}
		for i = offset, #data do
			table.insert(elements, data[i])
		end
		return rule.match(parser, table.freeze(elements))
	elseif rule.class == "pattern" then
		local current = data[offset]
		if current.elementType == "token" and
			current.value:match(`^{rule.pattern}$`) then
			return true, { current }, 1
		end
		return false, { AST.Error.new(current, rule) }, 1
	elseif rule.class == "include" then
		local ruleName = rule.ruleName
		local subrule = parser.grammar.rules[ruleName]
		local success, content, count = match(parser, subrule, data, offset, stack)
		if success then
			if #content > 0 then
				return true, { AST.Structure.new(ruleName, content) }, count
			else
				return true, {}, count
			end
		end
		return false, { AST.Error.new(data[offset], subrule) }, 1
	elseif rule.class == "whitespace" then
		local current = data[offset]
		if current.elementType == "whitespace" and
			(not current.multiline or rule.multiline) then
			return true, { current }, 1
		end
		return true, {}, 0
	elseif rule.class == "eof" then
		local current = data[offset]
		if current.elementType == "eof" then
			return true, { current }, 1
		end
		return false, { AST.Error.new(data[offset], rule) }, 1
	elseif rule.class == "modifier" then
		if rule.modifier == "optional" then
			local success, output, count = match(parser, rule.rule, data, offset, stack)
			if success then
				return success, output, count
			else
				return true, {}, 0
			end
		elseif rule.modifier == "repeation" then
			local output = {}
			local count = 0
			local found = 0
			while offset <= #data do
				while data[offset].elementType == "whitespace" do
					offset += 1
					count += 1
				end
				local success, out, cnt = match(parser, rule.rule, data, offset, stack)
				if success then
					for _, element in out do
						table.insert(output, element)
					end
					offset += cnt
					count += cnt
					if cnt > 0 then
						stack = {}
					end
					found += 1
					if found >= rule.max then
						break
					end
				else
					break
				end
			end
			if found < rule.min then
				table.insert(output, AST.Error.new(data[offset], rule))
				return false, output, count
			end
			return true, output, count
		end
	elseif rule.class == "chain" then
		if rule.operation == "and" then
			local output = {}
			local count = 0
			for _, subrule in rule.rules do
				while data[offset].elementType == "whitespace" do
					offset += 1
					count += 1
				end
				local success, out, cnt = match(parser, subrule, data, offset, stack)
				for _, element in out do
					table.insert(output, element)
				end
				offset += cnt
				count += cnt
				if cnt > 0 then
					stack = {}
				end
				if not success then
					return success, output, count
				end
			end
			return true, output, count
		elseif rule.operation == "or" then
			local map = {}
			for _, subrule in rule.rules do
				if stack[subrule] then
					continue
				end
				local substack = table.clone(stack)
				substack[subrule] = true
				local success, output, count = match(parser, subrule, data, offset, substack)
				if success then
					map[count] = output
				end
			end
			local max
			local maxn = -1
			for count, output in map do
				if count > maxn then
					max = output
					maxn = count
				end
			end
			if max then
				return true, max or {}, maxn
			end
			return false, { AST.Error.new(data[offset], rule) }, 1
		end
	end
end

function Parser.new(grammar: Grammar.Grammar)
	return setmetatable({
		grammar = grammar
	}, Parser)
end

function Parser:parse(source: string): AST.SyntaxTree
	local grammar = self.grammar
	local rootRuleName = grammar.rootRule
	local rootRule = grammar.rules[rootRuleName]
	if not rootRule then
		error("Root rule not found!")
	end
	local tokens = self:tokenize(source)
	local _, content, _ = match(self, Grammar._and {
		rootRule,
		{
			class = "eof"
		}
	}, tokens, 1, {})
	return AST.SyntaxTree.new(
		AST.Structure.new(rootRuleName, content)
	)
end

function Parser:tokenize(source: string): { AST.Token }
	local dict = self.grammar.dictionary
	local tokens = {}
	local offset = 1
	local line = 1
	local column = 1
	local char, start, stop
	while offset <= #source do
		char = source:sub(offset, offset)
		local whitespace = ""
		local whitespaceStart = AST.Position.new(offset, line, column)
		local multiline = false
		while char and char:match(Grammar.patterns.whitespace) do
			whitespace ..= char
			if char == "\n" then
				line += 1
				column = 1
				multiline = true
			else
				column += 1
			end
			offset += 1
			char = source:sub(offset, offset)
		end
		if #whitespace > 0 then
			local whitespaceStop = AST.Position.new(offset, line, column)
			table.insert(tokens, AST.Whitespace.new(whitespace, whitespaceStart, whitespaceStop))
		end
		if char == "" then
			break
		end
		local matches = {}
		for _, pattern in dict do
			start, stop = source:find(`^{pattern}`, offset)
			if start then
				table.insert(matches, source:sub(start, stop))
			end
		end
		if #matches > 0 then
			table.sort(matches, function(a, b) return a > b end)
			local match = matches[1]
			local start = AST.Position.new(offset, line, column)
			match:gsub(".", function()
				if char == "\n" then
					line += 1
					column = 1
				else
					column += 1
				end
				offset += 1
			end)
			local stop = AST.Position.new(offset, line, column)
			table.insert(tokens, AST.Token.new(match, start, stop))
		else
			local start = AST.Token.new(match, start, stop)
			local got = source:sub(offset)
			got:gsub(".", function()
				if char == "\n" then
					line += 1
					column = 1
				else
					column += 1
				end
				offset += 1
			end)
			local stop = AST.Position.new(offset, line, column)
			local gotToken = AST.Token.new(got, start, stop)
			local patterns = {}
			for _, pattern in dict do
				table.insert(patterns, Grammar.pattern(pattern))
			end
			local expected = Grammar._or(patterns)
			table.insert(tokens, AST.Error.new(gotToken, expected))
		end
	end
	table.insert(tokens, AST.EOF.new(AST.Position.new(offset, line, column)))
	return tokens
end

function Parser.unescape(raw: string)
	local unescaped = ""
	local index = 2
	local char
	while index <= #raw - 1 do
		char = raw:sub(index, index)
		index += 1
		if char == "\\" then
			char = raw:sub(index, index)
			index += 1
			if char == raw:sub(1, 1) then
				unescaped ..= char
			elseif char == "\\" then
				unescaped ..= "\\"
			elseif char == "a" then
				unescaped ..= "\a"
			elseif char == "b" then
				unescaped ..= "\b"
			elseif char == "f" then
				unescaped ..= "\f"
			elseif char == "n" then
				unescaped ..= "\n"
			elseif char == "r" then
				unescaped ..= "\r"
			elseif char == "t" then
				unescaped ..= "\t"
			elseif char == "v" then
				unescaped ..= "\v"
			else
				unescaped ..= "\\" .. char
			end
		else
			unescaped ..= char
		end
	end
	return unescaped
end

function Parser.escape(unescaped: string)
	local raw = "\""
	local index = 1
	local char
	while index <= #unescaped do
		char = unescaped:sub(index, index)
		index += 1
		if char == "\"" then
			raw ..= "\\\""
		elseif char == "\\" then
			raw ..= "\\\\"
		elseif char == "\a" then
			raw ..= "\\a"
		elseif char == "\b" then
			raw ..= "\\b"
		elseif char == "\f" then
			raw ..= "\\f"
		elseif char == "\n" then
			raw ..= "\\n"
		elseif char == "\r" then
			raw ..= "\\r"
		elseif char == "\t" then
			raw ..= "\\t"
		elseif char == "\v" then
			raw ..= "\\v"
		else
			raw ..= char
		end
	end
	raw ..= "\""
	return raw
end

export type Parser = typeof(Parser.new())

return Parser
