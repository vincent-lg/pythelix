---
title: Commands in Pythelix
---

It's easy to create commands in Pythelix. It's even easier to keep track of which commands are available and to provide a robust help system that doesn't leave anything out.

## Prerequisites

This documentation assumes you have read the [getting started documentation](./start.md).

## Commands are entities

In Pythelix, most things are [entities](./entities.md), and commands are no exception. They are **virtual entities**, meaning they are not stored in the database.

Virtual entities are created when applying a [worldlet](./worldlets.md) as usual, but they will not be stored. If you want to remove a command, simply remove it from the worldlet and reapply it.

You could create a command in Pythelix by writing something like this in a worldlet file:

```
!command/shout!
parent = "generic/char_command"
name = "shout"

def run(character):
    client.msg("NOT SO LOUD!")
```

1. Like any entity, a command should have a unique key. The exact value doesn't matter much, but it should be unique.
2. The `parent` attribute is critical here: this entity inherits from `"generic/char_command"`. The `"generic/char_command"` virtual entity is parent to all character commands.
3. The `name` attribute contains the command's name, a string the players will type to invoke this command.
4. The command defines a single method, `run`, which is called whenever the command is used by a player.

If a player connects to your MUD and types `shout` or `shout something`, they will receive the message:

> NOT SO LOUD!

Of course, commands can be much more powerful than that (and usually are), but it's important to connect these dots:

- You create a virtual entity with a parent of `"generic/char_command"` or similar (see below).
- When a player enters the command name (or a valid abbreviation of it), followed optionally by a space and arguments, the command's `run` method is executed.
- You can use all the power of Pythello, the [scripting language](./scripting.md), to make the command behave however you want.

Now for the finer points.

## Command parents

In reality, Pythelix automatically creates one (and only one) command entity: `"generic/command"`. All commands should inherit (directly or not) from it.

> Then, why did we use `"generic/char_command"`?

In your default worldlet, you have a few different sub-types of commands. If you open the "worldlets/command.txt" file, at the very top, you should see:

```
!generic/char_command!
parent = "generic/command"

!generic/player_command!
parent = "generic/command"

def can_run(self, character):
    return "player" in character.permissions

!generic/admin_command!
parent = "generic/command"

def can_run(self, character):
    return "admin" in character.permissions
```

You have three new entities:

- `"generic/char_command"`: all commands executed by a character (including a player character or a NPC, Non-Playing Character);
- `"generic/player_command"`: all commands that are accessible only to players (not NPCs). Example: the "quit" command (it wouldn't make sense for NPCs to quit);
- `"generic/admin_command"`: commands that can only be run by administrators, not any player.

So we have three other entities. And most commands use one of these as parent. Since their own parent is `"generic/command"`, they're still commands.

> So if I use `"generic/admin_command"` as parent of a command, it will not be accessible to any player... but why have `"generic/char_command"` at all and not use `"generic/command"` directly for all other commands?

Commands don't only run in the game after a character has connected. They can also run on bare clients (during login). For instance, when you connect to the MUD and enter `"new"` to create a new user, that's a command — but no character exists yet, so the command runs on the client (the connection) rather than on a character. To maintain this distinction, we use `"generic/char_command"` for commands that require a character and `"generic/command"` for commands that don't. All character commands assume a character runs them (after login). A generic command has no assumption and is usually preferred for commands run by clients.

> Why isn't Pythelix creating these entities automatically then?

Pythelix makes as few assumptions about your game as possible. Perhaps you want a completely different permission system. Perhaps you don't even want characters. Perhaps you want commands to be run by vehicles and the game to connect to these instead. So only `"generic/command"` is actually defined by Pythelix. The rest can be changed however you want.

Also notice that we don't just define three entities — two of them also override the `can_run` method. This method checks that the character can indeed run the command. We check for `character.permissions`, which is set on all characters. You can see it in `worldlets/character.txt`.

## Command attributes

| Attribute     | Type            | Description |
| ------------- | --------------- | ----------- |
| `parent`      | String          | The parent entity of the command. Always `"generic/command"` or another entity inheriting from it. |
| `name`        | String          | The command's name. **Mandatory**. |
| `can_shorten` | Boolean         | Defaults to `True`. If `True`, abbreviated forms of the command name are accepted. For example, if the command name is `shout`, entering `shou` or even `sh` will match the command. Often desirable, but can be turned off for individual commands or groups (see below). |
| `syntax`      | String          | The syntax describing the command's arguments. By default, a command has no arguments. See the dedicated section below. |
| `aliases`     | List of strings | Optional list of alternative names for the command. Example: `aliases = ["st", "stat"]` to reach a `status` command. Note that since command names can generally be abbreviated, aliases are less often needed. |

`"char_command"` also provides the attributes `category` (the command category name) and `help` (the command help text) but these are actually dependent on the way you set up your game. You might want a different help system. This is just a default.

> **Tip:** Want to disable command abbreviations globally without repeating `can_shorten = False` in every command? Easy. You could add the attribute to the `"generic/char_command"` in your worldlet file. For instance, modify in your `worldlets/command.txt` the `"generic/char_command"` entry:

```
!generic/char_command!
parent = "generic/command"
can_shorten = False
```

> Why does this work?

Attributes like `can_shorten` are looked up hierarchically: if they are not defined on the individual command entity, their value is inherited from the parent. By setting `can_shorten = False` on the parent entity, all child commands will default to that unless they override it individually.

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

Sounds abstract? Don't worry, we'll see different examples, one step at a time, to illustrate how to handle arguments.

### Simple arguments

The simplest arguments are what was previously called "fill-in-the-blank." To avoid confusion with the word "argument" as used in method definitions, we'll call these **syntax variables** instead.

Recall our `shout` example:

> shout I did it!

Our shout command could accept any argument (one word, multiple words, anything). To express that the command accepts exactly one syntax variable, you enclose its name in angle brackets (`<>`). The name you choose here becomes the variable name available in `refine` and `run`.

For example, if we call the syntax variable `message`, the command's `syntax` would be:

```
syntax = "<message>"
```

Let's review the complete command:

```
!command/shout!
parent = "generic/char_command"
name = "shout"
syntax = "<message>"

def run(character, message):
    character.msg(f"You shout at top volume: {message}")
```

Save the worldlet, apply it as usual.

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

    You shout at top volume: me too

If you've defined the optional `refine` method, it will be called before `run` with the same variables, possibly modifying them before `run` receives them.

> **Why use `refine`?**

The `run` method executes the command. However, the static syntax cannot cover every use case. The `refine` method sits between parsing and execution, allowing you to:

1. Transform or update syntax variables.
2. Search for objects in locations (perform matching). This is not done automatically.
3. Handle complex situations that the syntax parser cannot express.

Let's see an example.

### Refining arguments

```
!command/shout!
parent = "generic/char_command"
name = "shout"
syntax = "<message>"

def refine(character, message):
    message = message.upper()

def run(character, message):
    character.msg(f"You shout at top volume: {message}")
```

Here, we added a `refine` method that transforms the `message` variable to uppercase.

Sending:

    shout me too

Now results in:

    You shout at top volume: ME TOO

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
!command/get!
parent = "generic/char_command"
name = "get"
syntax = "<object> from <container>"

def run(character, object, container):
    character.msg(f"You'd like to take {object} from {container}.")
```

Typing:

    get red apple from fig tree

Produces:

    You'd like to take red apple from fig tree.

- `<object>` is a syntax variable capturing the first argument.
- `from` acts as a keyword separator.
- `<container>` captures everything after `from`.

> **What if the user omits `from` or some arguments?**

By default, a parse error occurs with a generic message. You can provide a more helpful message by overriding the `parse_error` method:

```
!command/get!
parent = "generic/char_command"
name = "get"
syntax = "<object> from <container>"

def run(character, object, container):
    character.msg(f"You'd like to take {object} from {container}.")

def parse_error(character):
    character.msg("Enter the object name, followed by FROM, followed by the container name.")
```

`parse_error` is called whenever argument parsing fails, allowing you to guide the player with a better message.

### Slightly different: using symbols instead of keywords

You can also use delimiters like commas as symbols in syntax:

```
syntax = "<object>, <container>"
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
!command/shout!
parent = "generic/char_command"
name = "shout"
syntax = "#times# <message>"

def refine(character, times, message):
    message = message.upper()

def run(character, times, message):
    character.msg(f"You shout {times} times at top volume: {message}")
    character.msg(f"... or, rather: {times * message}")
```

Typing:

    shout 3 ok

Produces:

    You shout 3 times at top volume: OK
    ... or, rather: OKOKOK

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
!command/get!
parent = "generic/char_command"
name = "get"
syntax = "<object> (from <container>)"

def run(character, object, container=None):
    if container:
        character.msg(f"You'd like to take {object} from {container}.")
    else:
        character.msg(f"You'd like to take {object} from the ground.")
    endif
```

- We explicitly declare the `run` method arguments.
- `character` is the character object (used to send messages).
- `object` corresponds to the `<object>` syntax variable.
- `container` corresponds to `<container>`. It has a default value `None`, so if omitted by the player, the variable exists but is `None`.

Examples:

    get red apple

Shows:

    You'd like to take red apple from the ground.

And:

    get red apple from fig tree

Shows:

    You'd like to take red apple from fig tree.

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
def run(character):
    character.msg("Before the pause")
    wait 5  # Wait 5 seconds
    character.msg("After these five seconds")
```

This example looks straightforward: you send a message, wait 5 seconds, then send another message. But consider:

- During the pause, the client might move on to another menu or action. Including typing another command.
- The client might disconnect during the pause; this will not cause a crash.
- The server might restart during the pause; the task will resume when the server is back online, though the client may no longer exist. Again, this will not cause an error.

You cannot prevent the client from disconnecting, nor can you prevent server restarts (although that is your responsibility). In other words, you should avoid giving important information **after** these five seconds if it is vital for the next connection, since it might not happen.

You specify the pause in seconds after the keyword `wait`. It can be a variable, an integer, or a float. It can appear inside loops if needed—it's just a language construct.

You can also specify a duration, which might be easier to read:

```
def run(character):
    character.msg("Before the pause")
    wait 5m
    client.msg("After five whole minutes")
```

Using a duration (with a number followed by a unit (`s` for seconds, `m` for minutes, etc) might be easier to read.

## Asking the character for details

Some commands might ask a user for additional information. The most common scenario is a confirmation: "Are you sure you want to proceed? Enter 'yes' or 'no'.".

This kind of thing can be handled with the builtin `ask` or `choice` functions.

`ask` simply asks the user for information:

    name = ask(character, "What is your name again then?")
    # Do whatever with the name command

For instance, a command that asks for the character's eye color can be written like this:

```
!command/eye!
parent = "generic/char_command"
category = "General"
name = "eye"

def run(character):
    color = ask(character, "What is your character's eye color?")
    character.msg(f"You have chosen the eye color: {color}.")
```

You can save and apply the worldlet as usual. In your MUD client, if you enter `eye`, you should see:

    What is your character's eye color?

And you can type `blue` for instance and get the message:

    You have chosen the eye color: blue.

> Can other players enter commands in between?

Yes, fortunately. This is not blocking. It's just blocking the current player, waiting for input. But others can execute commands, including being asked to provide information of their own.

> What happens if the player disconnects before giving their eye color?

Then, they will be asked about it upon reconnecting (when they have entered their username and password). The same would be true if the server stops and starts again. Input prompts are saved like paused tasks.

> What prevents the player from writing an invalid color?

Nothing. This is a free-form type of question. What you could potentially do is `ask` in a loop until the answer looks good to you.

But the `choice` function might be easier to use here. It assumes only some answers are valid.

You have to specify which answer. Let's see a simple example:

```
!command/eye!
parent = "generic/char_command"
category = "General"
name = "eye"
syntax = "<color>"

def run(character, color):
    choices = {"yes": True, "no": False}
    prompt = f"You have chosen the {color} color. Are you sure?"
    retry = "Enter 'yes' or 'no'"

    if choice(character, choices, prompt=prompt, retry=retry):
        character.msg("Well, if you're sure, let's save your choice.")
    else:
        character.msg("Aborted.")
    endif
```

First, notice the `choices` dictionary: it contains choices as keys (just strings) and anything as value (in this case, a boolean, either `True` or `False`). This set of choices just means: if the character enters `yes`, then return `True`, if they enter `no`, then return `False`. save and apply. You can then try the command:

    > eye blue

And you should see:

    You have chosen the blue color. Are you sure?

If you type `yes`, you should see:

    Well, if you're sure, let's save your choice.

If you type `no`, you should see:

    Aborted.

And if you type anything else, like `I'm not sure`, you should see:

    Enter 'yes' or 'no'

And you have to try again. One more time, if the client disconnects and then reconnects, they will be asked for the same information.

Another example with eye color? Let's say you want to offer a limited list of choices. The code is slightly more involved but not too much:

```
!command/eye!
parent = "generic/char_command"
category = "General"
name = "eye"

def run(character):
    colors = ("blue", "green", "brown", "orange", "black", "white")
    choices = {}
    prompt = "Enter the eye color as a number:"
    i = 1

    for color in colors:
        choices[str(i)] = color
        prompt += f"\n  {i} for {color}"
        i += 1
    done

    prompt += f"\nEnter a number between 1 and {len(colors)}:"
    retry = "Enter a valid number."
    color = choice(character, choices, prompt=prompt, retry=retry)
    character.msg(f"You have chosen the eye color {color}.")
```

If you enter `eye` with no argument you should see:

    Enter the eye color as a number:
      1 for blue
      2 for green
      3 for brown
      4 for orange
      5 for black
      6 for white
    Enter a number between 1 and 6:

If you enter `4` for instance you will get:

    You have chosen the eye color orange.

And of course, if you enter anything else but a number from 1 to 6, you'll have to retry.

## Searching valid entities in a location

A lot of commands need to work on valid entities. Think of our `get` command: it extracts text, which is fine, but if it cannot find the entities that actually use this text as name, it's a bit complicated. Pythelix doesn't allow searching directly from the command parser, because a lot of things (like the origin of the search) are not often identical.

The fact remains: we want to have a get command with `<object>` as syntax that looks for the right entity. If the user enters `get red apple`, we don't want the text `red apple`, we want the entity of this name.

Matching, or searching for an entity given a name, is usually done in three steps:

1. First we extract the argument as text, as we did before.
2. The `refine` method searches for the entity (or entities) that have this name.
3. The `run` method decides what to do with these entities.

Matching is a complex topic. Since games will usually behave very differently, Pythelix tries to avoid assuming anything regarding matching. It offers generic features that can usually be extended to fit your game.

But let's see a basic example. To do a `get` command that gets an object from the ground (you can enter `get red apple` if there's an apple on the ground), the worldlet looks like this:

```
!command/get!
parent = "generic/char_command"
name = "get"
category = "General"
syntax = "<object>"

def refine(character, object):
    to_pick = search.match(character.location, object, viewer=character)

def run(character, to_pick):
    # Change object location
    for item in to_pick:
        item.location = character
    done

    # Display object names
    for name in names.group(to_pick, viewer=character):
        character.msg(f"You pick up {name}.")
    done
```

In summary:

- The `syntax` attribute contains the object name;
- The `refine` method uses `search.match` to find entities with the proper name (in the character location, presumably a room);
- The `run` method runs two loops: one for placing all objects' location from the room to the character (placing in inventory), the second for displaying the object names (we use `names.group` to properly handle plural names).

As said, matching is a complex topic and this is just an overview. To learn more, read the [documentation about matching](./match.md).

## Command FAQ

- <details markdown="1">
  <summary>Why aren't commands plain methods?</summary>

  If you're familiar with LambdaMOO, you might know that commands can just be verbs defined on objects. Pythelix could theoretically work similarly: commands would just be methods on entities.

  However, Pythelix chooses a different design because:

  - Finding the method to execute would require searching many candidates, complicating the engine.
  - Commands defined across objects make it harder to create a central help system.
  - Players might invoke commands in wrong contexts and receive unhelpful errors such as "I don't understand" or "huh?".
  - Conflicts could arise if the same verb is defined on multiple entities.

  Centralizing commands as virtual entities offers clear advantages:

  - Commands are in one place, simplifying management and help generation.
  - Parsing, argument handling, and error reporting are consistent.
  - Conflicts are minimized.
  - Commands can still call methods (verbs) on matched objects.

  This design choice enhances clarity and maintainability without limiting your ability to build rich interactions.

  </details>

This covers the basics of creating and handling commands in Pythelix, including attributes, methods, syntax, argument parsing, and refinements. For more detailed scripting, see the [scripting documentation](./scripting.md). You might also want to check the [documentation on methods](./methods.md) which explains in greater details the concept of method signature and default arguments.
