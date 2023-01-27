---
permalink: /tutorial
title: Tutorial
toc: true
---
Lux is an easy to use string parsing tool. You can get it on [Roblox Creator Marketplace](https://create.roblox.com/marketplace/asset/12285625378/Lux). After installation you can require and use it:

{%highlight lua %}
local Lux = require(script.Lux)
{%endhighlight%}

### Generating parser

First thing you have to do is define grammar. You can do it two ways: using LBNF and manually. Then you can create a parser with your grammar. We will use LBNF because it's much more easier to understand.

We don't have to do a lot of stuff:

{%highlight lua %}
local parser = Lux.generateParser([[
name = "%u%l+" -- One uppercase letter and lowercase letters
greetings = "Hello," * name -- "Hello,", indent and name
!text = > { greetings > } -- Root rule: multiline indent, and any greetings with multiline indents.
]])
{%endhighlight%}

But if you want to define grammar manually you have to do this:

{%highlight lua %}
local grammar = Lux.Grammar.new()
grammar:defineRule("name", Lux.Grammar.pattern "%u%l+") -- One uppercase letter and lowercase letters
grammar:defineRule("greetings", Lux.Grammar._and {
    Lux.Grammar.pattern "Hello,",
    Lux.Grammar.whitespace(false),
    Lux.Grammar.include "name"
}) -- "Hello,", indent and name
grammar:defineRule("text", Lux.Grammar._and {
    Lux.Grammar.whitespace(true),
    Lux.Grammar.repeation(
        Lux.Grammar._and {
            Lux.Grammar.include "greetings",
            Lux.Grammar.whitespace(true)
        }
    )
}) -- Root rule: multiline indent, and any greetings with multiline indents.
grammar.rootRule = "text"
{%endhighlight%}

### Parsing

Now you can use your parser to parse text:

{%highlight lua %}
local tokens = parser:tokenize("Hello, Bob")
local tree = parser:parse("Hello, Bob")
{%endhighlight%}

### Viewing tokens & syntax tree

You can view the result using Lux.show:

{%highlight lua %}
Lux.show(tokens)
Lux.show(tree)
{%endhighlight%}
