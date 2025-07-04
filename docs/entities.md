---
title: Entities in Pythelix
---

Simply put: your game cannot exist without entities. Everything in the game is an entity (a room, an object, a non-player character, a vehicle, etc.). If you're not familiar with entities in Pythelix, it is recommended to read this chapter sequentially. If you already know LambdaMOO, you can go directly to the [section about LambdaMOO](#Coming-from-LambdaMOO).

## What is an entity?

An entity is a "piece of information" in your game. It can represent anything in your game world. Let's consider a concept most MUDs have in common: rooms.

A room is just an entity in Pythelix. All entities have two main components:

- **Attributes**: these are pieces of data inside your entity (like the room title or the room description).
- **Methods**: these define behavior (what to do with this entity in situation X or Y).

### Entity attributes

Attributes are easier to understand: they are simply named data values on your entity. For example, your room (an entity) could have an attribute `"title"` containing the title of the room. And of course, you can create several rooms (several entities) with different titles (different attribute values, though the attribute names remain the same).

Here is an example of [a worldlet file](./worldlets.md):

```
[bakery]
parent: "room"
title: "A bakery"
description: """
The warm, inviting scent of freshly baked bread and sweet pastries fills
the air upon entering this cozy little shop. A fine dusting of flour clings
lightly to the wooden floorboards and countertops. Shelves and display cases
brim with golden-baked goods: loaves of crusty bread, delicate pastries,
and confections in all shapes and sizes. Icing glistens under soft lighting,
while nuts, berries, and chocolate chips adorn many of the treats with artistic
precision. At the back of the shop, an antique wooden cash register rests
atop a counter, its brass details dulled slightly with age and use.
"""
```

For now, note that an entity begins with a line between brackets (`[bakery]`). All attributes follow this syntax:

    attribute_name: attribute_value

In this example, we see several attributes:

- `parent`: we'll discuss this later;
- `title`: the title of the room;
- `description`: the description of the room (notice it spans multiple lines, but you don't need to worry about the syntax here).

All of these are attributes, although `parent` has a special meaning to be covered later.

Here, all attribute values are strings enclosed in double quotes (`"`). However, this is not always the case: attributes can also hold numbers or other types of values.

If you want to learn more about worldlets (what they are and how to use them), see [the documentation about worldlets](./worldlets.md).

### Entity methods

As mentioned earlier, methods represent behavior: instead of just holding data (like a title), they describe "what to do in a given situation." A "given situation" could be a command or a contextual event (for example, when a player character enters the room of a non-player character, the NPC might be notified and a method on the NPC entity would be executed, allowing the NPC to greet the player or attack them).

The concept of methods is more advanced, so we'll leave it at that for now: methods are behavior. If you want to learn about behavior in Pythelix, check [the documentation about methods](./methods.md).

### Entities can have keys

It is often necessary to find a specific entity. This is especially true when one entity must be "connected" to another.

For example, imagine you want to spawn a non-player character in a room every 15 minutes (unless it is already present). This creates a kind of "random" respawn: if the NPC is killed by a player, it will eventually return.

If we define an attribute in the room, for instance `"repop"`, how should we indicate it refers to a specific NPC? We have another piece of information (another entity) describing that NPC, but how do we connect the two?

This is where **keys** come in: keys are unique identifiers. A key should only be used by one entity. They are groups of letters (digits and special characters, including accented letters). The only rule is that keys must be unique: one key, one entity. Which key you use is entirely up to you, but you should choose a strategy and remain consistent in your world, because entity keys cannot be changed easily.

> Ideas: You could form a key by including the entity type and an "address." For example, the entity with key `"room/demo/1"` would indicate a room (only rooms having this prefix), zone `"demo"`, and the specific room identifier `1`. Again, no other entity should have the same key. If you follow a good system, entity keys will be easy to track.

I mentioned that a key should link to only one entity; however, an entity does not have to have a key. Entities can exist without keys. These entities, however, are not created by your worldlet. Think of player characters (yes, these are entities). What should their key be? An email address assigned at character creation? That could work if you only allow one character per email address. They could also have no key (looking them up would follow a different pattern). But most entities in the game should have a key.

Let's consider another example: you may want to create objects and decide to have prototypes for each object. An object would always be created from a prototype, so its title, description, and statistics would match the prototype's. If you change these data in the prototype, it affects all objects created from it. The prototype could be part of your worldlet (with a key like `"prototype/object/red_apple"`). But what about objects created from that prototype? Should they have keys? This is up to you. They could have keys or not. You might create objects with individual keys, such as `"object/red_apple/33"`, to uniquely identify each object. It might not be strictly necessary, but it would make sense. Note that objects would not be created in your worldlet in this case, so the system for generating keys would be your responsibility. Objects without keys could also work. Your choice.

## Entities have a parent

The example of prototypes and objects is useful to explain the concept of inheritance (the technical term). An entity can have a parent (another entity). That parent can also have a parent, and so on. Some entities have no parent (so the chain ends eventually).

Basically, if entity A has a parent B, then A automatically inherits all attributes and methods of B. This includes all attribute values. For example, the prototype could be the parent of all objects. The prototype `red_apple` could have attributes like `name`, `description`, `weight`, `price`... and each red apple object, regardless of its location or quantity, would also have these attributes. This also applies to methods (the red apple object would have the same behavior as the prototype). This is extremely powerful for game design. A well-structured inheritance system can lead to great results.

> Can an entity have several parents?

No. This is not a limitation, but a design choice: from my experience as a game designer, multiple inheritance (entities having several parents) complicates error tracking. Which attribute or method should the entity have? How to resolve conflicts? Better to avoid "diamond-shaped inheritance" as it is sometimes called. Most cases where multiple inheritance seems useful can be solved with a simpler design using single inheritance (each entity having one and only one parent). Note that an entity can have multiple ancestors through the parent chain (the parent can have its own parent, and so on).

## When not to use entities?

Earlier we talked about rooms. How should exits be defined? Exits are usually defined on a room and connect two rooms with a specific name: an exit called `"north"` could link room A with room B. Players in room A could type `"north"` (or `"n"`) to go to room B.

How should we model exits?

> We could create entities!

That could be a good solution. On one hand, exits would have attributes and methods (data and behavior), allowing you to, for example, define a `"can_traverse"` method on the exit itself, not just on the room, which might be less straightforward.

On the other hand, there are issues with modeling exits as entities:

- Defining them in worldlets would be best, but then exits would require unique keys, something like `"exit/demo:1/north"` combining room key and direction. That might work, but it’s a lot of typing. Entities in worldlets must have keys (a strict rule for good reasons).
- Even if you assign keys to exits, applying a file to create rooms and exits, then removing an exit from the file and reapplying it doesn’t delete the exit entity. Worldlets only create or update; they don't delete. This can leave "orphaned" exits after updating.
- If you have dynamic behavior creating and removing exits automatically (e.g., a room that moves and connects to different rooms like a subway or elevator), the exit entity would need to be recreated each time the room moves. This is doable but should prompt careful consideration. Entities are generally not meant for very short-lived existence.

What alternatives do we have? We can just set exits on the room as an attribute:

```
[bakery]
title: "A bakery"
description: "..."
exits: {
    "north": !room/demo/2!,
    "east": !room/demo/58!,
    "down": !room/underground/1!,
}
```

> The syntax shown here defines a dictionary. See the [documentation about scripting](./scripting.md) for more details (every attribute can have a value that is valid scripting).

In this design, exits are just an attribute (a dictionary) of the room entity. You can easily modify this attribute, avoiding proliferation of potentially unnecessary entities.

Admittedly, this approach introduces other challenges. I'm not suggesting modeling exits as entities is wrong, rather, creating entities in every case may not always be best.

To sum up: entities should, in most cases, exist for some time. Creating and destroying entities is not free in terms of system resources. Your database can hold billions of entities, but eventually, it will be too much. Avoid a design where millions of entities are created and destroyed daily. While this likely won't be a problem for years, it should be kept in mind.

That said, don't worry too much. Entities in Pythelix are lightweight, distributed, and saved separately. Just try to avoid scenarios where entities are created and destroyed too frequently (e.g., every second), this is where problems might arise.

## Abstract entities

So far, we've focused on entities with concrete roles: rooms, characters, objects, vehicles. But entities can also represent abstract concepts, elements not directly visible to players but still influencing gameplay. For example:

- **Races or classes**: You could create an entity for each playable race or character class. Individual characters then reference these entities via attributes. Race/class entities can provide default attributes (like hand slots) and behaviors (such as passive traits or restrictions).
- **Skills or spells**: Each skill or spell could be an entity. Behavior can be defined via methods (e.g., what happens when the spell is cast).
- **Help topics**: Help content can be modeled as entities, enabling dynamic listing or retrieval when a player types `"help"`.
- **Worldbuilding constructs**: Planets, galaxies, factions, quests, apps, zones, etc., can all be entities—not necessarily for direct interaction but to organize game logic or narrative.

Entities need not be visible or "physical" in the game world to be powerful tools. They serve as containers for logic, metadata, and structure.

For example, suppose you're building a game set in the Star Wars universe. Characters (player and NPC) belong to different races. Some races have more limbs than others, affecting how many "hand slots" they have for equipping items. Humans typically have two arms (two hand slots), while Besalisks have four arms (four hand slots). This adds interesting variety to gameplay and character design. You could create an entity like:

```
[generic/race]
title: "non specified"
description: "not set"
hand_slots: 0
```

Then add humans:

```
[race/human]
parent: "generic/race"
title: "Humans"
description: """
Humans are a highly adaptable, resourceful species known for their diversity
and resilience. While not the most physically remarkable race in the galaxy,
their ingenuity and cultural variety make them one of the dominant civilizations
in most star systems.
"""
hand_slots: 2
```

... and Besalisks:

```
[race/besalisk]
parent: "generic/race"
title: "Besalisks"
description: """
Besalisks are a large, four-armed species known for their strength, endurance,
and multitasking ability. Native to the planet Ojom, Besalisks can wield
multiple weapons or tools simultaneously, making them formidable in both combat
and technical fields.
"""
hand_slots: 4
```

This setup allows a clean, flexible structure where abstract traits like race meaningfully influence gameplay without cluttering visible game content.
