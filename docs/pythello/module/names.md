---
title: "names — entity name grouping module"
---

The `names` module provides functions for grouping entities by name, typically for display purposes. It works with lists of entities and stackables produced by [`search.match`](./search.md) or the `.contents` attribute on containers.

## `names.group`

Group a list of items by name, returning one display name per group.

```
names.group(items, viewer=None, filter="name")
```

### Parameters

| Name | Type | Required | Description |
|---|---|---|---|
| `items` | list | yes | A list of entities or stackables to group (e.g., from `search.match` or `.contents`). |
| `viewer` | entity | no | The entity performing the display (usually a player). Enables the [`__namefor__`](./search.md#__namefor__-on-item-entities) hook. |
| `filter` | string | no | The attribute name to group by. Defaults to `"name"`. |

### Return value

A list of strings, one per group, in first-occurrence order. Each string is the display name for that group, obtained by calling `__namefor__(viewer, quantity)` on the first entity in the group. When no viewer is provided, or the entity does not define `__namefor__`, the raw attribute value is used.

### Grouping rules

Items are grouped by their resolved name. The resolved name is:

- The return value of `__namefor__(viewer)` when a viewer is provided and the hook exists.
- The raw attribute value (named by `filter`, defaulting to `"name"`) otherwise.

Within each group, quantities are summed: regular entities contribute 1 each, stackables contribute their full quantity. The total is then passed to `__namefor__(viewer, quantity)` to produce the final display name.

### Ordering

Groups appear in the order their first member appears in the input list. This matches the ordering of `search.match` and `container.contents`, so item indices are consistent between display and interaction.

For example, if a room contains a sword, three apples, and a key (in that order), `names.group` produces three groups in the order: sword, apple, key. A player typing `2.apple` would select the second apple in both `search.match` and the grouped display.

### Examples

Basic grouping of container contents:

```
items = !room!.contents
result = names.group(items)
# ["sword", "apple", "gold coin"]
```

With a viewer for pluralised names (requires `__namefor__` with quantity support):

```
items = !room!.contents
result = names.group(items, viewer=!player!)
# ["sword", "3 apples", "100 gold coins"]
```

Grouping search results:

```
matches = search.match(!room!, "apple", viewer=!player!)
result = names.group(matches, viewer=!player!)
# ["3 apples"]
```

Complete display workflow:

```
items = !room!.contents
display_names = names.group(items, viewer=player)
for name in display_names:
    tell(player, name)
done
```

### Setting up `__namefor__` for pluralisation

To produce pluralised group names, define `__namefor__` with two positional arguments on your entity (or a parent entity):

```
[object]

{__namefor__(viewer: Entity, quantity: int = 1) -> str}
if quantity == 1:
    return self.name
return f"{quantity} {self.name}s"
```

The `quantity` argument has a default of `1`, so the method also works when called by `search.match` (which passes only the viewer). See the [`__namefor__` documentation](./search.md#__namefor__-on-item-entities) for details.
