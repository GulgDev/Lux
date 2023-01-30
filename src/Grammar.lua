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

function Grammar.repeation(rule: GrammaticalRule): RuleModifier
	return {
		class = "modifier",
		modifier = "repeation",
		rule = rule
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

function Grammar.whitespace(multiline: boolean): Whitespace
	return {
		class = "whitespace",
		multiline = multiline
	}
end

function Grammar.custom(callback: (any, { AST.Element }) -> (boolean, { ASR.Element }, number)): Custom
	return {
		class = "custom",
		match = callback
	}
end

local makeDictionaryForRules

local function makeDictionaryForRule(dict: {}, map: {}, rule: GrammaticalRule, grammarRules: { [string]: GrammaticalRule }, stack: { [GrammaticalRule]: boolean })
	if rule.class == "pattern" and not map[rule.pattern] then
		map[rule.pattern] = true
		table.insert(dict, rule.pattern)
	elseif rule.class == "include" then
		makeDictionaryForRule(dict, map, grammarRules[rule.ruleName], grammarRules, stack)
	elseif rule.class == "modifier" then
		makeDictionaryForRule(dict, map, rule.rule, grammarRules, stack)
	elseif rule.class == "chain" then
		if rule.operation == "and" then
			makeDictionaryForRules(dict, map, rule.rules, grammarRules, stack)
		elseif rule.operation == "or" then
			for _, subrule in rule.rules do
				if stack[subrule] then
					continue
				end
				local substack = table.clone(stack)
				substack[subrule] = true
				makeDictionaryForRule(dict, map, subrule, grammarRules, substack)
			end
		end
	end
end

makeDictionaryForRules = function(dict: {}, map: {}, rules: { GrammaticalRule }, grammarRules: { [string]: GrammaticalRule }, stack: { [GrammaticalRule]: boolean })
	for _, rule in rules do
		makeDictionaryForRule(dict, map, rule, grammarRules, stack)
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
		makeDictionaryForRules(dict, map, rules, rules, {})
		return table.freeze(dict)
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

local function parseExpression(expression: AST.Structure): GrammaticalRule
	local first: AST.Structure = expression.first
	local name = first.name
	if name == "and-chain" then
		local subexprs = first:findChildrenByName("expression")
		local rules = parseExpressions(subexprs)
		return Grammar._and(rules)
	elseif name == "or-chain" then
		local subexprs = first:findChildrenByName("expression")
		local rules = parseExpressions(subexprs)
		return Grammar._or(rules)
	elseif name == "pattern" then
		return Grammar.pattern(Parser.unescape(first.first.value))
	elseif name == "name" then
		return Grammar.include(first.first.value)
	elseif name == "inline-whitespace" then
		return Grammar.whitespace(false)
	elseif name == "multiline-whitespace" then
		return Grammar.whitespace(true)
	elseif name == "repeation" then
		local subexpr = first:findChildByName("expression")
		local rule = parseExpression(subexpr)
		return Grammar.repeation(rule)
	elseif name == "optional" then
		local subexpr = first:findChildByName("expression")
		local rule = parseExpression(subexpr)
		return Grammar.optional(rule)
	elseif name == "group" then
		local subexpr = first:findChildByName("expression")
		return parseExpression(subexpr)
	end
end

parseExpressions = function(expressions: { AST.Structure }): { GrammaticalRule }
	local rules = {}
	for _, expression in expressions do
		table.insert(rules, parseExpression(expression))
	end
	return rules
end

local lbnfParser

function Grammar.parse(lbnf: string): Grammar
	local grammar = Grammar.new()
	local tree: AST.SyntaxTree = lbnfParser:parse(lbnf)
	tree:on("rule-definition", function(definition)
		local name = definition:findChildByName("name").first.value
		local expression = definition:findChildByName("expression")
		grammar:defineRule(name, parseExpression(expression))
		local first = definition.first
		if first.elementType == "token" and first.value == "!" then
			if grammar.rootRule then
				error("Grammar must have only one root rule")
			else
				grammar.rootRule = name
			end
		end
	end)
	require(script.Parent.Visualizer).showSyntaxTree(tree)
	-- require(script.Parent.Visualizer).showGrammar(grammar)
	return grammar
end

function Grammar.importAll()
	Grammar.importAll = nil
	
	Parser = require(script.Parent.Parser)
	
	local lbnfGrammar = Grammar.new()
	lbnfGrammar:defineRule("grammar", Grammar._and {
		Grammar.include("comments"),
		Grammar.repeation(
			Grammar._and {
				Grammar.include "rule-definition",
				Grammar.include "comments"
			}
		)
	})
	lbnfGrammar:defineRule("rule-definition", Grammar._and {
		Grammar.optional(Grammar.pattern "!"),
		Grammar.include "name",
		Grammar.whitespace(false),
		Grammar.pattern "=",
		Grammar.whitespace(false),
		Grammar.include "expression"
	})
	lbnfGrammar:defineRule("name", Grammar.pattern "[A-Za-z0-9-_]+")
	lbnfGrammar:defineRule("expression", Grammar._or {
		Grammar.include "name",
		Grammar.include "pattern",
		Grammar.include "and-chain",
		Grammar.include "or-chain",
		Grammar.include "repeation",
		Grammar.include "optional",
		Grammar.include "group",
		Grammar.include "inline-whitespace",
		Grammar.include "multiline-whitespace"
	})
	lbnfGrammar:defineRule("pattern", Grammar.pattern "([\"']).-[^\\]%1")
	lbnfGrammar:defineRule("and-chain", Grammar._and {
		Grammar.include "expression",
		Grammar.whitespace(false),
		Grammar.include "expression",
		Grammar.repeation(
			Grammar._and {
				Grammar.whitespace(false),
				Grammar.include "expression"
			}
		)
	})
	lbnfGrammar:defineRule("or-chain", Grammar._and {
		Grammar.include "expression",
		Grammar.whitespace(false),
		Grammar.pattern "|",
		Grammar.whitespace(false),
		Grammar.include "expression",
		Grammar.repeation(
			Grammar._and {
				Grammar.whitespace(false),
				Grammar.pattern "|",
				Grammar.whitespace(false),
				Grammar.include "expression"
			}
		)
	})
	lbnfGrammar:defineRule("repeation", Grammar._and {
		Grammar.pattern "{",
		Grammar.whitespace(false),
		Grammar.include "expression",
		Grammar.whitespace(false),
		Grammar.pattern "}"
	})
	lbnfGrammar:defineRule("optional", Grammar._and {
		Grammar.pattern "%[",
		Grammar.whitespace(false),
		Grammar.include "expression",
		Grammar.whitespace(false),
		Grammar.pattern "%]"
	})
	lbnfGrammar:defineRule("group", Grammar._and {
		Grammar.pattern "%(",
		Grammar.whitespace(false),
		Grammar.include "expression",
		Grammar.whitespace(false),
		Grammar.pattern "%)"
	})
	lbnfGrammar:defineRule("inline-whitespace", Grammar.pattern "*")
	lbnfGrammar:defineRule("multiline-whitespace", Grammar.pattern ">")
	lbnfGrammar:defineRule("comment", Grammar._or {
		Grammar.pattern "%-%-[^\n]+",
		Grammar.pattern "%-%-%[(=*)%[.-%]%1%]"
	})
	lbnfGrammar:defineRule("comments", Grammar._and {
		Grammar.whitespace(true),
		Grammar.repeation(
			Grammar._and {
				Grammar.include "comment",
				Grammar.whitespace(true)
			}
		)
	})
	lbnfGrammar.rootRule = "grammar"
	
	lbnfParser = Parser.new(lbnfGrammar)
end

return Grammar
