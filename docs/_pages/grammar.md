---
permalink: /grammar
title: Grammar
toc: true
---

## LBNF

Lux uses LBNF (BNF variant) to describe the grammar.

### Defining rules

To define rule simply do this:

{% highlight lbnf %}
rule-name = expression
{% endhighlight %}

Rule name must only contain letters, digits, hyphens and underscores:
{% highlight lbnf %}
first-valid-rule-name
invalid $rule name&
2nd-valid-rule-name
{% endhighlight %}

### Root rule

To define root rule (rule that will be used to match the whole input) use !:
{% highlight lbnf %}
!root-rule-name = expression
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

You can specify repeation count:
{% highlight lbnf %}
rule = {abc}<min..max>
{% endhighlight %}

{%highlight lbnf %}
{abc} is same as {abc}<0..inf>
[abc] is same as {abc}<0..1>
{% endhighlight %}

## Advanced usage

You can create rules manually using Grammar.\_or, Grammar.\_and, Grammar.repeation, Grammar.optional, Grammar.pattern, Grammar.include, Grammar.whitespace and Grammar.custom.

### Custom rules

You can define custom rules using Grammar.custom:

{% highlight lua %}
Grammar.custom(function(parser, elements)
    return true, elements, #elements -- success, result, count
end)
{% endhighlight %}
