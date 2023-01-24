---
title: Lux
---

Lux is a parser generator for Luau.

It can be used for creating custom languages, creating powerful tools, such as command parser and a lot of other things! Lux has many useful functions for parsing and lexing.

## Getting started

To start working with Lux, let's create a simple parser.

{% highlight ebnf %}
-- Rules
name = "Bob" | "Steve" -- Bob or Steve
hello = "Hello," * name ["!"] -- "Hello," (indent) (Bob or Steve) (optional "!")
bye = "Bye!"

-- Root rule (must start with "!")
!program = > { hello > } bye > -- Hello rule any number of times, and then bye rule. (> is multiline indent)
{% endhighlight %}
