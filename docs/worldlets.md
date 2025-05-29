Worldlets are files stored on the server that contain definitions of your game world. You are free to use them exclusively, rely on a more traditional game-building approach with commands, or even combine both methods.

## What are worldlets?

A worldlet is simply a text file on the server. This file contains instructions to create or update parts of the world.

This feature may seem simple, but the key point is "create and update". For example, if the file contains the definition for a room that already exists, the existing room in the world is updated according to the file. This allows you to apply and reapply the same files and see the world evolve (without duplication).

> Why is this useful?

Suppose you've created several rooms but repeatedly made the same spelling mistake in their descriptions. Normally, you'd have to manually update the description in each room—assuming you have an efficient way to edit them—one by one, which can be time-consuming.

If your rooms are defined in worldlets, you only need to open the relevant files in your favorite editor, perform a "find and replace" (most editors support this across multiple files), then save and apply the worldlets. Voilà!

## Planning ahead in world building

It's tempting, when you find a great game engine (hopefully Pythelix!), to immediately start building a game full of rooms, NPCs, vehicles, spells, spaceships, dancing fluffies, and more. However, if you intend to manage a game with builders, it’s important to plan ahead.

How would builders contribute? Traditionally, the answer was straightforward: give them a builder role (or the necessary permissions), train them on building commands, and hope they use them effectively. This isn't a bad approach, but other workflows exist.

You might decide never to share building commands directly. Instead, share individual worldlets (one or two files) with each builder. Each builder manages their assigned worldlet, builds and tests on their own computer, and then sends the completed worldlet to you, the administrator, for review and application. This way, they only access what you allow, and still can test their work.

If they encounter repeated mistakes (like spelling errors), they can correct them in their worldlet, resend it, and after your review, you can reapply it to fix the issues.

Additional possible workflows:

1. **Test server:** Maintain a test server accessible only to builders. They can push their worldlets here to check for conflicts. Once cleared, you push the worldlet to the main server. The test server is just a copy of the main server, with restricted access.
2. **Version control:** Use a system like Git to version your worldlets, allowing easy tracking of changes and avoiding redundant reviews. Builders can use this too, but may not always care about version history.
3. **Shared folder access:** If you trust your builders, you might give them access to a shared Dropbox folder or similar service where they can directly modify their worldlets, which are then automatically applied in the game. (Dropbox is one example, but there are many other solutions.)

These strategies illustrate how worldlets support collaboration.

> You don't have to use worldlets for everything!

Worldlets follow specific rules and are intended primarily for world deployment (think lore only, not the complete game). For example, player accounts are created in your database and should not be included in worldlets. They are not backups; they exist to simplify world deployment.

## Where to find worldlets and how to edit them?

Worldlets are located in the server code under the `worldlets` directory. This directory contains both subdirectories and `.txt` files. When the server starts, it reads every worldlet file in the directory and its subdirectories and applies them.

By default, the directory includes some example files:

- `commands.txt`: worldlet containing your commands. You can split this into multiple files if needed.
- `demo.txt`: a basic demonstration with rooms and characters.
- `base.txt`: basic creation of parent entities.

Your game world consists of [entities](./entities.md). An entity is a single piece of information (a room, item, character, vehicle, etc.). Entities can be practical or logical (e.g., a race, event, skill, or spell).

Here's an example from `demo.txt` (open `worldlets/demo.txt` in your favorite editor):

```
[bakery]
parent: "room"
title: "A bakery"
description: """
The warm, inviting scent of freshly baked bread and sweet pastries fills
the air upon entering this cozy little shop. A fine dusting of flour clings
lightly to the wooden floorboards and countertops. Shelves and display cases
brim with golden-baked goods—loaves of crusty bread, delicate pastries,
and confections in all shapes and sizes. Icing glistens under soft lighting,
while nuts, berries, and chocolate chips adorn many of the treats with artistic
precision. At the back of the shop, an antique wooden cash register rests
atop a counter, its brass details dulled slightly with age and use.
"""
```

Let's break it down:

- The entity key is between brackets at the top (`[bakery]` here). Each entity key is unique (defining an entity with an existing key updates it). Sometimes, using a path-like key such as `[room/demo/bakery]` helps avoid conflicts. Here, `room/demo/bakery` is the key and slashes act as path separators; you can use another separator as long as you're consistent.
- `parent: "room"` indicates that this entity has a parent with key `"room"` (defined elsewhere, e.g., `worldlets/base.txt`). To learn more, see the [entities documentation](./entities.md).
- `title: "A bakery"` sets the `title` attribute to `"A bakery"`. Note the quotation marks—they are needed because attribute values can be various types (text, numbers, lists, other entities, etc.).
- `description: """ ... """` uses triple quotes to define a multiline string as the value of the `description` attribute.

A single file can contain many entities (noted by multiple `[entity key]` declarations).

### Attributes in entities

To recap, the syntax for attributes is:

> `attribute_name: attribute_value`

- `attribute_name` should be a valid name (no spaces, use underscores if needed; it cannot start with a digit but can contain Unicode characters such as `é`).

Attribute values accept any value valid in [Pythello](./scripting.md), the scripting language. For example:

- `price: 300` — integer value 300
- `volume: 15.8` — floating-point number 15.8
- `title: "some title"` — string
- `tips: """ ... on multiple lines ... """` — multiline string (triple quotes on opening and closing lines):

  ```txt
  tips: """
  Some tip on multiple
  lines.
  """
  ```

- `friend: !room/demo/fruit_stand!` — reference to another entity with key `room/demo/fruit_stand`. The `!entity key!` syntax is a Pythello shortcut.
- `food: ["white bread", "cookie", "croissant"]` — a list of strings (can be multiline, but the opening bracket must be on the starting line)
- `info: {"price": 31, "weight": 72}` — a dictionary

and so on.

All valid scripting values (numbers, strings, lists, dictionaries, entities, function calls, operations, etc.) are valid attributes. Attributes are evaluated when the worldlet is applied, so be cautious with function calls. For example:

```
choice: random.randint(1, 6)
```

This will assign an integer between 1 and 6 to `choice`, but the value will reset each time the worldlet is reapplied, which may not be desired.

To learn more about value syntax, see the [scripting documentation](./scripting.md).

### Methods in entities

Entities can also have methods, representing behavior. If you've used LambdaMOO, methods are similar to verbs (while attributes map to properties). Note that Pythelix methods are strictly behavioral; unlike LambdaMOO verbs, they do not serve as commands.

An entity can have zero, one, or multiple methods.

Methods are more complex, so it's advisable to read the [methods documentation](./methods.md). In worldlets, methods look like this:

```
[entity_key]
attr1: value1
attr2: value2
...

{method_name}
code on
several
lines

{another_method}
Some
other
code
...
```

To define a method, specify its name between braces (e.g., `{greet}`), followed by the method's code on one or more lines. When Pythelix sees a line starting a new entity (`[another entity]`), starting a new method (`{another method}`), or end-of-file, and considers the method body complete, it adds the method to the entity.

Example:

```txt
[bakery]
parent: "room"
title: "A bakery"

{spill}
author.msg("You swipe the merchandise and throw it to the ground. How rude!")
author.announce(f"{author} swipes the merchandise and throws it to the ground. Really!")
```

This `spill` method sends a message to the action's author and announces it to the room (excluding the author).

Methods can have arguments, specified in parentheses after the method name:

```
{spill(author)}
```

Multiple arguments are also supported:

```
{roll_dice(min, max)}
```

Here, `roll_dice` takes two arguments, `min` and `max`. You can add type annotations (similar to Python) for argument types:

```
{roll_dice(min: int, max: int)}
```

Now, `min` and `max` are expected to be integers. If called with incorrect argument types, an error is raised or the call rejected.

Arguments can also be entities, with type hints:

```
{spill(author: Entity["player"])}
```

This means `spill` expects `author` to be an entity whose parent (or ancestor) key is `"player"`. This syntax resembles Python’s typing but is designed to avoid confusion.

Specifying type hints is strongly recommended. You can also specify a return type:

```txt
{roll_dice(min: int, max: int) -> str}
```

This method takes two integers and returns a string, aiding error detection.

Default argument values can be set with `=`:

```txt
{roll_dice(min: int = 1, max: int = 6) -> str}
```

Calling this method with no arguments uses defaults; you can override one or both arguments.

See [the methods documentation](./methods.md) for more details on syntax.

## Reapplying worldlets

As mentioned, all worldlets are applied automatically when the server starts. Often, though, you'd want to apply one or more worldlets without restarting.

This is easy: Pythelix provides the `apply` (or `apply.bat`) scripts for this purpose.

If running the binary version, look inside the `bin` directory for `apply` (Unix) and `apply.bat` (Windows). You can use these in the command line, specifying the file or directory to apply:

```sh
./apply path/to/file/or/directory
```

The path can point to a single `.txt` file or a directory (all worldlets inside will be applied). Upon success, the script reports how many entities were created or updated. If errors occur, Pythelix still tries to apply as many worldlets as possible.

You can also double-click on the script (or execute it with no argument). All worldlets will be applied.

If running from source, run:

```
mix apply path/to/worldlet
```

In both cases, the server must be running (`server` or `server.bat` for the binary, or `mix phx.server` from source). `apply` queues the task in the server. Worldlets are applied between commands, ensuring the game remains consistent during the process.

If you have started a Pythello console (with `script`, `script.bat` or `mix script`), you can also use the `apply` function. It's a builtin, so you can type in your console `apply()` to apply all worldlets (note the parenthesis).
