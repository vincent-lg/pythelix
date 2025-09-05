Building in Pythelix is designed to be easy, powerful, highly flexible... and fun whenever possible.

## When to use?

- If you're new to Pythelix entirely and want to begin your journey with building.
- If you have built in Pythelix before but have forgotten the various options you have.

## Requirements

- A fresh Pythelix installation. If you don't have one, you can head to [the installation guide](../../installing.md).

## Creating a game

You have ideas for a text-based game, and Pythelix, like most MUD engines, is here to help you bring them to life.

Let’s start small. Suppose you want to add a bakery to your world:

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
price: 30000
```

In Pythelix, this bakery is an entity: a single "thing" in your game world, with its own data (`title`, `description`, `price`) and behavior (what happens when a player interacts with it).

The block of text above is part of a worldlet: a file that defines one or more entities and their attributes or methods.

Think of it like this:

- Entity: the object in your game.
- Worldlet: the blueprint that creates or updates it.

In the next section, we’ll explore these two concepts in more detail and see how they shape everything you build in Pythelix.

## Working with Pythelix

There are two key concepts to understand about Pythelix that shape the building experience for everything (from commands to spells):

- In Pythelix, most things are [entities](../../entities.md): an entity is a "portion" of the game world (a room is an entity, as are objects, NPCs, accounts...).
- Entities are described in [worldlets](../../worldlets.md): worldlets are just text files containing a special syntax to add or update entities.

These concepts might seem vague at first, but we'll see many examples in this tutorial. For now, just remember: entities are small portions of your game (you might have a lot of them in a playable game) and worldlets are the files used to describe your entities.

### What are entities exactly?

Pythelix relies heavily on entities in its structure. An entity is simply a "portion" of your game world which can have data (attributes) and behavior (methods). Most things in Pythelix (including individual connections, commands, menus, characters, accounts, rooms...) are entities.

Let's take a simple example: a room in your game world. You probably have a lot of rooms. A single room is just an entity: it has data (its title, description, whether it's inside or outside, etc.) and behavior (for example, what happens when someone enters this room).

There are two types of entities:

- **Stored entities (or full entities):** These are stored in your database. They have a unique ID (a number). No two entities can share the same ID.
- **Virtual entities:** These are not stored in the database and do not have an ID.

> **Why are virtual entities useful?**

Some concepts do not need to be saved permanently: for example, it makes no sense to store individual connections, since these are lost after each session. Connections, commands, menus, etc., are virtual entities. They are still entities like most things but are not stored in the database. Commands, in particular, are described in your worldlet files: if you remove a command from the worldlet, it is removed from the game. Commands are not stored in the database.

What about rooms? Rooms are stored (or full) entities: they are stored in the database and have an ID.

To better understand how entities work in practice, let's examine what the `look` command does. This command is used by the player to see their surroundings. Typically, the player would enter "look" in their MUD client and receive the room's title and description.

For Pythelix, this happens as follows:

- `look` is a command, which is a virtual entity.
- When executed (by entering "look" in a MUD client), it calls one of its methods (this is the entity's behavior).
- This method locates the room (an entity) where the current player is.
- Once it has this entity, it retrieves the "title" and "description" attributes (these are data on the room entity).
- It then formats these attributes into a nice-looking response and sends it back to the client.

If you're still unsure about the nature of entities, read on. It might become clearer with an example... and for that, we'll turn to worldlets.

### What are worldlets?

A worldlet is just a text file on your computer (or server). It describes game entities. For instance, a worldlet defining a room could look like this:

```
[room/135]
parent: "generic/room"
title: "A splendid room"
description: "This room looks so beautiful, I cannot properly describe it."
```

This small piece of worldlet creates an entity (or updates it if it already exists). Three attributes are defined: `parent`, `title`, and `description`.

The `parent` attribute holds special meaning: if present, it refers to another entity whose attributes and methods will be inherited by this entity. Usually, entities have a parent (which can have its own parent, and so on). We'll see later why this offers powerful capabilities. For now, let's ignore this attribute.

The `title` and `description` attributes are more straightforward: they store the room's title and description.

In addition to attributes, we can define methods:

```
[room/135]
parent: "generic/room"
title: "A splendid room"
description: "This room looks so beautiful, I cannot properly describe it."

{look}
return [
    self.title,
    self.description,
]
```

Here, we have defined a `look` method on the room. It reads the `title` and `description` attributes and returns them as a list. Pythelix methods are scripts: their syntax resembles Python but has some differences. If you don't know Python or the previous examples seem hard to follow, don't worry too much.

To complete our example, we could add a command. This is also an entity, defined in a worldlet too (perhaps the same file):

```
[command/look]
parent: "generic/command"
name: "look"

{run(character)}
room = character.location
lines = room.look()
character.msg("\n".join(lines))
```

We've defined a new command. We specify its name in the `name` attribute. It has a `run` method (notice it takes the `character` as an argument). To get the room, it accesses the `location` attribute of the character. It then calls the `look` method on the room (which, as defined earlier, returns a list of strings) and sends the lines joined by newlines to the character's client via `character.msg()`.

That's the basic principle of entities: how they work, interact with one another, and define attributes and methods.

Let's return to worldlets: where are they defined?

If you have downloaded Pythelix from a binary version (for Linux or Windows), you will find a folder called "worldlets" in your installation directory (alongside "bin", "lib", or "releases"). If you run it from source, the "worldlets" directory will be inside the directory where you run `mix`.

Inside this folder, you should see other folders and text files (with the `.txt` extension): these are your worldlets. You can open them in your favorite text editor. Inside, you should see exactly the syntax we have seen above (often, several entities are defined within the same file).

That's the same syntax throughout: create or update an entity, add or update attributes, add or update methods. If you modify this file and start the game engine, the entity in question will be added or updated.

> **Why are worldlets useful?**

In most traditional game engines, you directly modify an entity in-game using commands to add/remove attributes, create new entities, or update methods. In Pythelix, the choice has been made to use worldlets instead: files that can be easily modified and applied. There are many advantages to this approach:

- Files can be applied repeatedly, and the entities within will just be updated.
- Builders can contribute to your game without having the whole list of worldlets; they can work on their zone files, for example.
- Fixing things like spelling errors is simple: just modify the file and apply it.

This structure offers a lot of potential for collaboration with minimal complexity.

> **And working from building commands? Can I still do that?**

Yes, you can... but you need to add these commands yourself. Pythelix doesn't assume anything about your game. So if you want to add a command, like `redit` to edit a room, you can do so, but that's your choice. You can definitely create these commands and give them to builders without sharing the worldlets at all.

> **If I use building commands, will the new entities appear in my worldlets too?**

Think of your worldlets like blueprints. Applying them updates the building. But if you change the building in-game, the blueprint doesn’t magically update: you’d have to edit it manually.

So no. Worldlets are not your "database." They are just a way to build. They won't contain everything (for example, individual accounts with their passwords are never defined in worldlets). If you use building commands, these commands won't affect your worldlets: meaning that you would add these commands to your worldlets, but builders using them won't add entities to those worldlets automatically. These are separate systems. They can work hand in hand, but it requires some planning by the administrator.

Another example: if a builder modifies an entity in game which is also defined in a worldlet... then the entity will be reset to whatever was defined in the worldlet. So be careful: building commands are not incompatible with worldlets, but using both at the same time can be risky.

Overall, there are few good reasons to avoid using worldlets with your builders. As mentioned, you can easily share only a small portion of a file and have them complete it. You can establish a review process to examine worldlets before integrating them into the game. You could set up a system where trusted builders have their worldlets applied automatically while others still go through a review process. Or you could do something else entirely. The concept is flexible enough to allow several ways to collaborate.
