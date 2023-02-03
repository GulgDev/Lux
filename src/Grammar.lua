local Grammar = {}

local AST = require(script.Parent.AST)

export type GrammaticalRuleChainOperation = "and" | "or"

export type GrammaticalRuleExpressionModifier = "repeation" | "optional"

export type RuleChain = {
	class: "chain",
	operation: GrammaticalRuleChainOperation,
	rules: { GrammaticalRule }
}

export type RuleModifier = {
	class: "modifier",
	modifier: GrammaticalRuleExpressionModifier,
	rule: GrammaticalRule
}

export type Pattern = {
	class: "pattern",
	pattern: string
}

export type Include = {
	class: "include",
	ruleName: string
}

export type Whitespace = {
	class: "whitespace",
	multiline: boolean
}

export type Custom = {
	class: "custom",
	match: (any, { AST.Element }) -> ({ AST.Element }, number)
}

export type EOF = {
	class: "eof"
}

export type GrammaticalRule = RuleChain | RuleModifier | Pattern | Include | Whitespace | Custom | EOF

Grammar.patterns = {}

Grammar.patterns.whitespace = "[ \t\f\n\r]"
Grammar.patterns.inlinewhitespace = "[ \t]"
Grammar.patterns.quote = "[\"']"
Grammar.patterns.alpha = "[A-Za-z_]"
Grammar.patterns.alphanumeric = "[A-Za-z0-9_]"

function Grammar._or(rules: { GrammaticalRule }?): RuleChain
	return {
		class = "chain",
		operation = "or",
		rules = rules or {}
	}
end

function Grammar._and(rules: { GrammaticalRule }?): RuleChain
	return {
		class = "chain",
		operation = "and",
		rules = rules or {}
	}
end

function Grammar.repeation(rule: GrammaticalRule, min: number, max: number): RuleModifier
	return {
		class = "modifier",
		modifier = "repeation",
		rule = rule,
		min = min,
		max = max
	}
end

function Grammar.optional(rule: GrammaticalRule): RuleModifier
	return {
		class = "modifier",
		modifier = "optional",
		rule = rule
	}
end

function Grammar.pattern(pattern: string): Pattern
	return {
		class = "pattern",
		pattern = pattern
	}
end

function Grammar.include(ruleName: string): Include
	return {
		class = "include",
		ruleName = ruleName
	}
end

function Grammar.custom(callback: (any, { AST.Element }) -> (boolean, { AST.Element }, number)): Custom
	return {
		class = "custom",
		match = callback
	}
end

local makeDictionaryForRules

local function makeDictionaryForRule(dict: {}, map: {}, rule: GrammaticalRule, grammarRules: { [string]: GrammaticalRule })
	if rule.class == "pattern" and not map[rule.pattern] then
		map[rule.pattern] = true
		table.insert(dict, rule.pattern)
	elseif rule.class == "include" then
		makeDictionaryForRule(dict, map, grammarRules[rule.ruleName], grammarRules)
	elseif rule.class == "modifier" then
		makeDictionaryForRule(dict, map, rule.rule, grammarRules)
	elseif rule.class == "chain" then
		makeDictionaryForRules(dict, map, rule.rules, grammarRules)
	end
end

makeDictionaryForRules = function(dict: {}, map: {}, rules: { GrammaticalRule }, grammarRules: { [string]: GrammaticalRule })
	for _, rule in rules do
		if map[rule] then
			continue
		end
		map[rule] = true
		makeDictionaryForRule(dict, map, rule, grammarRules)
	end
end

local Parser

function Grammar.new()
	return setmetatable({
		rules = {}
	} :: {
		rules: { GrammaticalRule },
		rootRule: string?,
		dictionary: { string },
		defineRule: typeof(Grammar.defineRule)
	}, Grammar)
end

function Grammar:defineRule(name: string, rule: GrammaticalRule)
	local rules = self.rules
	if rules[name] then
		error("Rule with this name is already registered")
	end 
	rules[name] = rule
end

function Grammar:__index(key)
	if key == "rules" or key == "rootRule" then
		return rawget(self, key)
	elseif key == "dictionary" then
		local map = {}
		local dict = {}
		local rules = self.rules
		makeDictionaryForRules(dict, map, rules, rules)
		return dict
	else
		return Grammar[key]
	end
end

function Grammar:__newindex(key, value)
	if key == "rootRule" then
		if type(value) == "string" then
			rawset(self, "rootRule", value)
		else
			error("Root rule name must be a string")
		end
	else
		error(`{key} cannot be assigned to {value}`)
	end
end

export type Grammar = typeof(Grammar.new())

local parseExpressions

local function parseExpression(element: AST.Structure): GrammaticalRule
	local name = element.name
	if name == "and-chain" then
		return Grammar._and(parseExpressions(element.children))
	elseif name == "or-chain" then
		return Grammar._or(parseExpressions(element.children))
	elseif name == "pattern" then
		return Grammar.pattern(Parser.unescape(element.first.value))
	elseif name == "name" then
		return Grammar.include(element.first.value)
	elseif name == "repeation" then
		local subexpr = element:findChildByName("expression")
		local rule = parseExpression(subexpr.first)
		local min, max = 0, math.huge
		local count = element:findChildrenByName("repeation-count")
		if #count == 2 then
			min, max = tonumber(count[1].value), tonumber(count[2].value)
		end
		return Grammar.repeation(rule, min, max)
	elseif name == "optional" then
		local subexpr = element:findChildByName("expression")
		local rule = parseExpression(subexpr.first)
		return Grammar.optional(rule)
	elseif name == "group" then
		local subexpr = element:findChildByName("expression")
		return parseExpression(subexpr.first)
	end
end

parseExpressions = function(elements: { AST.Element }): { GrammaticalRule }
	local rules = {}
	for _, element in elements do
		if element.elementType == "structure" then
			table.insert(rules, parseExpression(element))
		end
	end
	return rules
end

local validateRules

local function validateRule(map: { [GrammaticalRule]: boolean }, rule: GrammaticalRule, grammarRules: { [string]: GrammaticalRule })
	if rule.class == "pattern" then
		if not pcall(string.find, "", rule.pattern) then
			error(`Invalid pattern: {Parser.escape(rule.pattern)}`)
		end
	elseif rule.class == "include" then
		local target = grammarRules[rule.ruleName]
		if target == nil then
			error(`Rule "{rule.ruleName}" is not defined`)
		end
		validateRule(map, target, grammarRules)
	elseif rule.class == "modifier" then
		validateRule(map, rule.rule, grammarRules)
	elseif rule.class == "chain" then
		validateRules(map, rule.rules, grammarRules)
	end
end

validateRules = function(map: { [GrammaticalRule]: boolean }, rules: { GrammaticalRule }, grammarRules: { [string]: GrammaticalRule })
	for _, rule in rules do
		if map[rule] then
			continue
		end
		map[rule] = true
		validateRule(map, rule, grammarRules)
	end
end

local lbnfParser

function Grammar.parse(lbnf: string): Grammar
	local grammar = Grammar.new()
	local tree: AST.SyntaxTree = lbnfParser:parse(lbnf)
	tree:forEach("rule-definition", function(definition)
		local name = definition:findChildByName("name").first.value
		local expression = definition:findChildByName("expression")
		grammar:defineRule(name, parseExpression(expression.first))
		local first = definition.first
		if first.elementType == "token" and first.value == "!" then
			if grammar.rootRule then
				error("Grammar must have only one root rule")
			else
				grammar.rootRule = name
			end
		end
	end)
	validateRules({}, grammar.rules, grammar.rules)
	return grammar
end

function Grammar.importAll()
	Grammar.importAll = nil
	
	Parser = require(script.Parent.Parser)
	
	local lbnfGrammar = Grammar.new()
	lbnfGrammar:defineRule("grammar", Grammar._and {
		Grammar.repeation(
			Grammar._and {
				Grammar.include "comment"
			},
			0, math.huge
		),
		Grammar.repeation(
			Grammar._and {
				Grammar.include "rule-definition",
				Grammar.repeation(
					Grammar._and {
						Grammar.include "comment"
					},
					0, math.huge
				)
			},
			0, math.huge
		)
	})
	lbnfGrammar:defineRule("rule-definition", Grammar._and {
		Grammar.optional(Grammar.pattern "!"),
		Grammar.include "name",
		Grammar.pattern "=",
		Grammar.include "expression",
		Grammar.pattern ";"
	})
	lbnfGrammar:defineRule("name", Grammar.pattern "[A-Za-z][A-Za-z0-9-_]*")
	lbnfGrammar:defineRule("expression", Grammar._or {
		Grammar.include "name",
		Grammar.include "pattern",
		Grammar.include "and-chain",
		Grammar.include "or-chain",
		Grammar.include "repeation",
		Grammar.include "optional",
		Grammar.include "group"
	})
	lbnfGrammar:defineRule("pattern", Grammar.pattern "([\"']).-[^\\]%1")
	lbnfGrammar:defineRule("and-chain", Grammar._and {
		Grammar.repeation(
			Grammar._or {
				Grammar.include "name",
				Grammar.include "pattern",
				Grammar.include "repeation",
				Grammar.include "optional",
				Grammar.include "group"
			},
			0, math.huge
		)
	})
	lbnfGrammar:defineRule("or-chain", Grammar._and {
		Grammar._or {
			Grammar.include "name",
			Grammar.include "pattern",
			Grammar.include "and-chain",
			Grammar.include "repeation",
			Grammar.include "optional",
			Grammar.include "group"
		},
		Grammar.repeation(
			Grammar._and {
				Grammar.pattern "|",
				Grammar._or {
					Grammar.include "name",
					Grammar.include "pattern",
					Grammar.include "and-chain",
					Grammar.include "repeation",
					Grammar.include "optional",
					Grammar.include "group"
				}
			},
			1, math.huge
		)
	})
	lbnfGrammar:defineRule("repeation", Grammar._and {
		Grammar.pattern "{",
		Grammar.include "expression",
		Grammar.pattern "}",
		Grammar.optional(
			Grammar._and {
				Grammar.pattern "<",
				Grammar.include "repeation-count",
				Grammar.pattern "%.%.",
				Grammar.include "repeation-count",
				Grammar.pattern ">"
			}
		)
	})
	lbnfGrammar:defineRule("repeation-count", Grammar._or {
		Grammar.pattern "inf",
		Grammar.pattern "%d+"
	})
	lbnfGrammar:defineRule("optional", Grammar._and {
		Grammar.pattern "%[",
		Grammar.include "expression",
		Grammar.pattern "%]"
	})
	lbnfGrammar:defineRule("group", Grammar._and {
		Grammar.pattern "%(",
		Grammar.include "expression",
		Grammar.pattern "%)"
	})
	lbnfGrammar:defineRule("comment", Grammar._or {
		Grammar.pattern "%-%-[^\n]+",
		Grammar.pattern "%-%-%[(=*)%[.-%]%1%]"
	})
	lbnfGrammar.rootRule = "grammar"
	
	lbnfParser = Parser.new(lbnfGrammar)
end

return Grammar
