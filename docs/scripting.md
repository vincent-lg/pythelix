In Pythelix, almost everything can be scripted. A script is a description of what happens at a given time:

- What happens when a new client connects to the server?
- What happens when a player picks up an object?
- What happens when a player takes an exit, and are they even allowed to?
- What happens at 9 AM every day in this room?

And much more; but you probably get the idea. A script describes behavior (the *what*) and is usually tied to an event (the *when*).

> If you have been more of a writer than a developer, note that in this documentation a script is used in the *developer* sense.

Pythelix provides its own scripting language, called *Pythello*. It is somewhat close to Python in terms of syntax, but there are differences.

## Where do scripts live?

Most scripts live in [entities](./entities.md). More specifically, they're usually written as [methods](./methods.md). If you are familiar with Object-Oriented terminology, a method should be self-explanatory: some code linked to a class (an entity, in our case). If you're not familiar, for now, think of a method as:

- Sitting on an entity. An entity can have (and usually has) several methods;
- Named uniquely per entity. No two methods on the same entity can share the same name.

This might all sound abstract, so let's see an example you can paste into your [worldlet](./worldlets.md) file:

```
[command/shout]
parent: "generic/command"
name: "shout"
syntax: "<message>"

{run}
client.msg(f"You shout at top volume: {message}")
```

Here's our first method! But let's first look at the entity definition:

- `[command/shout]`: this starts a new entity with the unique key `command/shout` in our [worldlet file](./worldlets.md). The following lines describe it until the next entity definition;
- `parent: "generic/command"`: sets the entity's parent as `generic/command`, marking it as a command (otherwise, it would be a different kind of entity);
- `name: "shout"`: commands have a name;
- `syntax: "<message>"`: all commands should have a syntax. When the user enters `shout`, they should specify the message to shout. The syntax can be quite extensive—refer to [the documentation about commands](./commands.md) for details.

Next is our first method. It's called `run`. Everything that follows is considered the method's script until the next method (starting with a `{`), the next entity definition, or the end of the file.

Our script looks like this:

```
client.msg(f"You shout at top volume: {message}")
```

If you're familiar with Python, this should look simple. We call the `msg` method on the client to send a message. This message is an f-string: portions between braces will be evaluated at runtime. Here, we insert the content of `message` directly into our text.

So if you save this file and apply the worldlet (or start the server), you can connect, enter:

    shout something

and you should receive:

    You shout at top volume: something!

That was likely your first command in Pythelix! Don't feel too proud yet—many more will come.

> This might look like Python, but it's not. It's not meant to be. There are important differences we will cover next. This language is meant to be easy to write, not a full Python interpreter.

Let's recap what we've done:

- We've created an entity with the key `command/shout`;
- It has the parent `generic/command`. In Object-Oriented terms, it inherits from `generic/command`, making it a command (not its key);
- It has a name and a syntax describing how to call the command. It can also have aliases, a help file, and many other attributes;
- It has a single method called `run`. When we enter the command, the `run` method is executed. You don't need to do anything else at this point.

## What can I do in a script?

Virtually anything—within reason—that you need in your game. Most things in the game are tied to scripts, which gives Pythelix a huge advantage in terms of flexibility. You already saw this aspect with commands. Most things are as easy to set up.

That said, this answer might feel vague. With great flexibility comes a learning curve. We've tried hard to make it as friendly as possible.

On one hand:

1. If you want to do something specific and have some programming experience, go ahead and try it. There’s an interpreter (see below) to help you check your code;
2. If you have goals but no programming experience, do not despair. Experience will come, little by little.

Now is a good time to reach for the [tutorials](./tutorials/index.md) about doing specific tasks. If you're new to programming, just find one you like and read through it. We take it slowly, so with time, you'll understand the syntax intuitively and won't need much help.

If you'd like to practice or see what happens when you type lines of script, read the next section before heading to a tutorial.

## A scripting playground

If you're new to programming—or have some Python experience—you might want to check the playground: it is a console where you can type Pythello scripts and see them in action. Very useful to check syntax before writing your worldlet, for instance.

To start it:

1. First start the server: if you have a binary version, click `bin/server.bat` (Windows) or start `bin/server` (other OSes). If running from source, it is best to use `dev.bat` or `./dev` to start the development server.
2. Connect the console: while the server is running, start the console. For a binary version, execute `bin/script.bat` or `./bin/script`. This will attempt to connect to the server. If running from source, enter `mix script` while the server is still running.

If all goes well, after a short wait (it might need some time to compile—don’t worry, it won’t happen next time), you should see:

```
Starting interactive script. Press CTRL+C twice to exit.
>>>
```

Here you can type your scripting instructions. Don’t type the `>>>` prompt; it indicates you can enter your code:

```
>>> value = 22
>>> f"value is {value}, while value times two would be {value * 2}"
"value is 22, while value times two would be 44"
>>> value += 36
>>> value
58
>>> lst = [1, 2, 3, value]
>>> lst
[1, 2, 3, 58]
>>>
```

And that's not all. Assuming you noticed that client number 3 connected (clients are stored as `client/{number}` keys, so `client/3` is your client's key), you can do:

```
>>> client = get_entity(key="client/3")
>>> client.msg("I see you!")
```

As expected, the client would receive your message.

In fact, you can use a short form here. Retrieving an entity by its key is so common there’s a syntax to do it quickly. You can replace:

```python
get_entity(key="client/3")
```

with:

```python
!client/3!
```

Simply surround the entity key with exclamation points. It works the same:

```
>>> client = !client/3!
>>> client.msg("I see you!")
>>>
```

Or even in a single line:

```
>>> !client/3!.msg("I see you!")
```

Admittedly, the single line can be a little tangled, but it's just to show how flexible the language truly is.

To close this console, press CTRL+C twice—as with any normal Elixir process (it might be three times on Windows).

Want more? If you already have programming experience, keep reading. If not, it's advised to look at the [tutorials](./tutorials/index.md).

## Pythello syntax

This is not a full tutorial, but a quick summary with mostly code examples.

### Strings, numbers, variables, lists—identical to Python

```
>>> True
True
>>> 52
52
>>> 3.7
3.7
>>> "a string"
"a string"
>>> 'a string with tics'
"a string with tics"
>>> """
... a string
... on several
... lines
... """
"a string\non several\nlines"
>>> i = 0
>>> f"i = {i}"
"i = 0"
>>> (3 + 5) * 2
14
>>>
```

### Conditions

Like in Python but terminated with the keyword `endif`:

```
>>> i = 0
>>> if i <= 0:
...   do_something()
... endif
```

`if` and `else` can be used as usual. Indentation within these blocks doesn't matter, but you must provide an `endif` at the end.

> Python uses indentation to determine blocks. In Pythello, explicit end blocks are used since Pythello can sometimes be executed inside your MUD client, where typing true indentation might be complicated.

### Loops

Like Python, Pythello provides two loops: `for` and `while`.

Example `for` loop:

```
l = [1, 2, 3]
for e in l:
    # do something with e
done
```

Example `while` loop:

```
i = 0
while i < 1000:
    i += 1
done
```

As with conditions, loops must be terminated with `done`. Indentation within loops doesn't matter.

### Subtleties

A few things to keep in mind:

- Every block must be closed with a matching keyword (`endif` or `done`).
- Indentation has no impact on code structure.
- Pythello does not aim to support every Python syntax. Python is an advanced language supporting many features. While Pythello tries to reproduce the Python experience, it is not a Python interpreter and will never be one. If you notice a syntax you think Pythello should support, feel free to reach out. But note that adding complexity adds overhead, so it might not be accepted.
- F-strings are evaluated at runtime, but *later* than where they're defined. This is so that f-strings including other players can be replaced with proper messages describing them, even if the f-string is sent to everyone in the location, for example. This is a specialized behavior and should not affect most builders. Remember, when you write code like `text = f"..."`, it will not evaluate immediately; the formatted string is stored, and the client evaluates it when it receives it.

## Scripting and entities

As pointed out earlier, entities are first-class citizens in Pythelix—and they're easy to manipulate in Pythello too. There's a function called `Entity` (with a capital E) to create them, and a function `get_entity` to retrieve them, with a shorthand syntax as seen before.

What about entity attributes? An entity can have two things: methods (behavior) and attributes (data). Reading and writing attributes is extremely simple:

```python
>>> nova = Entity()
>>> nova
Entity(id=7)
>>> nova.id
7
>>> nova.size = 58
>>> nova.size
58
>>> nova.size * 2
116
>>>
```

We've created an entity and stored it in the variable `nova`. We displayed it, showing its ID (7). We then wrote an attribute—just by assigning `nova.size = 58`—and read it back, multiplying it by 2.

Worth noting: this small snippet created and saved an entity in the database. Notice its ID (7). It's saved persistently—you can stop your server, restart it, and it will still be there. Assigning attributes saves to the database immediately.

Don't believe it? Note the entity's ID is 7 in the example (yours may differ). Shut down the server, restart it, and start the Pythello console again:

```
>>> old_nova = get_entity(7)
>>> old_nova
Entity(id=7)
>>> old_nova.size
58
```

Let's do something more interesting:

```
>>> old_nova.points = [1, 2, 8]
>>> old_nova.points.append(135)
>>>
```

Restart the server and start a console again:

```
>>> very_old_nova = Entity(7)
>>> very_old_nova.points
[1, 2, 8, 135]
>>>
```

We defined a list attribute on the entity, then appended a number to it. Amazingly, this change is saved to the database too.

Working with entities in scripts is straightforward.

### Parent and child entities

```
>>> mother = Entity(key="mother")
>>> boy = Entity(key="boy", parent=mother)
>>> mother.number = 21
>>> boy.number
21
>>>
```

Now, something interesting: entities can have parents, like our `command/shout` entity inherited from `generic/command`.

Here, we create an entity with key `mother`. Then we create a child entity with key `boy`, specifying its parent as `mother`.

We assign an attribute `number` to the parent, and the child inherits this attribute since it doesn't have its own value.

This is inheritance in Pythelix: if a child entity doesn't define an attribute, it inherits the parent's attribute value. The child can override the attribute independently, without affecting the parent.

The same applies to methods: unless the child defines a method of the same name, the parent's method will be used.

You can change an entity's parent by assigning to the `parent` attribute:

```
>>> boy.parent = some_other_entity
```

Or break the parent relationship entirely:

```
>>> boy.parent = None
```

### Location and contained entities

Entities can also be contained inside others. This does not affect attributes or methods.

Why is this useful? Players entering a room will:

- Leave the previous room;
- Be placed inside the new room.

Similarly, if a player drops an object:

- The object is removed from the player's inventory;
- The object is placed in the room.

Objects and players move often; rooms less so. Rooms might not be inside anything, or they may be inside zones or vehicles, depending on your design.

Here's an example:

```
>>> room = Entity(key="room/demo")
>>> player = Entity(key="player/kredh", location=room)
>>> player.location
Entity(key="room/demo")
```

You can look at the room's contents:

```
>>> room.contents
[Entity(key="player/kredh")]
>>>
```

`contents` is a list since an entity can contain multiple entities. You *cannot* append directly to this list; to move an entity, change its `location` attribute:

```
>>> player.location = new_room
```

Or, if an entity with key `room/demo2` exists:

```
>>> player.location = !room/demo2!
```

To place the player nowhere:

```
>>> player.location = None
```

### Calling entity methods

This topic is discussed at length in the [methods documentation](./methods.md).

### Deleting attributes and entities

Like in Python, you can use the `del` keyword to remove entity attributes or entities themselves. Be careful with this keyword:

```
>>> del entity.attribute_name
>>> del entity
```

The second instruction removes the entity from the database, so be sure you want to delete it.

> You cannot remove entity methods with `del`.
