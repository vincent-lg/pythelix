---
title: "code — interactive scripting console module"
---

The `code` module provides the `Console` class for interactive Pythello code evaluation. A console accumulates input line by line, detects when the code is complete, executes it, and retains variables across evaluations. This is the building block for creating in-game scripting consoles, debugging tools, or any command that lets players or builders execute Pythello interactively.

**WARNING**: the `code` module can create a scripting playground. Very useful for debugging. If you give this tool to players, remember they will be able to create and destroy entities without control, so remain careful.

## `code.Console`

Create a new interactive console.

```
code.Console(variables=None)
```

### Parameters

| Name | Type | Required | Description |
|---|---|---|---|
| `variables` | dict | no | Initial variables available inside the console. Keys are variable names (strings), values are any Pythello value. |

### Return value

A `Console` object.

### Examples

Create a bare console:

```
console = code.Console()
```

Create a console with initial variables (e.g. for an in-game command where the character and its room should be accessible):

```
console = code.Console({"self": character, "location": character.location})
```

## `console.push`

Feed a line of input into the console.

```
console.push(text)
```

### Parameters

| Name | Type | Required | Description |
|---|---|---|---|
| `text` | string | yes | A line of code. |

### Return value

A dictionary with three keys:

| Key | Type | Description |
|---|---|---|
| `"status"` | string | `"complete"` — code was executed. `"need_more"` — the console is waiting for more lines. `"error"` — a syntax or runtime error occurred. |
| `"value"` | string or None | The `repr()` of the last expression's value when status is `"complete"`, or `None` if the code was a pure statement (e.g. an assignment). |
| `"error"` | string or None | The error message when status is `"error"`. |

### How it works

1. The text is appended to an internal buffer.
2. The buffer is checked for completeness (matching brackets, closed blocks, terminated strings, etc.).
3. If complete, the buffer is executed with the console's retained variables. New or updated variables are kept for the next call. The buffer is cleared.
4. If more input is needed (e.g. an `if` block without `endif`), the buffer is preserved and `"need_more"` is returned.
5. If a syntax error is detected in the buffer structure (e.g. unmatched `)`), the buffer is cleared and `"error"` is returned.

### Examples

Simple expression:

```
result = console.push("1 + 2")
# result["status"] == "complete"
# result["value"] == "3"
```

Assignment (no visible return value):

```
result = console.push("x = 42")
# result["status"] == "complete"
# result["value"] == None
```

Variable retention across pushes:

```
console.push("x = 10")
result = console.push("x * 3")
# result["value"] == "30"
```

Multi-line code:

```
console.push("i = 0")
console.push("while i < 3:")
# returns {"status": "need_more", ...}
console.push("self.msg(str(i))")
# returns {"status": "need_more", ...}
console.push("i += 1")
result = console.push("done")
# returns {"status": "complete", ...}
# (the loop executed, messages were sent)
```

## `console.buffer`

Read-only attribute. Contains the accumulated input as a string when the console is waiting for more lines, or `None` when the buffer is empty.

```
console.push("if True:")
console.buffer
# "if True:"
```

## `console.variables`

Read-only attribute. Returns a dictionary of the currently retained variables.

```
console.push("x = 5")
console.push("name = 'test'")
console.variables
# {"x": 5, "name": "test"}
```

## `console.reset`

Clear the buffer without clearing retained variables. Useful when a user wants to abandon an incomplete multi-line block and start over.

```
console.reset()
```

## `console.clear`

Clear both the buffer and all retained variables, returning the console to a fresh state.

```
console.clear()
```

## Full example: a `py` command

The simplest way to expose a Pythello console is through a single command. The console is stored on the character entity so that variables persist across invocations.

```
!command/py!
parent = "generic/char_command"
name = "py"
syntax = "<input>"
category = "Building"

def run(character, input):
    console = getattr(character"_py_console", None)
    if console == None:
        console = code.Console({"self": character, "location": character.location})
        character._py_console = console
    endif

    result = character._py_console.push(input)
    if result["status"] == "complete":
        if result["value"] != None:
            character.msg(result["value"])
    elif result["status"] == "need_more":
        character.msg("...")
    elif result["status"] == "error":
        character.msg(result["error"])
    endif
```

A player session might look like:

```
> py x = 5
> py x * 3
15
> py i = 0
> py while i < 3:
...
> py self.msg(str(i))
...
> py i += 1
...
> py done
0
1
2
> py self.location
!room/demo/bakery!
```

Because Pythello does not rely on indentation, every line can be entered separately through the command. Variables (`x`, `i`) persist until the console is cleared.

## Full example: a dedicated menu

For a more immersive experience, you can enter a dedicated menu mode with its own prompt. This avoids typing `py` before every line.

```
!command/pythello!
parent = "generic/char_command"
name = "pythello"
syntax = ""
category = "Building"

def run(character):
    console = getattr(character, "_py_console", None)
    if console == None:
        console = code.Console({"self": character, "location": character.location})
        character._py_console = console
    character.game_modes.add("menu/pythello", character)
    character.msg("Pythello console. Type 'quit' to exit.")

!menu/pythello!
parent = "generic/menu"
prompt = ">>>"

def unknown_input(self, character, input):
    console = character._py_console
    result = console.push(input)
    if result["status"] == "complete":
        self.prompt = ">>>"
        if result["value"] != None:
            character.msg(result["value"])
    elif result["status"] == "need_more":
        self.prompt = "..."
    elif result["status"] == "error":
        self.prompt = ">>>"
        character.msg(result["error"])

!command/pythello/quit!
parent = "generic/command"
location = "menu/pythello"
name = "quit"

def run(character):
    character.game_modes.remove(0)
    character.msg("Good bye.")
```

A session inside the menu:

```
> pythello
Pythello console. Type 'quit' to exit.
>>> x = 5
>>> x + 10
15
>>> if x > 3:
... self.msg("big")
... endif
big
>>> quit
Good bye.
```

The `>>>` prompt switches to `...` on the client side when `"need_more"` is returned (the worldlet above sends `"..."` as a message; adapting the prompt itself is left to the builder).

## Notes

- **Variables are de-referenced between executions.** When a script finishes, its internal references are cleaned up. The console extracts plain values and re-injects them on the next run, so retained variables survive across calls.
- **Console code can pause (or wait).**
- **Errors do not destroy variables.** If code raises an exception, variables set before the error are still retained for the next push.
- **Initial variables are injected once.** The dictionary passed to `code.Console()` seeds the console's variable store. Subsequent pushes can overwrite these variables like any other.
