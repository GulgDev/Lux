---
permalink: /grammar
title: Grammar
toc: true
---

Lux uses LBNF (BNF variant) to describe the grammar.

## Basics
### Defining rules

To define rule simply do this:

{% highlight lbnf %}
rule name = expression
{% endhighlight %}

Rule name must only contain letters, digits and underscores:
{% highlight lbnf %}
first_valid_rule_name
invalid rule name
2nd_valid_rule_name
{% endhighlight %}

### Root rule

To define root rule (rule that will be used to match the whole input) use !:
{% highlight lbnf %}
!root rule name = expression
{% endhighlight %}
Rule name can be only defined **once**!

### Patterns

Basic rule for LBNF is [pattern](https://www.lua.org/pil/20.2.html). Pattern must be surrounded by quotes:

{% highlight lbnf %}
"LBNF pattern"
{% endhighlight %}

**Don't** use whitespaces and line breaks in patterns: use inline and multiline indent instead!

### Includes

You can include rules by name and use them in other rules:

{% highlight lbnf %}
first-rule = "pattern"
second-rule = first-rule
{% endhighlight %}

### Whitespace

You can define whitespace of any length using whitespace operators:

{% highlight lbnf %}
* -- inline whitespace
> -- multiline whitespace
{% endhighlight %}

### Groups

You can group rules by using parentheses:

{% highlight lbnf %}
rule = (a | b) c
{% endhighlight %}

### Chains

Chains are rule sets that can be used to define a rule sequence or a rule variants.

{% highlight lbnf %}
rule = "a" | "b" -- "or" chain
rule = "a" "b" -- "and" chain
{% endhighlight %}

### Modifiers

Rule modifiers describe how many times the rule can be repeated:
{% highlight lbnf %}
rule = [abc] -- optional (0 or 1)
rule = {abc} -- repeation (0 or more)
{% endhighlight %}
