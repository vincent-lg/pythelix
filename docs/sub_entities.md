This document explains what sub-entities are, how they differ from entities, and when they can be useful.

**WARNING:** This is a more advanced topic. You should be familiar with the concepts of [entities](./entities.md), [worldlets](./worldlets.md), and [Pythello scripting](./scripting.md) before continuing. If you don't immediately see why sub-entities would be useful, you might not need them at all.

## Definition

A sub-entity is very similar to an entity, except that it is *never* saved directly to the database. It does not have an ID or key.

There are specific situations where this mechanism is beneficial, which we will discuss shortly.

For now, consider sub-entities as entities that are not meant to be stored directly.

> **What's the point? Wouldn't virtual entities serve the same purpose?**

If you know Pythelix well, you might recall that virtual entities are stored in memory. They behave like entities (they do not have an ID but do have a key), but they are not saved to the database.

Sub-entities, on the other hand, are stored—but not directly: they are stored inside another entity. Hence the name. When the parent entity is saved to the database, its sub-entities are saved as part of its attributes. The key difference is that sub-entities are not saved as separate entries in the database (i.e., no new row is created for them). This is not only more efficient, but also ensures that if the parent entity is deleted, the sub-entities contained within it are automatically removed.

## Why are sub-entities useful?

We will explore several use cases where sub-entities are beneficial. You might think of others. If you don’t see their usefulness, you may not need them—this is an advanced concept, and in many cases sub-entities can simply be entities. While that can sometimes create unusual situations, it is not necessarily problematic.

### Exits: an example of data always inside another entity (a room)

First example: exits. Entities typically represent small parts of your game world—objects, rooms, characters, etc. Why shouldn’t they represent exits? Something like this:

```
[exit]
name: None
destination: None
door: None
open: True

# ... and then later
[bakery/north]
parent: "exit"
name: "north"
destination: !sidewalk!

[bakery]
parent: "room"
exits: [
    !bakery/north!
]
```

Notice one thing first: our exit (leading north from the bakery) needs a key. We set it to `bakery/north`. This is necessary because all entities in a worldlet need a key (this is a golden rule).

So we must define a separate entity to hold our exit. Okay, the key naming is not ideal, but manageable. The problem arises when the bakery entity is deleted—for any reason—the exit entity still exists because there is no mechanism to remove it automatically. There are workarounds, but they introduce complexity.

Most importantly, our exit is generally not useful on its own. It is meant to be stored inside the room entity. When you see this pattern, the natural solution is to use sub-entities.

Now, let's see the same example using a sub-entity instead:

```
[Exit]
parent: "SubEntity"

{__init__(self, name: str, destination: Entity)}
self.name = name
self.destination = destination
self.door = None
self.open = True

# ... and then later
[bakery]
parent: "room"
exits: [
    Exit("north", !sidewalk!)
]
```

This example introduces some complex topics, so let’s first focus on the room entity. Notice it still defines an `exits` attribute, which is a list, but the first (and only) element is `Exit("north", !sidewalk!)`. It almost looks like Python: creating an `Exit` object by calling its constructor, specifying the direction (`"north"`, a string) and the destination (another entity). And that’s exactly what happens.

Where does this `Exit` class come from? It is defined as an entity with a capitalized key (`Exit`) and its parent is `SubEntity`. Both are required to create a sub-entity. Once defined, you can use it anywhere as if `Exit` were a class.

It behaves like a class: notice we have defined only one method, `__init__`. This takes three arguments:

- `self` (the sub-entity itself);
- `name`: the exit direction as a string;
- `destination`: the exit destination as an entity.

Inside the method, we assign values to attributes on `self`, just like a Python constructor. We create four attributes: `name`, `destination`, `door`, and `open`.

What happens next? Our `Exit` sub-entity is stored inside the room entity (in a list, in fact). So when we modify the sub-entity, the parent entity (the room) is marked as changed and saved.

The syntax might look odd initially but will feel more natural if you're familiar with Python's class definitions, especially constructors.

Here, both issues are resolved:

1. Our exit doesn't require or have a key (because it is not stored directly in the database).
2. If our room is deleted, the exit also ceases to exist because it is embedded inside the room’s attributes, which are removed automatically.

### A handler to store stats

Another common use case for sub-entities is handlers—objects used to avoid cluttering your entity with too many attributes and methods. Consider stats: in most games, a character has many stats (HP, EP, strength, charisma, chance, etc.). Some have maximum values that must be respected. Sure, you could put them all inside the character entity and add methods there, but a handler is cleaner.

```
[StatsHandler]
parent: "SubEntity"

{__init__(self, hp: int, ep: int)}
self.hp = hp
self.hp_max = hp
self.ep = ep
self.ep_max = ep

{restore()}
self.hp = self.hp_max
self.ep = self.ep_max

{die()}
self.hp = 0

{hurt(damage: int)}
self.hp -= damage
if self.hp < 0:
    self.hp = 0
endif

{heal(gain: int)}
self.hp += gain
if self.hp > self.hp_max:
    self.hp = self.hp_max
endif
```

Inside a character entity, you would use it like this:

```
[guard]
parent: "Character"
stats: StatsHandler(hp=8, ep=15)
```

You can then do things like:

```
>>> guard = !guard!
>>> guard.stats.restore()
>>> guard.stats.heal(2)
>>> guard.stats.hurt(10)
```

This approach is more organized than putting everything inside the entity itself. It provides clearer separation. And again, when the guard entity is deleted from the database, its stats handler is deleted as well.

In short, sub-entities are designed to be easy to use and avoid complications—so why not use them?

### Inventory or equipment, a collection

Most games share the concept of character inventory or equipment. Those familiar with LambdaMOO might consider adding the character’s inventory directly using the content/location relationship:

```
object.location = character
```

What about equipment though? Equipment is technically “on” the character as well. How should we differentiate between objects that are just carried (inventory) and those that are worn (equipment)?

Different games propose different strategies. Pythelix asks you: why not separate them more cleanly?

```
[Inventory]
parent: "SubEntity"

{__init__(self)}
self.objects = []

{get(object: Entity, from_location: Entity)}
if object in self.objects:
    return None
elif object not in from_location.content:
    return None
else:
    object.location = None
    self.objects.append(object)

{drop(object: Entity, location: Entity)}
if object not in self.objects:
    return None
elif object in location.content:
    return None
else:
    object.location = location
    self.objects.remove(object)
```

Then, on the character entity:

```
[character]
inventory: Inventory()
```

Inventory is clearly separated (you can define a sub-entity for equipment as well). This is likely much more robust for your game design, instead of merely relying on changing the location of objects to mimic get/drop/give, especially when handling more complex scenarios like containers.

### Owned text messages

Imagine a game set in the future (or modern society) where players can send text messages to one another. Suppose we want to store these text messages so we can display the “last sent/received messages from that player” to anyone in the player’s contact list, for instance.

So we need to store the messages: should text messages be entities? Players might send thousands (or more) messages. Storing each as an entity would quickly become wasteful.

Text messages could instead be modeled as sub-entities:

```
[TextMessage]
parent: "SubEntity"

{__init__(self, sender: Entity, recipient: Entity, content: str)}
self.sender = sender
self.recipient = recipient
self.content = content
```

Then you could store these messages inside phone objects. True, this means you would need to store every message twice (once on the sender’s phone and once on the recipient’s phone), but it’s still much more efficient.

## When not to use sub-entities?

Sub-entities aren’t a one-size-fits-all solution. Like every design concept, they have their limitations. Trying to apply sub-entities everywhere may lead to problems.

First, sub-entities are meant to be stored within an entity:

- If data is to be shared among several entities, then this data should be an entity;
- If data should be independent of an entity’s life cycle, then it should be an entity itself.

In the previous example, we described a sub-entity for a text message: this is a valid application. As pointed out, you would need to store each text message twice—once for the sender, once for the recipient. Sub-entities are linked to one (and only one) entity. Wouldn't it have been more effective to use entities for text messages? Maybe at first. But once the number of text messages grows, it’s definitely not the best option. There are alternatives, and sub-entities are definitely an interesting one.

However, if you consider switching your rooms to be sub-entities, think again: it might cause serious problems. Rooms are referenced by many parts of your game, so putting them inside other entities wouldn’t make sense.
