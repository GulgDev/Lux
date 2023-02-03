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
local parser = Lux.generateParser([[ -- Generate grammar & parser
name = "%u%l+" -- One uppercase letter and lowercase letters
greetings = "Hello," name -- "Hello," and name
!text = { greetings } -- Root rule: any greetings.
]])
{%endhighlight%}

But if you want to define grammar manually you have to do this:

{%highlight lua %}
local grammar = Lux.Grammar.new() -- Create grammar
grammar:defineRule("name", Lux.Grammar.pattern "%u%l+") -- One uppercase letter and lowercase letters
grammar:defineRule("greetings", Lux.Grammar._and {
    Lux.Grammar.pattern "Hello,",
    Lux.Grammar.include "name"
}) -- "Hello," and name
grammar:defineRule("text", Lux.Grammar.repeation(
    Lux.Grammar.include "greetings",
    0, math.huge
)) -- Root rule: any greetings.
grammar.rootRule = "text"

local parser = Lux.Parser.new(grammar) -- Create parser
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

![Visualization result]({{ "/assets/images/visualizer.png" | relative_url }})
