---
title: "search — container search module"
---

The `search` module provides functions for locating entities inside game containers and across the entire world database. It is the standard tool for implementing player commands like `get`, `drop`, `look`, `give`, and any other command that must resolve a player's text input into one or more items.

> This page is the full reference for the `search` module. If you are looking for a practical introduction to searching containers in the context of stackable items, see [Stackables](../../stackables.md).

## `search.match`

Find items inside a container whose name (or another attribute) matches a text query.

```
search.match(
    container, text, viewer=None, limit=None, index=None, filter="name"
)
```

### Parameters

| Name | Type | Required | Description |
|---|---|---|---|
| `container` | entity | yes | The entity whose contents are searched. |
| `text` | string | yes | The search query (case-insensitive by default). |
| `viewer` | entity | no | The entity performing the search (usually a player). Enables the `__visible__` and `__namefor__` hooks. |
| `limit` | int | no | Cap the quantity returned for each matching [stackable](../../stackables.md). Has no effect on regular entities. |
| `index` | int | no | Return only the Nth matching item (1-based). Returns an empty list when the index is out of range. |
| `filter` | string | no | The attribute name to match against. Defaults to `"name"`. |

### Return value

A list of matching items. Each item is either a regular entity or a stackable stack. The list is empty when nothing matches. The function never modifies the container or any item—use `item.location` assignment to move items after a match.

### Matching rules

By default, `search.match` lowercases both the search query and the item attribute before comparing. A match is found when the normalized attribute **starts with** or **contains** the normalized query.

Text normalisation can be overridden game-wide with the [`!search!.normalize` hook](#search-entity-and-the-normalize-hook).

### Examples

Basic lookup:

```
results = search.match(!treasure_room!, "gold")
# returns all items whose name starts with or contains "gold"
```

Partial transfer — pick up 10 coins from a pile of 400:

```
matches = search.match(!room!, "gold coin", limit=10)
for item in matches:
    item.location = !player!
done
```

Disambiguation — pick up the second matching item:

```
matches = search.match(!room!, "sword", index=2)
if matches:
    matches[0].location = !player!
endif
```

Combined index and limit (second gold stack, at most 5):

```
matches = search.match(!room!, "gold", index=2, limit=5)
```

With a viewer — respects visibility and per-viewer names:

```
matches = search.match(!room!, "key", viewer=!player!)
```

Custom attribute — searching by a localised name:

```
results = search.match(!room!, "épée", filter="french_name")
```

## `search.many`

Query the world database for entities matching one or more attribute filters. Returns all results.

```
search.many(parent=None, **filters)
```

### Parameters

| Name | Type | Required | Description |
|---|---|---|---|
| `parent` | entity | no | When provided, only entities that inherit (directly or indirectly) from this parent are returned. |
| `**filters` | keyword arguments | yes (at least one) | Each keyword argument is an attribute name; its value is the required attribute value. |

At least one keyword filter must be provided. Calling `search.many()` with no filter raises `ValueError`.

### Return value

A list of entities. The list may be empty.

### Examples

Find all entities with `type` set to `"npc"`:

```
npcs = search.many(type="npc")
```

Find all entities of parent `!monster!` with `status` set to `"alive"`:

```
alive = search.many(!monster!, status="alive")
```

## `search.one`

Like `search.many`, but asserts that at most one result exists. Raises `ValueError` if more than one entity matches.

```
search.one(parent=None, **filters)
```

### Parameters

Same as `search.many`.

### Return value

A single entity when exactly one match is found, or `None` when no match is found. Raises `ValueError` when more than one entity matches.

### Examples

```
guild = search.one(name="Thieves Guild")
if guild:
    # exactly one guild found
endif
```

## Hooks

The `search` module is designed to be customised entirely through the scripting layer, without requiring any changes to the engine. Three hooks are available.

### `!search!` entity and the `normalize` hook

If an entity with the key `search` exists in the world and defines a method named `normalize`, `search.match` will call it to prepare both the search query and each item's name before comparison. This enables language-aware matching such as accent stripping or transliteration.

The method receives the raw text as its first argument and must return a string.

**Signature:**

```
{normalize(text: str) -> str}
```

**Example — accent-insensitive French matching:**

```
[search]

{normalize(text: str) -> str}
result = text.lower()
result = result.replace("é", "e")
result = result.replace("è", "e")
result = result.replace("ê", "e")
result = result.replace("à", "a")
result = result.replace("ô", "o")
return result
```

Once this entity is defined, `search.match(!room!, "epee")` will find an item named `"épée"`.

> The `!search!` entity is optional. If it does not exist, or if it exists but does not define `normalize`, `search.match` falls back to plain `String.downcase` normalisation.

The normaliser is called once per `search.match` invocation to prepare the query, and once per item during filtering. Method bytecode is cached after the first compilation, so the overhead per item is minimal.

### `__visible__` on item entities

When `search.match` is called with a `viewer=` argument, it calls `__visible__(viewer)` on each item's entity before attempting a name match. Items for which the method returns `False` are excluded entirely, as if they were not in the container.

This hook is the right place to implement:

- Items invisible in dark rooms
- Hidden or cloaked items that only certain players can detect
- Objects restricted to specific roles or factions

**Signature:**

```
{__visible__(viewer: Entity) -> bool}
```

Any return value other than an explicit `False` (including `:nomethod`, `:noresult`, and a method error) is treated as visible. This makes the default behaviour — no `__visible__` method defined — equivalent to always visible.

**Example — hide items in unlit rooms:**

```
[object]

{__visible__(viewer: Entity) -> bool}
lit = self.location.is_lit
carrying_light = viewer.has_light
return lit or carrying_light
```

**Example — items visible only to administrators:**

```
[secret_document]
parent: "object"
name: "secret document"

{__visible__(viewer: Entity) -> bool}
return viewer.is_admin
```

> The dunder naming convention (`__visible__`, with double underscores on both sides) is intentional. It signals a system-level hook and reduces the risk of a builder accidentally defining a method named `visible` for an unrelated purpose and triggering unexpected search behaviour.

### `__namefor__` on item entities

When `search.match` is called with a `viewer=` argument, it calls `__namefor__(viewer)` on each item's entity to determine the name used for matching. This allows the same item to appear under different names to different players.

**Signature:**

```
{__namefor__(viewer: Entity) -> str}
```

If the method is absent (`:nomethod`), produces no return value (`:noresult`), or raises an error, `search.match` falls back to the raw attribute value (the one named by `filter`, defaulting to `"name"`).

This hook enables:

- Administrators seeing items with their entity ID appended
- Items identified differently depending on a player's language or skill
- Partially identified items (e.g. `"a strange potion"` becoming `"potion of healing"` once examined)

**Example — administrators see entity IDs:**

```
[object]

{__namefor__(viewer: Entity) -> str}
if viewer.is_admin:
    return f"{self.name} [#{self.id}]"
return self.name
```

With this method, an administrator searching for `"gold coin [#"` would find the item; a regular player searching for `"gold"` would also find it (since their normalised name is `"gold coin"`).

**Example — item identified only after examination:**

```
[unidentified_potion]
parent: "object"
name: "strange potion"
true_name: "potion of healing"

{__namefor__(viewer: Entity) -> str}
if viewer.has_identified(self):
    return self.true_name
return self.name
```

> Searching without a `viewer=` argument always uses the raw attribute, regardless of whether `__namefor__` is defined. This is intentional: viewer-less searches (used by scripts, automation, or admin tooling) should not depend on per-player state.

## Interaction between hooks

The three hooks compose cleanly:

1. **`normalize`** is applied to the search query once, and to the name produced by `__namefor__` (or the raw attribute fallback) for each item.
2. **`__visible__`** is checked before name matching. Invisible items are never passed to `__namefor__` or the normaliser.
3. **`index`** and **`limit`** are applied after all filtering is complete.

The full pipeline for a call like `search.match(!room!, "gold", viewer=!player!, index=2, limit=5)` is:

```
for each item in container.contents:
    if not item.__visible__(viewer):        skip
        name = item.__namefor__(viewer)         (or raw attribute)
        name = search.normalize(name)           (or String.downcase)
        query = search.normalize("gold")        (computed once, reused)
        if name contains query:                 include in candidates
        apply index=2 → take second candidate
        apply limit=5 → cap stackable quantity to 5
```
