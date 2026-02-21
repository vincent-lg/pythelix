---
title: Stackables in Pythelix
---

Stackables solve one of the most common headaches in MUD development: modeling items that exist in quantities. Coins, potions, arrows, crafting materials—these are things players expect to accumulate in piles rather than carry one at a time. Stackables let you represent a thousand gold coins as efficiently as a single one.

## The problem stackables solve

Without stackables, you'd need to create a separate entity for each coin, potion, or arrow in the game. A chest containing 500 gold coins would require 500 individual entity objects in the database—nearly identical, differing only in location. That's wasteful, slow, and painful to maintain.

Stackables flip this around: you define the item once (a single `gold_coin` entity acting as a prototype), then represent any quantity of it anywhere in the world with a lightweight **stack**: a record that says "there are N of this item here." One entity in the database. Any number of stacks in any number of containers.

## Two concepts to keep in mind

Understanding stackables requires keeping two distinct ideas separate:

- **The stackable entity**: the definition of the item—its name, description, value, and behavior. This is a normal entity defined in a worldlet, with one extra attribute: `stackable: True`. It is defined once and never duplicated.
- **A stack**: a record that ties a stackable entity to a container with a specific quantity. "There are 400 gold coins in the treasure room" is one stack. "There are 12 gold coins in the player's inventory" is another. Both refer to the same `gold_coin` entity.

Think of it like a library catalog. The catalog entry for a book (the stackable entity) exists once, regardless of how many copies are on the shelves. Each shelf location holding copies of that book is a stack.

## Why use stackables?

Stackables offer three clear benefits over managing individual item entities:

- **Efficiency**: a single entity row in the database, no matter the quantity. A chest of 10,000 gold coins costs exactly the same as a chest of one.
- **Simplicity**: no need to create, track, or destroy hundreds of nearly identical entity instances. The quantity is just a number.
- **Consistency**: changing the stackable entity—its name, description, value—immediately affects every stack referencing it, everywhere in the world.

> Stackables are ideal for consumables, currency, crafting materials, ammunition, and any other item players expect to accumulate in quantity. If your item is unique—a specific named sword, a player's personal journal—a regular entity is the right choice.

## Defining a stackable entity

A stackable entity is a normal entity in a [worldlet](./worldlets.md), distinguished only by the `stackable: True` attribute:

```
[gold_coin]
stackable: True
name: "gold coin"
description: "A shiny gold coin."
value: 1
```

This creates an entity with the key `"gold_coin"`. It acts as a prototype: it is never placed directly in the world—instead, stacks reference it.

## Working with stacks in scripts

All stack manipulation happens in scripts. The `stackable()` built-in function creates a new stack:

```
stack = stackable(!gold_coin!, 100)
```

This creates a stack of 100 gold coins. At this point, the stack has no location—it is not yet in any container. Think of it as a floating quantity, waiting to be placed.

### Placing a stack

Assign the `location` attribute to put the stack inside a container:

```
stack = stackable(!gold_coin!, 100)
stack.location = !treasure_room!
```

After this, the treasure room contains 100 gold coins. Placing more stacks into the same container accumulates their quantities:

```
more = stackable(!gold_coin!, 50)
more.location = !treasure_room!
# treasure_room now contains 150 gold coins
```

### Transferring a stack

Assigning a new location moves the full quantity from the old container to the new one:

```
stack = stackable(!gold_coin!, 200)
stack.location = !room!
# room: 200 coins

stack.location = !player!
# room:   0 coins
# player: 200 coins
```

### Removing a stack from a container

Setting `location` to `None` removes the stack from its container entirely, turning it back into a floating quantity:

```
stack = stackable(!gold_coin!, 30)
stack.location = !vault!
# vault: 30 coins

stack.location = None
# vault: 0 coins, stack is floating
```

## Reading attributes

A stack exposes two attributes of its own:

- **`quantity`**: the number of items in this stack (read-only).
- **`location`**: the container this stack is currently placed in (`None` if floating).

All other attribute accesses are forwarded directly to the underlying entity:

```
stack = stackable(!gold_coin!, 400)
stack.location = !treasure_room!

name = stack.name      # "gold coin", from the entity
val  = stack.value     # 1, from the entity
qty  = stack.quantity  # 400, from the stack itself
```

This forwarding is particularly powerful when iterating over a container's contents: you can read `name`, `description`, or any other attribute through the stack without knowing in advance whether you're dealing with a stack or a plain entity.

### Quantity on regular entities

Regular [entities](./entities.md) also expose a `quantity` attribute, which always returns `1`. This makes it easy to iterate over a container that holds a mix of regular entities and stackables without special-casing either:

```
for item in !storage_room!.contents:
    # item.quantity is 1 for regular entities, N for stackables
    total = total + item.quantity
done
```

## Searching inside a container

In practice, you rarely want to transfer an entire stack at once. A player picking up "10 gold coins" from a room that has 200 shouldn't empty the room—they should take only what they asked for.

Use `search.match` to find items inside a container by a text attribute. It works on containers holding regular entities, stackables, or a mix of both. The examples below cover the most common options; for the full reference—including per-viewer visibility, per-viewer naming, game-wide text normalisation, and result indexing—see the [search module documentation](./pythello/module/search.md).

```
results = search.match(!treasure_room!, "gold")
```

`results` is a list of matching items (entities or stacks). By default, `search.match` filters on the `name` attribute and accepts any prefix or substring match. It does not modify anything—searching never moves items.

### Limiting the quantity returned

Pass `limit=N` to cap the quantity returned for each matching stack. This is the key to partial transfers:

```
# Room has 400 gold coins
matches = search.match(!room!, "gold", limit=10)
# matches[0].quantity == 10
# Room still has 400 coins — search.match doesn't modify anything
```

The returned stack is a new object with `min(available, limit)` as its quantity. Assign its location to perform the partial transfer:

```
matches = search.match(!room!, "gold", limit=10)
for result in matches:
    result.location = !player!
done
# room:   390 coins
# player: 10 coins
```

This pattern is exactly what you'd use to implement commands like `get 10 coin`.

### Filtering by a different attribute

By default, `search.match` looks at the `name` attribute. You can change this with the `filter` keyword argument:

```
results = search.match(!room!, "épée", filter="french_name")
```

All entities in the container must have the specified attribute defined for matching to work.

## Persistence

Stackable quantities stored in a container are automatically persisted alongside the container entity. No extra steps are needed: when the game server saves the container, the stackable counts are saved with it and restored on the next load.

## A complete example

In your worldlet:

```
[gold_coin]
stackable: True
name: "gold coin"
value: 1
```

In a method or command:

```
room = !treasure_room!
player = !player!

# Stock the room
chest = stackable(!gold_coin!, 500)
chest.location = room

# Player picks up 10 coins
matches = search.match(room, "gold", limit=10)
if matches:
    partial = matches[0]
    partial.location = player
endif

# Now:
# room has 490 gold coins
# player has 10 gold coins
```
