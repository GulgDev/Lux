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

First thing you have to do is define grammar. You can do it two ways: using LBNF and manually. We will use LBNF because it's much more easier to understand.

{%highlight lua %}
local parser = Lux.generateParser([[
name = "%u%l+" -- One uppercase letter and lowercase letters
greetings = "Hello," * name -- * is indent
]])
{%endhighlight%}
