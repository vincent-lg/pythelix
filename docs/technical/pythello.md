---
title: Pythello in technical terms
---

Pythelix relies on Pythello, a simple scripting language with a syntax very close to Python. This document describes how to interact with the engine and how it works behind the scenes.

If you don't know Pythello or its syntax, it's better to first read [the documentation on Pythello](../scripting.md).

## Executing a Pythello Script

Pythello is contained within its own set of modules defined under `Pythelix.Scripting`. This module generally helps interpret scripts on a somewhat higher level. Let's run a basic expression in Pythello and get the result in Elixir:

```elixir
iex(?)1> Pythelix.Scripting.eval("(2 + 8) * 5")
{:ok, 50}
```

We use the `eval` function and pass it a string containing a basic mathematical operation in Pythello. We get a tuple `{:ok, result}`.

The name `eval` might confuse those coming from Python: this function allows you to run full scripts spanning multiple lines. The important part is that the result of the last expression is always returned:

```elixir
iex(?)3> Pythelix.Scripting.eval("""
...(?)3> i = 0
...(?)3> number = 3
...(?)3> while i < 5:
...(?)3>   i += 1
...(?)3>   number *= 3
...(?)3> done
...(?)3> number
...(?)3> """)
{:ok, 729}
```

We provide a multiline string with our script. It creates two variables, `i` and `number`, then runs a loop incrementing `i` and multiplying `number` by 3, five times. The last line simply returns `number`. What happens here? The last expression (`number`) is returned by `Pythelix.Scripting.eval`.

`eval` is good to get the result of one or several Pythello instructions. It is mostly useful for debugging (you can safely use it; the REPL in `mix script` does so). Just keep in mind that it is a shortcut.

## Exploring the Script Structure

In most cases, we prefer to work with the full scripting structure. It may feel overwhelming since it contains a lot of information, but some fields are quite important, and all are useful to various degrees for running the Pythello engine.

Let's try the same example but using the `run` function instead:

```elixir
iex(?)4> Pythelix.Scripting.run("(2 + 8) * 5")
%Pythelix.Scripting.Interpreter.Script{
  bytecode: [line: 1, put: 2, put: 8, +: nil, put: 5, *: nil, raw: nil],
  cursor: 7,
  line: 1,
  stack: [],
  references: %{},
  variables: %{},
  bound: %{},
  last_raw: 50,
  pause: nil,
  error: nil,
  debugger: nil
}
```

This is the full structure of our Pythello script. It is a struct from the module `Pythelix.Scripting.Interpreter.Script`. Some fields are especially important:

- `bytecode`: the list of bytecode operations for this script. We'll discuss it in more detail later.
- `cursor`: the current position of the instruction pointer within the bytecode list. Here, it's at the very end (indicating the script was fully executed).
- `line`: the original script's current line number. Useful for error tracking.
- `stack`: Pythello’s virtual machine is stack-based, meaning it pushes and pops values. The stack is represented as a list (empty here).
- `references`: a map of references; we'll return to this later (it's empty in this example).
- `variables`: a map of variables. None in this script.
- `last_raw`: the last raw evaluated value (here, the final result of the expression).
- `error`: an optional error (traceback if any was raised). We'll discuss tracebacks later.
- Other fields exist but won't be discussed here.

### Understanding Bytecode

Some of this information relates to the bytecode structure. Pythello uses a very basic bytecode format with minimal optimization, which helps you understand what's happening. If you're not familiar with bytecode, this might be surprising, so let's take an example:

```elixir
iex(?)5> Pythelix.Scripting.run("1 + 2")
%Pythelix.Scripting.Interpreter.Script{
  bytecode: [line: 1, put: 1, put: 2, +: nil, raw: nil],
  cursor: 5,
  ...
}
```

We feed the engine the very basic instruction `"1 + 2"`. The bytecode is a sequence of operations to execute, represented as a list, each as a tuple with two elements: the operation name (an atom) and its value (any type). It looks like a keyword list. To clarify, you could think of it as:

```elixir
[
  {:line, 1},
  {:put, 1},
  {:put, 2},
  {:+, nil},
  {:raw, nil}
]
```

It's exactly the same data—just easier to read. Each bytecode tuple consists of two elements: the first is an atom naming the operation; the second is the value (or `nil` if no value is needed). So:

1. `{:line, 1}`
   Updates the current line number in the script to 1.

2. `{:put, 1}`
   Pushes the value 1 onto the stack.

3. `{:put, 2}`
   Pushes the value 2 onto the stack.

4. `{:+, nil}`
   Pops two values from the stack (1 and 2), adds them (getting 3), and pushes the result back onto the stack.

5. `{:raw, nil}`
   Pops the top value from the stack (3) and places it into `last_raw`.

This script adjusts the line count, pushes values onto the stack, adds them, and stores the result. At the end, the stack is empty. Notice how the stack is used multiple times here.

The stack is a simple list. When we push (via `:put`), we add elements at the head of the list; when we pop (like in the `:+` operation), we remove elements from the head. These are efficient list operations in Elixir.

> **Why not use registers instead of a stack?**

If you're familiar with bytecode processing, you might know stack-based virtual machines are not the only approach. Register-based VMs are more common and sometimes faster; however, they are more complex to implement. Here, the choice was made to keep things simple, which can change later without breaking compatibility.

To summarize: the bytecode is a sequential list of operations to execute. The stack is the memory of the script. The cursor indicates which bytecode is currently being executed.

Note: When a method (behavior attached to an entity) is stored in the database, both the original source code (string) and the bytecode list are saved. This avoids recompiling the script on each run, though it makes entities slightly larger on disk. The bytecode size is small compared to source strings.

### Variables

Variables are straightforward: they are stored in a map of names to values:

```elixir
iex(?)6> Pythelix.Scripting.run("""
...(?)6> i = 0
...(?)6> number = 3
...(?)6> while i < 5:
...(?)6>   i += 1
...(?)6>   number *= 3
...(?)6> done
...(?)6> """)
%Pythelix.Scripting.Interpreter.Script{
  bytecode: [...],
  cursor: 30,
  line: 3,
  stack: [],
  references: %{},
  variables: %{"i" => 5, "number" => 729},
}
```

The bytecode is more complex here, so it's omitted. The key point is that the `variables` map holds the values of `i` and `number`.

### References

So far, we've mostly dealt with primitive values like numbers. But Pythello can handle many types like lists, dictionaries, sets, entities, and so on. These are objects in Pythello.

Pythello, like Python, handles these by using references. In Python, a reference essentially indicates where a value is located in memory. Variables point to references (not directly to values). Here's an example in Python:

```python
>>> my_list = [1, 2, 3]
>>> my_list
[1, 2, 3]
>>> id(my_list)
2628550578752
>>> my_list.append(133)
>>> my_list
[1, 2, 3, 133]
>>> id(my_list)
2628550578752
```

Initially, `my_list` points to a list object at some memory address (ID). After appending a value, the list contents change, but the reference ID remains the same. So the variable points to the same reference, even though the underlying object is modified.

Pythello works similarly:

```elixir
iex(?)7> Pythelix.Scripting.run("""
...(?)7> my_list = [1, 2, 3]
...(?)7> my_list.append(133)
...(?)7> """)
%Pythelix.Scripting.Interpreter.Script{
  bytecode: [...],
  cursor: 15,
  line: 2,
  stack: [],
  references: %{#Reference<0.1473274994.3163029512.42954> => [1, 2, 3, 133]},
  variables: %{"my_list" => #Reference<0.1473274994.3163029512.42954>},
  ...
}
```

Here, the variable `my_list` stores a reference (`#Reference<...>`). Looking up that reference in the `references` map gives the current list `[1, 2, 3, 133]`.

Lists and other objects are not stored directly on the stack. Instead, a reference is created when they're first placed in memory, and variables hold references to them. Calling methods like `append` modifies the object that the reference points to, transparently to the user.

> **Why use references?**

It may feel complicated at first, but references allow objects to be mutable, as in Python. Elixir data is immutable by default, so methods like `append` actually create a new list. Using references replicates Python’s behavior so that objects can be modified while variables refer to stable references.

> **Are references long-lived?**

No, references exist only while a script runs (or shortly after). They are not meant to be stored persistently. If Pythelix detects a reference is intended to be stored (e.g., in an attribute), it attempts to resolve the reference's value, even if it must break object links. This may cause surprising behavior if you rely heavily on memory preservation, but this is advanced usage Pythello does not support.

Scripts can remain in memory in some circumstances, such as when stored as tasks, which can be restarted in different server sessions. In this case, references are invalid but still stored; Pythello will regenerate references upon loading. This is because references are implemented with Erlang VM references, which do not guarantee uniqueness across restarts.

To recap:

- Some Pythello values use references, which work as pointers to values stored in memory.
- Numbers (integers and floats), strings, and booleans do not use references; most other types do.
- For users, this is mostly transparent, but developers may need to query the script to get the value a reference points to.

The way to retrieve the value of a reference is to use `Script.get_value(script, reference)`. This is more than a simple map lookup: if the value contains nested references (e.g., lists inside lists), `get_value` recursively resolves them to return a fully dereferenced value.

Pythello allows recursive references (e.g., `my_list.append(my_list)`) similar to Python. However, `get_value` cannot fully resolve such cycles and returns an ellipsis (`:ellipsis`) in those cases.

```elixir
iex(?)1> script = Pythelix.Scripting.run("""
...(?)1> v = [1, 2, 3]
...(?)1> v.append(v)
...(?)1> """)
%Pythelix.Scripting.Interpreter.Script{
  bytecode: [...],
  cursor: 15,
  line: 2,
  stack: [],
  references: %{
    #Reference<0.1581766031.149946370.84906> => [1, 2, 3,
     #Reference<0.1581766031.149946370.84906>]
  },
  variables: %{"v" => #Reference<0.1581766031.149946370.84906>},
  ...
}
```

The references map holds one entry: the reference points to a list containing `[1, 2, 3]` and itself (recursive reference).

To retrieve the value:

```elixir
iex(?)2> [reference] = Map.keys(script.references)
[#Reference<0.1581766031.149946370.84906>]
iex(?)3> Pythelix.Scripting.Interpreter.Script.get_value(script, reference)
[1, 2, 3, :ellipsis]
```

`:ellipsis` corresponds to Python’s `...`. Running a similar Python script produces:

```python
>>> v = [1, 2, 3]
>>> v.append(v)
>>> v
[1, 2, 3, [...]]
```

In summary:

- To retrieve a variable’s value, use `Script.get_variable_value/2`.
- To retrieve the value associated with a reference, use `Script.get_value/2`.

Sometimes, it is useful to resolve a reference but leave inner references intact (not recursively dereference). For example, in the `append` example, you might want to resolve the list itself but keep its inner references. This can be done with `Script.get_value(script, reference, recursive: false)`.

This is especially useful for namespaces and modules that operate on collections like lists, dictionaries, and sets.

## From Parsing to Working Script

This section is more advanced and mostly for curiosity. If you want to learn more about Pythello’s inner workings, read on. Otherwise, you can skip this unless you plan to add new syntax.

### A Parser: From String to AST

Like most scripting languages, Pythello processes code in stages. When you feed it code as a string, it first produces an AST (Abstract Syntax Tree). This is a formal representation of the code, easier to interpret than the raw string.

To view the AST, use the `Pythelix.Scripting.Parser` module:

```elixir
iex> Pythelix.Scripting.Parser.eval("2 + 5")
{:ok, {:+, [2, 5]}}
```

The AST consists of simple structures (tuples and lists). For example, `2 + 5` is represented as `{:+, [2, 5]}`.

More complex expressions are nested accordingly:

```elixir
iex(?)2> Pythelix.Scripting.Parser.eval("(2 + 5) * 3")
{:ok, {:*, [{:+, [2, 5]}, 3]}}
```

Here, the `:*` operation has two arguments: a `:+` operation and a `3`. The parser manages operator precedence.

Under the hood, Pythello uses [NimbleParsec](https://hexdocs.pm/nimble_parsec/NimbleParsec.html), a library that easily transforms strings into desired structures (the AST here). Defining parsing rules with NimbleParsec is straightforward.

Note that the Pythello parser is split across multiple modules (e.g., `Pythelix.Scripting.Parser.Value` for values, `Pythelix.Scripting.Parser.Statement` for statements). Editing these modules to add syntax isn't difficult but depends heavily on your intended additions. Sometimes it is easier to write a parser directly with NimbleParsec and later integrate it.

### From AST to Bytecode

Next, the AST is converted into bytecode. This is performed with the `Pythelix.Scripting.Interpreter.AST` module, especially its `convert` function, which takes an AST and returns a `Script` struct.

This module is mostly self-contained; converting AST to bytecode is straightforward with various function clauses handling different AST forms. For example:

```elixir
defp read_ast(code, {op, [left, right]}) when op in [:+, :-, :*, :/] do
  code
  |> read_ast(left)
  |> read_ast(right)
  |> add({op, nil})
end
```

This clause handles arithmetic operations by recursively reading left and right operands, then adding the operation bytecode.

If you add new syntax, you may also need to extend this AST-to-bytecode conversion.

### Bytecode Execution in the Virtual Machine

Finally, the bytecode list is executed by the virtual machine (`Pythelix.Scripting.Interpreter.VM`). This VM maps bytecode operations to functions, managing memory, variables, references, control flow (jumps and conditions), and retrieving nested values (e.g., entity attributes).

Unlike parsing and AST conversion, often you do not need to add new bytecode support for new syntax; common operations are already handled. It's possible that a sequence of existing bytecodes can implement your addition.

This document won’t go into more detail here. If you're interested in extending Pythello's syntax, feel free to reach out. Keep in mind, Pythello is not Python and is not intended to become Python; it’s a simple language with a more limited syntax, focusing on usefulness rather than full Python compatibility.
