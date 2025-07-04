---
title: Commands in Pythelix
---

It's easy to create commands in Pythelix. It's even easier to keep track of which commands are available and to provide a robust help system that doesn't leave anything out.

## Commands are entities

In Pythelix, most things are [entities](./entities.md), and commands are no exception. They are **virtual entities**, meaning they are not stored in the database.

Virtual entities are created when applying a [worldlet](./worldlets.md) as usual, but they will not be stored. If you want to remove a command, simply remove it from the worldlet and reapply it.

You could create a command in Pythelix by writing something like this:

```
[command/shout]
parent: "generic/command"
name: "shout"

{run}
client.msg("NOT SO LOUD!")
```

1. Like any entity, a command should have a unique key. The exact value doesn't matter much, but it should be unique.
2. The `parent` attribute is critical here: this entity inherits from `"generic/command"`. This parent entity is created automatically by Pythelix, and all commands should inherit from it. This inheritance informs Pythelix that this is a virtual entity; no further configuration is needed.
3. The `name` attribute contains the command's name, a string the players will type to invoke this command.
4. The command defines a single method, `run`, which is called whenever the command is used by a player.

If a player connects to your MUD and types `shout` or `shout something`, they will receive the message:

> NOT SO LOUD!

Of course, commands can be much more powerful than that (and usually are), but it's important to connect these dots:

- You create a virtual entity with a parent of `"generic/command"`.
- When a player enters the command name (or a valid abbreviation of it), followed optionally by a space and arguments, the command's `run` method is executed.
- You can use all the power of Pythello, the [scripting language](./scripting.md), to make the command behave however you want.

Now for the finer points.

## Command attributes

| Attribute     | Type            | Description |
| ------------- | --------------- | ----------- |
| `parent`      | String          | The parent entity of the command. Always `"generic/command"` or another entity inheriting from it. |
| `name`        | String          | The command's name. **Mandatory**. |
| `can_shorten` | Boolean         | Defaults to `True`. If `True`, abbreviated forms of the command name are accepted. For example, if the command name is `shout`, entering `shou` or even `sh` will match the command. Often desirable, but can be turned off for individual commands or groups (see below). |
| `syntax`      | String          | The syntax describing the command's arguments. By default, a command has no arguments. See the dedicated section below. |
| `help`        | String          | Optional help text for the command. Recommended for building a comprehensive help system. |
| `aliases`     | List of strings | Optional list of alternative names for the command. Example: `aliases = ["st", "stat"]` to reach a `status` command. Note that since command names can generally be abbreviated, aliases are less often needed. |

> **Tip:** Want to disable command abbreviations globally without repeating `can_shorten = False` in every command? Easy. Just create an entity in your [worldlet](./worldlets.md) that inherits from `"generic/command"` with this configuration:

```
[generic/custom_command]
parent: "generic/command"
can_shorten: False
```

Then, have your commands inherit from `"generic/custom_command"` instead of `"generic/command"`. The entity key can be whatever makes sense for your world; the principle applies regardless.

> Why does this work? Attributes like `can_shorten` are looked up hierarchically: if they are not defined on the individual command entity, their value is inherited from the parent. By setting `can_shorten: False` on the parent entity, all child commands will default to that unless they override it.

## Command methods

A command can define methods. We've already seen that `run` is called each time the command is executed by a player. Actually, there are several available methods:

| Method          | Arguments                  | Usage                                               |
| --------------- | -------------------------- | --------------------------------------------------- |
| `refine`        | Specific to the syntax     | Can be used to programmatically alter the syntax arguments before `run` is called. |
| `run`           | Specific to the syntax     | Executed when the command is called by a player, after its arguments have been refined. **Mandatory.** |
| `refine_error`  | The arguments as a string  | Called if `refine` cannot be completed or encounters an error. |
| `parse_error`   | The arguments as a string  | Called when parsing the command arguments fails for some reason. |

Except for `run`, these methods are optional. We'll discuss next the concepts of syntax, argument parsing, and refining.

## Syntax and argument parsing

Commands can accept arguments, typically written after the command name (or one of its aliases), separated by spaces. For instance, if the player enters:

> shout I did it!

The input after `shout` (`I did it!`) becomes the command arguments. As explained above, `shout` can be abbreviated by default, so `sh I did it!` works identically.

Pythelix allows you to define a simple but powerful syntax on every command via the `syntax` attribute. By default, this attribute is empty, meaning the command takes no arguments.

You can specify a syntax string following a simple syntax language. This defines the expected structure of arguments and how they will be passed to the command's methods.

In any case, `syntax` is a string attribute. From it, the command arguments are parsed and passed on to the `refine` (if defined) and `run` methods.

### Simple arguments

The simplest arguments are what was previously called "fill-in-the-blank." To avoid confusion with the word "argument" as used in method definitions, we'll call these **syntax variables** instead.

Recall our `shout` example:

> shout I did it!

Our shout command could accept any argument (one word, multiple words, anything). To express that the command accepts exactly one syntax variable, you enclose its name in angle brackets (`<>`). The name you choose here becomes the variable name available in `refine` and `run`.

For example, if we call the syntax variable `message`, the command's `syntax` would be:

```
syntax: "<message>"
```

Let's review the complete command:

```
[command/shout]
parent: "generic/command"
name: "shout"
syntax: "<message>"

{run}
client.send(f"You shout at top volume: {message}")
```

When a player enters:

    shout me too

The engine:

1. Separates the command name (`shout`) from the arguments (`me too`).
2. Checks the syntax, which specifies one syntax variable `message`.
3. Assigns all the arguments (`me too`) to the `message` variable.
4. Calls the `run` method like this:

```python
!command/shout!.run(message="me too")
```

If you send the above command, you'll see:

> You shout at top volume: me too

If you've defined the optional `refine` method, it will be called before `run` with the same variables, possibly modifying them before `run` receives them.

> **Why use `refine`?**

The `run` method executes the command. However, the static syntax cannot cover every use case. The `refine` method sits between parsing and execution, allowing you to:

1. Transform or update syntax variables.
2. Search for objects in locations (perform matching). This is not done automatically.
3. Handle complex situations that the syntax parser cannot express.

Let's see an example.

### Refining arguments

```
[command/shout]
parent: "generic/command"
name: "shout"
syntax: "<message>"

{refine}
message = message.upper()

{run}
client.send(f"You shout at top volume: {message}")
```

Here, we added a `refine` method that transforms the `message` variable to uppercase.

Sending:

    shout me too

Now results in:

> You shout at top volume: ME TOO

Here's why:

- The engine calls `refine` first with `message="me too"`.
- The `refine` method uppercases `message`.
- The modified `message` is passed on to `run`.
- `run` executes with `message="ME TOO"`.

Because `refine` is a method, it is not limited to static transformations and can perform any allowed operations in Pythello scripting ([see scripting docs](./scripting.md)).

### Keywords and symbols in arguments

What if you want a command that takes two syntax variables? For example, a `get` command that gets an object from a container.

At first glance, you might write:

```
<object> <container>
```

But if the player enters:

    get red apple fig tree

How does the parser know which words refer to the object and which to the container? It's ambiguous.

You need a separator, either a symbol or a keyword.

A symbol example:

    get red apple, fig tree

Using a comma as a delimiter.

More commonly in games, keywords are used for clarity. The keyword `from` is typical:

    get red apple from fig tree

To specify this in syntax, write the keywords plainly (no angle brackets):

```
<object> from <container>
```

Let's see the full command:

```
[command/get]
parent: "generic/command"
name: "get"
syntax: "<object> from <container>"

{run}
client.send(f"You'd like to take {object} from {container}.")
```

Typing:

    get red apple from fig tree

Produces:

> You'd like to take red apple from fig tree.

- `<object>` is a syntax variable capturing the first argument.
- `from` acts as a keyword separator.
- `<container>` captures everything after `from`.

> **What if the user omits `from` or some arguments?**

By default, a parse error occurs with a generic message. You can provide a more helpful message by overriding the `parse_error` method:

```
[command/get]
parent: "generic/command"
name: "get"
syntax: "<object> from <container>"

{run}
client.send(f"You'd like to take {object} from {container}.")

{parse_error}
client.send("Enter the object name, followed by FROM, followed by the container name.")
```

`parse_error` is called whenever argument parsing fails, allowing you to guide the player with a better message.

### Slightly different: using symbols instead of keywords

You can also use delimiters like commas as symbols in syntax:

```
syntax: "<object>, <container>"
```

The player would type:

    get red apple, fig tree

Which style you choose depends on your game, your preferences, and what players are used to.

### Numbers

Syntax variables can also be typed as numbers. Numbers differ from text syntax variables in two ways:

- They accept only a single "word".
- The word must be a valid number.

To indicate a number syntax variable, surround its name with `#` symbols:

```
#times#
```

For example, we can extend the `shout` command to take the number of times to shout and the message:

```
[command/shout]
parent: "generic/command"
name: "shout"
syntax: "#times# <message>"

{refine}
message = message.upper()

{run}
client.send(f"You shout {times} times at top volume: {message}")
```

Typing:

    shout 3 me too

Produces:

> You shout 3 times at top volume: ME TOO

Note `times` is a numeric syntax variable, while `message` is textual.

> **Wait, earlier you said two argument variables side by side cause ambiguity?**

Correct, but numbers are a special case: since numbers can only match a single word, the parser can differentiate whether the first word is a number or not. If parsing fails, `parse_error` is called.

### Optional branches

Sometimes, commands can accept optional parts. For example, with the `get` command, players might want to get something just from the ground, without specifying `from <container>` every time.

To define optional parts of syntax, enclose them in parentheses `()`.

Our original syntax:

```
<object> from <container>
```

Becomes:

```
<object> (from <container>)
```

This marks `from <container>` as optional.

So both

    get red apple

and

    get red apple from fig tree

are valid.

> **What happens if the optional argument is omitted? What about the variable `container`?**

If the player does not specify `from <container>`, the `container` variable does not exist by default in `run`. You can handle this by specifying default values in your method signature.

Here's an example:

```
[command/get]
parent: "generic/command"
name: "get"
syntax: "<object> (from <container>)"

{run(client, object, container=None)}
if container:
  client.send(f"You'd like to take {object} from {container}.")
else:
  client.send(f"You'd like to take {object} from the ground.")
endif
```

- We explicitly declare the `run` method arguments.
- `client` is the client object (used to send messages).
- `object` corresponds to the `<object>` syntax variable.
- `container` corresponds to `<container>`. It has a default value `None`, so if omitted by the player, the variable exists but is `None`.

Examples:

    get red apple

Shows:

> You'd like to take red apple from the ground.

    get red apple from fig tree

Shows:

> You'd like to take red apple from fig tree.

You could also set the default value in `refine` by creating the variable there if missing. Both approaches are valid; choose one based on your needs.

> **Note:** This works well because the optional branch starts with a keyword (`from`). However, if you have two adjacent argument variables (one optional and one mandatory), the parser cannot disambiguate without a keyword or a symbol. The engine does not guess or do any "magic" of this sort.

## Pausing in the Middle of Commands

It is fairly common to want to pause during the execution of the `run` method. For example, you might want to begin an action, wait a minute, then provide feedback to the user. Pythelix is structured so that:

- A pause does **not** block commands entered by this client or others.
- However, no two commands run simultaneously.

In other words, all commands (scripts, task executions, and so on) are queued and run one at a time. This is always true. Therefore, if you were to "freeze" the entire server for 5 seconds within your command, then no one would be able to do anything else during those 5 seconds—not ideal.

On the other hand, pauses introduce some other considerations:

- You can easily wait while a script is running. But others can send commands while the script is paused, which means the game state after the pause might differ from the one before it.
- This includes the same player: they can send commands while the script is paused and might even run the same command, potentially causing nested pauses. In general, it's best to avoid such duplications.

Usually, we want to do something once, wait for a pause, then allow it to happen again.

The syntax is quite simple. For instance:

```
{run(client)}
client.msg("Before the pause")
wait 5  # Wait 5 seconds
client.msg("After these five seconds")
```

This example looks straightforward: you send a message, wait 5 seconds, then send another message. But consider:

- During the pause, the client might move on to another menu or action.
- The client might disconnect during the pause; this will not cause a crash.
- The server might restart during the pause; the task will resume when the server is back online, though the client may no longer exist. Again, this will not cause an error.

You cannot prevent the client from disconnecting, nor can you prevent server restarts (although that is your responsibility). In other words, you should avoid giving important information **after** these five seconds if it is vital for the next connection, since it might not happen.

You specify the pause in seconds after the keyword `wait`. It can be a variable, an integer, or a float. It can appear inside loops if needed—it's just a language construct.

**WARNING**: You can use the `wait` keyword in any script. However, commands require immediate information, so you should **not** use `wait` inside the `parse` or `refine` methods of a command. If you do, the first part of the method will run, then the engine will gather data from it, and the next part will execute much later (after `run` has been executed too). Avoid using `wait` anywhere except in `run`.

> The rest of this section is not yet implemented and refers to features that are approved but still need some work. These paragraphs may still be useful to describe the project's potential.

You can also specify an interval with `min..max`. For example:

```
{run(client)}
client.msg("Before the pause")
wait 2..4
client.msg("After this pause")
```

The pause will be between 2 and 4 seconds—not only 2, 3, or 4 seconds, but also any time in between, making the duration somewhat random. This is a "nice to have" feature, providing a shortcut to create semi-random pauses.

## Why aren't commands plain methods?

If you're familiar with LambdaMOO, you might know that commands can just be verbs defined on objects. Pythelix could theoretically work similarly: commands would just be methods on entities.

However, Pythelix chooses a different design because:

- Finding the method to execute would require searching many candidates, complicating the engine.
- Commands defined across objects make it harder to create a central help system.
- Players might invoke commands in wrong contexts and receive unhelpful errors such as "I don't understand" or "hu?".
- Conflicts could arise if the same verb is defined on multiple objects.

Centralizing commands as virtual entities offers clear advantages:

- Commands are in one place, simplifying management and help generation.
- Parsing, argument handling, and error reporting are consistent.
- Conflicts are minimized.
- Commands can still call methods (verbs) on matched objects.

This design choice enhances clarity and maintainability without limiting your ability to build rich interactions.

This covers the basics of creating and handling commands in Pythelix, including attributes, methods, syntax, argument parsing, and refinements. For more detailed scripting, see the [scripting documentation](./scripting.md). You might also want to check the [documentation on methods](./methods.md) which explains in greater details the concept of method signature and default arguments.
