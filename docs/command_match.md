---
title: Matching and Displaying Items in Commands
---

Many commands need to resolve a player's text input into one or more items in the world, move those items, and tell the player what happened. This page explains the standard pattern for doing so, illustrated with a fully working `get` command.

For the complete API reference, see [`search.match`](./pythello/module/search.md) and [`names.group`](./pythello/module/names.md).

## The pattern

Matching commands follow a three-step structure:

1. **Parse** — the syntax extracts text and numbers from what the player typed.
2. **Refine** — `search.match` is called to find the actual entities that match the text.
3. **Run** — items are moved and the player receives feedback via `names.group`.

This split maps directly onto the `refine` and `run` methods of a command:

```
[command/get]
parent: "generic/command"
name: "get"
syntax: "(#number#) <object>"

{refine(client, object, number=1)}
to_pick = search.match(client.location, object, limit=number)

{run(client, to_pick)}
for item in to_pick:
    item.location = client
done
for name in names.group(to_pick, viewer=client):
    client.msg(f"You pick up {name}.")
done
```

This single command handles all of the following:

    get apple
    get 3 apple
    get 10 gold coin

## Walking through the example

### Syntax: `(#number#) <object>`

The syntax defines two variables:

- `object` — a text variable capturing the item name the player typed.
- `number` — an integer variable, wrapped in parentheses to make it **optional**.

When the player types `get apple`, the parser captures `object = "apple"` and leaves `number` unset. When the player types `get 3 apple`, both `object = "apple"` and `number = 3` are captured.

### Refine: finding the items

```
{refine(client, object, number=1)}
to_pick = search.match(client.location, object, limit=number)
```

The method signature `refine(client, object, number=1)` declares a **default value** for `number`. When the player omits the number from their input, the engine supplies `1` automatically.

`client.location` returns the room or container the player's character is currently in. `search.match` then searches that container's contents for items whose `name` attribute starts with or contains `object`. The `limit` parameter caps the **total** number of items returned across all matching stacks.

The result, `to_pick`, is a list of entities and stackables. It is available in `run` because variables set in `refine` carry over.

### Run: moving items and reporting

```
{run(client, to_pick)}
for item in to_pick:
    item.location = client
done
for name in names.group(to_pick, viewer=client):
    client.msg(f"You pick up {name}.")
done
```

`item.location = client` moves each item into the player's inventory. For stackable items, the engine automatically adjusts quantities in both the source container and the destination.

`names.group` then groups the moved items by name and returns one display string per group. If the entity defines a `__namefor__(viewer, quantity)` method, it is called to produce the final string (e.g. `"3 apples"` rather than `"apple"`). Without that hook, the raw `name` attribute is used.

## How `limit` works with multiple stacks

`limit` is a **global budget** shared across all matching items, consumed in the order the items appear in the container. Regular entities count as 1 each; stackable stacks consume up to their full quantity, limited by whatever budget remains.

A room contains two red apples (stackable, qty 2) added before five green apples (stackable, qty 5):

    get 3 apple

The budget is 3:

- Red apples: take `min(2, 3) = 2`, budget remaining = 1.
- Green apples: take `min(5, 1) = 1`, budget remaining = 0.

Result: the player picks up 2 red apples and 1 green apple. The room still has 4 green apples.

The player's feedback (with a `__namefor__` hook that pluralises correctly) would be:

> You pick up 2 red apples.
> You pick up a green apple.

Omitting `limit` (or using `limit=None`) returns **all** matching items.

## Handling no match

When nothing matches, `search.match` returns an empty list. The `for` loops in `run` simply produce no iterations, so the player receives no output. If you want explicit feedback, check the length of the list after the search:

```
{refine(client, object, number=1)}
to_pick = search.match(client.location, object, limit=number)

{run(client, object, to_pick)}
if len(to_pick) == 0:
    client.msg(f"You don't see {object} here.")
    return
endif
for item in to_pick:
    item.location = client
done
for name in names.group(to_pick, viewer=client):
    client.msg(f"You pick up {name}.")
done
```

> **Note on truthiness:** In Pythello, empty lists are **truthy** (following Elixir semantics, where only `None` and `False` are falsy). The pattern `if not to_pick:` does **not** detect an empty list. Use `len(to_pick) == 0` or `to_pick == []` instead.

## Adding pluralised display names

To get output like `"3 apples"` rather than `"apple"`, define `__namefor__` on the item entity (or a shared parent such as `object`):

```
[object]

{__namefor__(viewer: Entity, quantity: int = 1) -> str}
if quantity == 1:
    return self.name
return f"{quantity} {self.name}s"
```

The `quantity` default of `1` means the method also works when called by `search.match` (which only passes `viewer`). See the [`__namefor__` documentation](./pythello/module/search.md#__namefor__-on-item-entities) for details.

With this hook in place, the command output becomes:

> You pick up 2 red apples.
> You pick up a green apple.

## Searching a different container

The first argument to `search.match` is any entity. You can search the player's inventory, a specific chest, or any other container:

```
# Search the player's own inventory (to drop or give an item)
to_drop = search.match(client, object)

# Search a specific chest
to_take = search.match(!treasure_chest!, object, limit=number)
```

## Picking a specific item by index

When multiple items share the same name, players often use `2.sword` or `3.apple` to pick a specific one. Support this with the `index` parameter:

```
syntax: "(#index#.) (#number#) <object>"

{refine(client, object, index=None, number=1)}
to_pick = search.match(client.location, object, index=index, limit=number)
```

`index=2` returns only the second matching item. The result is still a list (of at most one entry), so the rest of the command is unchanged. When the index is out of range, `search.match` returns an empty list.

## Controlling visibility

Pass `viewer=client` to `search.match` to enable the `__visible__` hook. Items whose `__visible__` method returns `False` for the given viewer are excluded before name-matching begins:

```
to_pick = search.match(client.location, object, viewer=client, limit=number)
```

This is the right place to implement dark-room mechanics, hidden items, or faction-restricted objects. See [`__visible__`](./pythello/module/search.md#__visible__-on-item-entities) for details.
