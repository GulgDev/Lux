--[[
    
            ████████████████                ╔═════════════════════════════════════════════════════════╗
            ████████████████                ║                                                         ║
            ██  ██        ██                ║    Lux is a parser generator for Luau.                  ║
            ████████████████                ║                                                         ║
            ██            ██                ║    It can be used for creating custom languages,        ║
            ████████████████                ║  creating powerful tools, such as command parser and a  ║
            ██    ██      ██                ║  lot of other things! Lux has many useful functions     ║
            ████████████████                ║  for parsing and lexing.                                ║
    ████████████████████████████████        ║                                                         ║
    ████████████████████████████████        ║    Links:                                               ║
    ██  ██        ████  ██    ██  ██        ║      • Documentation: https://gulgdev.github.io/Lux     ║
    ████████████████████████████████        ║      • Source code: https://github.com/GulgDev/Lux/src  ║
    ██      ██    ████    ██      ██        ║                                                         ║
    ████████████████████████████████        ║                                                         ║
    ██    ██  ██  ████      ██    ██        ║                                                         ║
    ████████████████████████████████        ║                                                         ║
                                            ║                                                         ║
       ██      ██    ██  ██   ██            ║                                                         ║
       ██      ██    ██   ██ ██             ║                                                         ║
       ██      ██    ██    ███              ║                                                         ║
       ██      ██    ██   ██ ██             ║                                                         ║
       ██████    ████    ██   ██            ╚═════════════════════════════════════════════════════════╝
    
]]

local Visualizer = require(script.Visualizer)
local Grammar = require(script.Grammar)
local Parser = require(script.Parser)
local AST = require(script.AST)

Grammar.importAll()

local Lux = {
	Visualizer = Visualizer,
	Grammar = Grammar,
	Parser = Parser,
	AST = AST
}

function Lux.generateParser(lbnf: string?): Parser.Parser
	return Parser.new(
		if lbnf then Grammar.parse(lbnf) else Grammar.new()
	)
end

function Lux.show(data: { AST.Element } | AST.SyntaxTree | Grammar.Grammar)
	if data.root then
		Visualizer.showSyntaxTree(data)
	elseif data.rules then
		Visualizer.showGrammar(data)
	else
		Visualizer.showElements(data)
	end
end

return Lux
