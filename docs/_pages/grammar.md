---
permalink: /grammar
title: Grammar
---

Lux uses LBNF (BNF variant) to describe the grammar.

## Basics
### Patterns

Basic rule for LBNF is [pattern](https://www.lua.org/pil/20.2.html). Pattern must be surrounded by quotes:

{% highlight lbnf %}
"LBNF pattern"
{% endhighlight %}

**Don't** use whitespaces and line breaks in patterns: use inline and multiline indent instead!

### Defining rules

To define rule simply do this:

{% highlight lbnf %}
rule name = your expression
{% endhighlight %}

Rule name must only contain letters, digits and underscores:
{% highlight lbnf %}
first_valid_rule_name
invalid rule name
2nd_valid_rule_name
{% endhighlight %}

### Root rule

To define root rule (rule that will be used to match the whole input) use !:
