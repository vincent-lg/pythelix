---
title: Writing a plugin
---

A [plugin](../plugins.md) is a directory of text files. You can start one right now, in your own game, and see it load the next time you apply: a directory in `plugins` that isn't in the lock file is a local plugin, loaded as it is.

## The layout

```
plugins/<key>/
  plugin.txt        # the manifest
  worldlets/...     # your worldlets
  scenarios/...     # your plugin's tests (optional, but expected to be published)
  docs/README.md    # what it adds, and how to extend it
```

A plugin holds `.txt` and `.md` files, and nothing else.

## The manifest

`plugin.txt` is a worldlet declaring one entity:

```
!plugin/rooms!
parent = "generic/plugin"
name = "Rooms"
version = "1.2.0"
pythelix = ">=0.6"
depends = {"base": ">=1.0", "exits": ">=1.0"}
description = "Rooms with titles, descriptions and exits."
```

- The key has to be `plugin/<directory name>`, in lowercase letters, digits, `-` and `_`.
- `version` is required, and looks like `1.2.0`.
- `pythelix` and `depends` are optional. A requirement can be `>=1.0`, `>=1.0, <2.0`, `~>1.2`, `1.2.0` or `*`.

Values have to be literals: strings, numbers, dictionaries. The manifest is read before any world exists, by commands that never start the game, so it can't call anything or refer to any entity.

## Depending on base

The engine itself only provides a few entities. `generic/room`, `generic/player`, `generic/char_command`, `command/look` and the login menus all come from the `base` plugin. If you inherit from any of those, say so:

```
depends = {"base": ">=1.0"}
```

Your scenarios need it too, since logging a player in takes `generic/player` and `menu/near_game`.

## Keys

Nothing is enforced, but a convention avoids collisions: put your entities under your plugin's key, like `rooms/generic_room`. Overriding someone else's entity, such as `command/look`, is allowed and legitimate. It's one more declaration with that key.

## Write for extension

Whoever installs your plugin adjusts it by redeclaring one attribute or one method at a time. A method can't be partially overridden, so one long method leaves them only two choices: take it all, or rewrite it all.

So prefer small hook methods:

```
!rooms/generic_room!
parent = "generic/room"

def on_enter(character):
    character.msg(self.format_title(character))

def format_title(character):
    return self.title.upper()

def can_enter(character):
    return True
```

Now a game can change how titles look, or who gets in, in three lines. This is part of what reviewers look at.

Say which methods are meant to be overridden in your `docs/README.md`.

## Testing it

Your scenarios go in `scenarios/`, written like any other [scenario](../scenarios.md), and your fixtures in `scenarios/fixtures/`. Play them with:

```
bin/plugin scenario rooms
```

They run on the engine, your dependencies and your plugin, **without the game's worldlets or any other plugin**. A game's overrides are allowed to change how your plugin behaves, so playing against them would report expected changes as failures. In the same way, a game checks it still behaves as intended with its overrides through its own scenarios, on the full stack.

Check your worldlets with `bin/check`, and try the validation the registry will run:

```
bin/plugin package rooms
```

## Submitting it

Plugins are published through a single GitHub repository, [vincent-lg/pythelix-plugins](https://github.com/vincent-lg/pythelix-plugins). To propose a plugin, or a new version of one, open a pull request adding or updating `plugins/<key>/`.

CI then checks that:

- the manifest parses and its key matches the directory;
- the version is greater than the last published one, and a published version hasn't changed;
- the worldlets pass the checker, on the engine, your dependencies and your plugin;
- your scenarios pass;
- there's a `docs/README.md`, and only `.txt` and `.md` files.

Then a person reads your worldlets. Pythello is sandboxed, but a plugin can still grant powerful commands, so the review matters.

Once merged, CI builds the archive, computes its hash, publishes a release tagged `<key>-v<version>` and updates the index. You never write a hash by hand. To release a change, raise `version` in `plugin.txt`.

If you'd rather check beforehand or send it for review some other way, `plugin package` produces the same archive and its hash.
