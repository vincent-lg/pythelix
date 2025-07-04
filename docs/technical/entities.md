---
title: Entities in a technical context with Pythelix
---

This document describes in different layers the manipulation of entities, attributes and methods. It then dives deeper into the structure of entities and how they are stored within cache and database.

## Manipulae entities

Manipulating entities from Pythelix in Elixir usually require the usae of the `Pythelix.Record` module and its functions.

At its core, an entity is a structure defined in `Pythelix.Entity`. To retrieve it from the database or cache:

```iex
iex(?)1> Pythelix.Record.get_entity(1)
!account!
```

We try to retrieve the entity of ID 1. Which returns `!account!`. Why so?

If you have used Pythelix, you might know that entities can have either a key or an ID or both. In my case, the entity of ID 1 also happens to have a key, `"account"`. You can easily check:

```iex
iex(?)2> entity = Pythelix.Record.get_entity(1)
!account!
iex(?)3> entity.id
1
iex(?)4> entity.key
"account"
```

The rule is simple:

- Virtual entities, kept in cache only (in memory) but not stored anywhere, have no ID (their `entity.id` will return `:virtual`, a special atom to identify entities with no ID);
- Stored entities, kept in the database, always have a valid ID;
- Entities don't need keys, except entities that are defined in [worldlets](../worldlets.md). These always have a key.

`!account!` is defined within a worldlet (in `wordlet/demo.txt`):

```
[account]
```

That's all it takes to define an entity in a worldlet. So this creates (or updates) an entity with a key of `"account"`. The first time the worldlets are loaded, this entity is created. It's not a virtual entity (like a command or a menu), so Pythelix saves it to the database. next time the worldlet is loaded, the `!account!` entity is updated (not created again).

That's why this entity both has a key (`account`) and an ID (1). It is defined in a worldet (so it needs a key), but it's not a virtual entity (not a command or menu) so it ends up having an ID as well.

> Remember, keys have to be unique and you might realize why at this point.

So `Pythelix.Record.get_entity/1` will query the database or cache to find the entity. It can search an entity by its ID or by a key (secify it as a string):

```iex
iex(?)5> Pythelix.Record.get_entity("room")
!room!
```

If the serached entity cannot be found, `nil` is returned.

### Working with attributes

The `Pythelix.Record` module also provides functions to retrieve and modify attributes. The `worldlets/dmoe.txt` file also defines the `bakery` entity, a room (a bakery).

```iex
iex(?)7> bakery = Pythelix.Record.get_entity("bakery")
!bakery!
```

Then you can query all its attributes:

```iex
iex(?)8> Pythelix.Record.get_attributes(bakery)
%{
  "description" => "\nThe warm, inviting scent of freshly baked bread and sweet pastries fills\nthe air upon entering ...",
  "price" => 30000,
  "title" => "A bakery"
}
```

This returns a map of attribute names and their values. We can see here the `bakery` entity has three attributes: `description`,m `price` and `title` (`price` is mostly an example to show you attributes don't have to hold only strings).

You can also get a certain attribute value directly:

```iex
iex(pythelix@127.0.0.1)9> Pythelix.Record.get_attribute(bakery, "title")
"A bakery"
```

You can also specify a default value as third argument, is the entity doesn't have this attribute:

```iex
iex(pythelix@127.0.0.1)10> Pythelix.Record.get_attribute(bakery, "unknown", 8)
8
```

To change entity attributes (add or update one), use the `set_attribute` function:

