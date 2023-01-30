---
permalink: /syntax-tree-browsing
title: Syntax tree browsing
toc: true
---
Basic syntax tree browsing function is tree:forEach. Using this function you can execute given function for each structure with given name:
{%highlight lua %}
tree:forEach("greetings", function(structure)
    print("Hello,", strcture:findChildByName("name").first.value)
end)
{%endhighlight%}
