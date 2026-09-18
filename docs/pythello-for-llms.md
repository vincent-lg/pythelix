---
title: Pythello for Python programmers (and AI assistants)
---

Pythello is the scripting language of [Pythelix](./index.md). It is deliberately close to Python, so that anyone who has seen Python can read it. It is **not** Python, and it is not trying to become Python.

This page is the complete list of the differences. It assumes you already know Python and tells you only what changes. If you are writing Pythello with the help of an AI assistant, give it this page: it is short on purpose, so it can be read in full before writing a single line.

Everything not mentioned here behaves as you would expect: `if`/`elif`/`else`, `for`, `while`, `try`/`except`/`else`/`finally`, `and`/`or`/`not`, `is`/`is not`, `in`, `+= -= *= /=`, `#` comments, `True`/`False`/`None`, integers, floats, strings, f-strings, lists, tuples, dicts, sets, and their usual methods.

> **Check your work.** Run `mix pythello.check` (or `bin/check` in a release) on your worldlets before applying them. It parses without a server and names the rule you broke; almost everything on this page is caught by it. Then prove the behaviour with a [scenario](./scenarios.md) — both are covered at the end of this page.

## The short version

| Instead of this Python… | …write this Pythello |
|---|---|
| closing a block by dedenting | close it with `endif`, `done` or `endtry` |
| `for x in range(10):` | `range()` does not exist — loop over a list |
| `[x.name for x in things]` | a `for` loop with `.append()`, closed by `done` |
| `lambda x: x + 1` | a named method with `def` |
| `except ValueError as error:` | `except ValueError:` (no `as`) |
| `pass` | nothing at all, or `return` |
| `print(value)` | `character.msg(value)`, or `log(value)` |
| `sorted(items)` | `items.sort()` (sorts in place) |
| `len(s)`, `str(x)`, `int(x)` | the same — these do exist |
| `{"a":1}` | `{"a": 1}` — **a space after the colon is required** |
| `items[1:]` | no slicing; loop instead |
| `text[0]` | no string indexing |
| `[1, 2][0]` | index through a variable, not a literal |
| `"{}".format(x)` or `"%s" % x` | `f"{x}"` |
| `x = 1 if cond else 2` | a real `if`/`else` block |
| `import random` | nothing — `random` is already there |
| `class Weapon:` | an entity with a `parent` |
| `with open(...) as f:` | not supported |
| `if (n := f()) > 5:` | assign on its own line first |
| `@decorator` | not supported |

## Blocks end with a keyword

This is the difference you will trip on most. **Indentation means nothing in Pythello.** Every block is closed by a keyword:

| Block | Closed by |
|---|---|
| `if` / `elif` / `else` | `endif` |
| `for` | `done` |
| `while` | `done` |
| `try` / `except` / `else` / `finally` | `endtry` |
| `def` | *nothing* — see below |

```
if result == 1:
    character.msg("You roll a 1. Ouch.")
elif result == 6:
    character.msg("You roll a 6! Critical luck!")
else:
    character.msg(f"You roll a {result}.")
endif
```

```
total = 0
for coin in character.contents:
    total += coin.value
done
```

```
try:
    value = 10 / divisor
except ZeroDivisionError:
    value = 0
endtry
```

Note there is no `endfor`, no `endwhile` and no `endfunction`: `for` and `while` both close with `done`.

Indentation is still good manners — it makes the code readable, and everyone indents — but the parser ignores it. What ends a block is the keyword, nothing else.

> **Why?** Pythello can be typed directly into a MUD client, where leading whitespace is awkward or impossible to enter reliably. Explicit terminators mean a script can be written in a text editor, in the game, or over a network connection, and mean the same thing.

A method has no terminator. It runs until the next `def`, the next `!entity!` header, or the end of the file:

```
def greet(self, character):
    character.msg(f"{self.name} nods at you.")

def farewell(self, character):
    character.msg(f"{self.name} waves goodbye.")
```

## Functions that do not exist

These are ordinary Python builtins with no Pythello equivalent. Calling one raises `NameError: name '...' is not defined` **at runtime**, so it is worth knowing them by heart — the game will only tell you when a player triggers that line:

`print` · `range` · `sorted` · `min` · `max` · `abs` · `sum` · `round` · `any` · `all` · `enumerate` · `zip` · `reversed` · `map` · `filter` · `open` · `input`

`pass` does not exist either. It is not a keyword and not a function: writing it raises `NameError`. An empty block simply has no lines in it.

These builtins **do** exist:

`bool` · `int` · `float` · `str` · `repr` · `len` · `list` · `dict` · `set` · `tuple` · `getattr` · `setattr` · `hasattr` · `delattr` · `isinstance` · `entity` · `Entity` · `apply` · `ask` · `choice` · `stackable` · `log`

Instead of `print`, send a message to whoever should see it — `character.msg(...)`, `self.location.announce(...)` — or write to the server log with `log(...)`.

Instead of `range`, loop over a real list, or use a `while`:

```
i = 0
while i < 10:
    i += 1
done
```

## Syntax that does not exist

**No comprehensions**, in any form — list, dict, set or generator. Build the collection:

```
# Not: names = [c.name for c in self.contents]
names = []
for content in self.contents:
    names.append(content.name)
done
```

**No lambdas.** Give the function a name with `def`, or inline the expression.

**No slicing, and no string indexing.** `items[1:]` is a syntax error, and a string cannot be indexed at all: `text[0]` fails.

**Index through a variable, not a literal.** Lists, tuples and dicts index normally — `items[0]`, `d["key"]`, `d["a"][1]` — and a list element can be assigned (`items[0] = x`). But subscripting a literal directly is a syntax error:

```
value = [1, 2][0]        # syntax error
items = [1, 2]
value = items[0]         # fine
```

The same goes for calling a method on a list literal: bind it to a variable first.

**`finally` requires an `except`.** A bare `try:` / `finally:` / `endtry` is a syntax error; `else` and `finally` are otherwise as in Python, and `except:` on its own catches everything.

**No conditional expression.** `x = 1 if cond else 2` is a syntax error — use a real `if` block.

**No `%` formatting and no `.format()`.** Use f-strings.

**No `import`.** The namespaces below are always available.

**No `class`.** Behavior lives on [entities](./entities.md), and inheritance is the `parent` attribute.

**No `with`, no decorators, no walrus operator (`:=`).**

**Exceptions cannot be bound to a variable.** Write `except ValueError:`, never `except ValueError as error:`.

## What Pythello adds

### Entities are part of the language

An entity key between exclamation marks is an entity literal:

```
room = !room/bakery!
!room/bakery!.title = "A brightly-lit bakery"
```

Reading and writing attributes is ordinary attribute access — and **writing one saves it immediately**, permanently:

```
npc.hp = 20
npc.tags.append("hostile")
```

There is no save step and no commit. See [entities](./entities.md) and [scripting](./scripting.md#scripting-and-entities).

### Time and duration literals

```
15:00          # a time (hour:minute)
8:30:45        # hour:minute:second
15s  3m  2h30m # durations: s, m, h, d (days), o (months), y (years)

15:00.add(2h30m)      # 17:30
3m.total_seconds()    # 180
```

### Always put a space after the colon in a dict

Because `15:00` is a time, a colon with no space after it is read as one. This makes the most common Python way of writing a dict wrong, and it is the single easiest mistake to make:

```
d = {"a":1}          # SyntaxError
d = {"a": 1}         # a dict, as intended

d = {1:2}            # NO ERROR — a set containing the time 01:02
d = {1: 2}           # a dict, as intended
```

Note the second pair: `{1:2}` does not fail. It quietly builds something else entirely, and you find out much later. **Write dict literals with a space after every colon.** The rule applies inside nested dicts too.

This affects only the literal. Reading and writing (`d["a"]`, `d["a"] = 1`) are unaffected.

### `wait` suspends a script

```
character.msg("Hold on...")
wait 2m30s
character.msg("Done.")
```

### f-strings are evaluated late

An f-string is stored and formatted when it is *delivered*, not where it is written. This lets one message describe the same scene correctly to several viewers (names, visibility, pluralisation). So `text = f"{self} arrives."` does not produce a string right away — it produces something that becomes the right string for each recipient. It matters only if you expected to inspect the text in between.

### Namespaces always available

`random` · `realtime` · `gametime` · `clients` · `names` · `search` · `display` · `password` · `stats` · `code`

```
result = random.randint(1, 6)
exit = random.choice(exits)
now = realtime.now()
```

## The worldlet file

Pythello is usually written inside a [worldlet](./worldlets.md) — a `.txt` file describing entities. The file itself is not Pythello; it has three kinds of line:

```
!command/roll!                      # an entity key, starting a new entity
parent = "generic/char_command"     # an attribute (the value is a Pythello expression)
name = "roll"
category = "General"

def run(character):                 # a method; its body is Pythello
    result = random.randint(1, 6)
    character.msg(f"You roll a {result}.")
```

- Every entity in a worldlet **must** have a key, unique across the game.
- `parent` gives inheritance: the entity gets the parent's attributes and methods unless it defines its own. An entity has at most one parent.
- Applying a worldlet **creates or updates** — it is a blueprint, not a save file. Reapplying it is safe.
- Multi-line attribute values are allowed; the line continues until brackets and quotes balance.

Apply with the `apply` command in game, or `mix apply` / `bin/apply`.

## Methods and `self`

```
!generic/npc!

def greet(self, character):
    character.msg(f"{self.name} says: Hello, traveler.")
```

If the first argument is named `self`, it is filled in automatically with the entity the method belongs to — as in Python, but without a class. Callers do not pass it: `npc.greet(player)`.

Arguments may carry type hints and defaults, which are enforced at call time:

```
def greet(self, character: Entity["generic/character"], loudly: bool = False):
```

Some method names are called by the engine: `run` for a command, `on_tick` / `on_major_tick` for [ticking](./ticking.md), `can_leave` / `leave` / `enter` on rooms. See [methods](./methods.md) and [commands](./commands.md).

## Checking before applying

```
mix pythello.check                    # every worldlet
mix pythello.check worldlets/farm     # one directory
mix pythello.check --json             # for editors and tools
```

It needs no running server and changes nothing. A problem is reported with its line, the rule it breaks and where that rule is documented:

```
worldlets/quest.txt:7:14  in method run of !command/quest!
  list comprehensions are not supported
          active = [q for q in character.quests if q.active]
                   ^
  Build the list with a `for` loop and `append`, closing the loop with `done`.
  → docs/scripting.md#loops
```

The same explanation appears when you `apply` in game, so a mistake is never a stacktrace.

Two things the checker cannot see, because they are only wrong at runtime: a call to a function that does not exist (`print`, `range`, `pass`), and a wrong argument type. Both raise a traceback that reaches you, and administrators, in game.

## Proving that it works

The checker says the script is valid Pythello. It cannot say the command does what was asked. For that, write a [scenario](./scenarios.md) — a transcript of someone playing, which the engine carries out:

```
given Alice in !farm/room/field!
given Bob in !farm/room/field!

Alice> harvest wheat
Alice sees "You harvest a bundle of wheat."
Bob sees "Alice bends down and harvests some wheat."
Bob does not see "You harvest"
```

Save it under `scenarios/` and run `mix pythello.scenario` (or `bin/scenario` in a release). This is the whole language:

| | |
|---|---|
| `apply <path>` | apply an extra worldlet — the game's own are always applied first |
| `given <Name> in !<key>!` | a player of that name, in that room, logged in |
| `given <n> !<key>! in <where>` | put things somewhere — a room key, or a player's name |
| `connect <Name>` | a client at the login menu, not logged in |
| `<Name>> <input>` | that player types that line |
| `<Name> sees "<text>"` | the text reached them since they last typed |
| `<Name> does not see "<text>"` | it didn't |

Entities a scenario needs in place go in `scenarios/fixtures/` as ordinary worldlets; files there are never played, and `apply` looks there first.

Text is matched as a substring and is case-sensitive, so `sees "command not found"` will not match `Command not found.` Every expectation after one input asks about that same exchange, so several may follow a single line of input.

**Write the scenario before the worldlet.** "When Alice harvests, Bob should see her do it" is the request itself, in the words it was asked in — and someone who has never programmed can read it back and tell you whether you understood them, which they cannot do with the Pythello. Then implement until it passes.

## Where to go next

- [Scripting](./scripting.md) — the language in full, with the console
- [Entities](./entities.md) — what the world is made of
- [Worldlets](./worldlets.md) — the files, and building with others
- [Methods](./methods.md) — arguments, type hints, return values
- [Commands](./commands.md) — syntax strings and parsing player input
- [Scenarios](./scenarios.md) — proving that what you built does what was asked
