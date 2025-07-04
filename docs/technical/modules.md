---
title: Modules and namespaces in Pythelix
---

Pythello is designed to be flexible and to provide useful functions out of the box. However, you might want to add more operations. This document explains how you can extend or add new modules, as well as how to extend and add new namespaces.

## What features might I need to add?

Pythello faces the same challenge as every programming language: it cannot anticipate which features will be most important to every user and provide implementations that work for everyone. Therefore, it comes packaged with simple features covering many use cases while allowing developers to easily add new features.

Another critical concern for Pythello is security, especially considering that the code you write in Pythello could potentially be seen by others (at least other builders).

For example, suppose you want one of your non-player characters (NPCs) to be AI-powered, to "understand" conversations around them and respond accordingly. This is easier to do in a MUD because most actions involve simple text.

What are your options? You could query an AI API, such as those from OpenAI, Anthropic, or Google, but these APIs usually require a secret key.

Would you write this key directly in your Pythello script? It's better not to. This would be dangerous: if your code leaks, it could compromise not only your game but also your account on these platforms, not to mention result in higher costs.

Moreover, Pythello doesn't provide built-in support for sending or receiving data from an API.

What you want is something simple to use—a module with a function `chat` that sends a prompt to an AI model and returns the response. Your key remains secure, stored in your Elixir configuration or an environment variable, for example.

In the end, you might write something like:

```
prompt = f"""
You are a non-player character named Daisy. Your profession is... your description is...
You need to interact with other players in the room by speaking or gesturing in reaction to what happens
around you. Keep the tone casual and realistic, acting as if you were on a street confronted
with the given situation.
{message}
"""
response = AI.chat(prompt)
self.location.msg(response)
```

You don’t provide the key in your Pythello code: you just call a module function and receive the answer, then display it. Easy to use—perhaps too easy, since other builders might want to use the same system for their own NPCs... so watch out for usage limits.

Similarly, you could write a simple function to send emails using your Mailgun or SendGrid API. The same principle applies: don’t hardcode your key in Pythello code where others might read it.

## Namespace and modules: what’s the difference?

A **namespace** defines the set of attributes and methods of an object in Pythello. For instance, the `list` object has a namespace that contains methods like `append` and `insert`, which you can call on the object.

A **module**, in contrast, is simply a place where functions reside. Interestingly, in Python both concepts can be considered as namespaces. In Pythello, their definitions are very close. Let’s look at the `random` module:

```elixir
defmodule Pythelix.Scripting.Namespace.Module.Random do
  @moduledoc """
  Module defining the random module.
  """

  use Pythelix.Scripting.Module, name: "random"

  defmet randint(script, namespace), [
    {:a, index: 0, type: :int},
    {:b, index: 1, type: :int}
  ] do
    %{a: a, b: b} = namespace

    if b < a do
      {Script.raise(script, ValueError, "empty range #{a}..#{b}"), :none}
    else
      {script, Enum.random(a..b)}
    end
  end
end
```

This example already contains a lot:

1. A Pythello module is just an Elixir module.
2. It uses `Pythelix.Scripting.Module`, providing a name via the `name` option (a string). This is the name used to access the module (in this case, `random`).
3. It uses `defattr` to define an attribute and `defmet` to define a method. Note that even in a module, a function is actually a method for Pythello (we won't elaborate on the reason here).
4. A method resembles a function but with some differences: it uses `defmet` instead of `def`, takes only two arguments (`script` and `namespace`), and precedes the `do` block with a list of arguments.

The `namespace` is just a simple map. The arguments defined in the list are placed in the namespace.

Our example method expects two arguments:

1. `{:a, index: 0, type: :int}`

   The argument `:a` (available as `namespace.a`) is a positional argument at position 0 (the first positional argument). Its type should be an integer (`:int`).

2. `{:b, index: 1, type: :int}`

   The second argument `:b` (available as `namespace.b`) is the second positional argument (index 1) and also an integer.

This simple definition lets Pythello know that our method requires two integer arguments. If you call it incorrectly, it won’t execute the method at all, for example:

```
>>> random.randint()
Traceback (most recent call last):
  <stdin>, line 1
    random.randint()

TypeError: expected positional argument b
>>> random.randint(1, 2, 3)
Traceback (most recent call last):
  <stdin>, line 1
    random.randint(1, 2, 3)

TypeError: expected at most 2 arguments, got 3
>>> random.randint("a", "b")
Traceback (most recent call last):
  <stdin>, line 1
    random.randint("a", "b")

TypeError: argument b expects value of type :int
```

### Method arguments

As seen above, a method argument is defined as a tuple with the syntax:

```elixir
{:argument_atom, [options]}
```

The argument atom is required and corresponds to the key set in the namespace. The options can include:

- `index`: a number indicating the position if this is a positional argument (starting at 0);
- `keyword`: the keyword argument name, if this is a keyword argument (a string). An argument can be positional and keyword, or just one of these.
- `type`: the argument type, which can be:

  - `:any` — any value allowed
  - `:int` — integers only
  - `:float` — floating-point numbers only
  - `:str` — strings or formatted strings
  - `:entity` — an entity
  - `{:entity, ancestor}` — an entity that has this ancestor
  - `:list` — a list
  - `:dict` — a dictionary
  - `:set` — a set

- `default`: sets a default value, making this argument optional (for example, `default: :unset`)
- `args`: accepts all remaining positional arguments
- `kwargs`: accepts all remaining keyword arguments

The last two options (`args`, `kwargs`) allow creating methods with a variable number of arguments, similar to `*args` and `**kwargs` in Python.

To extract these arguments from the namespace (a map), you can use pattern matching or the `namespace.atom_name` notation.

### Return value

Every Pythello method must return two values: the (possibly modified) script, and the return value (which will be placed on the stack).

That’s why the return looks like this:

```elixir
{script, Enum.random(a..b)}
```

Pythello handles most Elixir types and converts them when needed: Elixir integers and floats become Pythello integers and floats, strings remain strings. Atoms don’t exist in Python, and Pythello doesn’t use them either—except for `true` and `false` (which become `True` and `False` in Pythello) and `:none` (which becomes `None` in Pythello). Pythello lists are Elixir lists, but Pythello uses its own type for dictionaries (see `Pythelix.Scripting.Object.Dict`). Tuples are not converted and can be used to store specific information in memory. Maps aren’t used in Pythello and you should avoid returning them.

In summary:

- `Enum.random(a..b)` returns a random number in the given range.
- We return this number along with the script—unchanged in this case.

### Raising exceptions

In the same function, you may have noticed:

```elixir
%{a: a, b: b} = namespace

if b < a do
  {Script.raise(script, ValueError, "empty range #{a}..#{b}"), :none}
else
  {script, Enum.random(a..b)}
end
```

Raising an exception in Pythello modifies the script structure (setting its `error` flag, including a full traceback). We use `Script.raise`, which takes three arguments:

- The script itself
- The exception (a capitalized atom)
- The message (a string)

But we still need to return two values, so we return the modified script and `:none` as the return value. Usually, the traceback will propagate, so the return value is rarely important. If it is, those cases are uncommon. Just return `:none` when you raise an exception.

The exception atom (`ValueError` here) matters because Pythello uses Python-like exceptions. The exception hierarchy is formally defined and you may want to catch specific exceptions.

### Working with references

All arguments passed to a method are provided as references. Some Pythello values—like numbers, booleans, and strings—do not use references. Otherwise, you should use `Script.get_value` to retrieve the actual value from a reference.

This should be done carefully. Here’s an excerpt from the `dict` namespace, specifically the `get` method:

```elixir
defmodule Pythelix.Scripting.Namespace.Dict do
  # ...
  defmet get(script, namespace), [
    {:key, index: 0, type: :any},
    {:value, index: 1, type: :any, default: :none}
  ] do
    dict = Script.get_value(script, namespace.self, recursive: false)

    {script, Dict.get(dict, namespace.key, namespace.value)}
  end
end
```

Notes:

- `dict` (stored in `namespace.self`) is our collection. Like everything in `namespace`, `self` is a reference. We need the value, but want to preserve inner references if the dictionary contains lists, entities, or similar. That's why we use `recursive: false` in `get_value`; we only retrieve the top-level dictionary while keeping the inner references intact.
- Do we need the actual value of the key, or just its reference? This is tricky: if the dictionary uses lists as keys, matching requires the exact same reference, not just an equal value. Therefore, it makes sense to keep the key as a reference.
- Similarly, we keep the value as a reference for the same reason.

Thus, the only thing converted from a reference to a value here is the outer dictionary. Keys and values remain references.

The `dict` namespace is somewhat complex, needing to handle multiple scenarios that may not often occur in your use cases; still, it’s worth studying the conflicts here and thinking about how to resolve them.
