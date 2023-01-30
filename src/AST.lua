local AST = {}

AST.Position = {}
AST.Position.__index = AST.Position

function AST.Position.new(offset: number, line: number, column: number)
	return setmetatable({
		offset = offset,
		line = line,
		column = column
	}, AST.Position)
end

export type Position = typeof(AST.Position.new())

AST.Token = {
	elementType = "token"
}
AST.Token.__index = AST.Token

function AST.Token.new(value: string, start: Position, stop: Position)
	return setmetatable({
		value = value,
		start = start,
		stop = stop
	}, AST.Token)
end

export type Token = typeof(AST.Token.new())

AST.Structure = {
	elementType = "structure"
}
AST.Structure.__index = AST.Structure

function AST.Structure.new(name: string, children: { Element })
	local first = children[1]
	local last = children[#children]
	return setmetatable({
		name = name,
		children = children,
		first = first,
		last = last,
		start = first.stop,
		stop = last.stop
	}, AST.Structure)
end

function AST.Structure:getDescendants()
	local descendants = {}
	for _, element in self.children do
		table.insert(descendants, element)
		if element.elementType == "structure" then
			for _, descendant in element:getDescendants() do
				table.insert(descendants, descendant)
			end
		end
	end
	return descendants
end

function AST.Structure:findChildByName(name: string): Structure
	for _, element in self.children do
		if element.name == name then
			return element
		end
	end
end

function AST.Structure:findChildrenByName(name: string): { Structure }
	local found = {}
	for _, element in self.children do
		if element.name == name then
			table.insert(found, element)
		end
	end
	return found
end

function AST.Structure:findDescendantByName(name: string): Structure
	for _, element in self:getDescendants() do
		if element.name == name then
			return element
		end
	end
end

function AST.Structure:findDescendantsByName(name: string): { Structure }
	local found = {}
	for _, element in self:getDescendants() do
		if element.name == name then
			table.insert(found, element)
		end
	end
	return found
end

export type Structure = typeof(AST.Structure.new())

AST.Error = {
	elementType = "error"
}
AST.Error.__index = AST.Error

function AST.Error.new(got: Element, expected: { })
	return setmetatable({
		got = got,
		expected = expected,
		start = got.start,
		stop = got.stop
	}, AST.Error)
end

export type Error = typeof(AST.Error.new())

AST.EOF = {
	elementType = "eof"
}
AST.EOF.__index = AST.EOF

function AST.EOF.new(position: Position)
	return setmetatable({
		position = position
	}, AST.EOF)
end

export type EOF = typeof(AST.EOF.new())

AST.Whitespace = {
	elementType = "whitespace"
}
AST.Whitespace.__index = AST.Whitespace

function AST.Whitespace.new(value: string, start: Position, stop: Position)
	return setmetatable({
		value = value,
		multiline = value:find("\n") ~= nil,
		start = start,
		stop = stop
	}, AST.Whitespace)
end

export type Whitespace = typeof(AST.Whitespace.new())

export type Element = Token | Structure | Error | EOF | Whitespace

AST.SyntaxTree = {}
AST.SyntaxTree.__index = AST.SyntaxTree

function AST.SyntaxTree.new(root: Structure)
	return setmetatable({ 
		root = root
	}, AST.SyntaxTree)
end

function AST.SyntaxTree:on(name: string, callback: (Structure) -> ())
	for _, element in self.root:findDescendantsByName(name) do
		callback(element)
	end
end

export type SyntaxTree = typeof(AST.SyntaxTree.new())

return AST
