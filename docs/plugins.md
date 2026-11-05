---
title: Plugins
---

A plugin is a package of [worldlets](./worldlets.md) that someone else wrote and maintains, and that your game can install with one command:

```
bin/plugin install rooms
```

(On Windows, `bin\plugin.bat`. From source, `mix pythelix.plugin`.)

Once installed, the plugin's entities (commands, menus, room types, methods) are part of your world as if you had written them. You keep full control: anything a plugin defines can be adjusted from your own worldlets, and the plugin's files stay untouched, so it can be updated later without losing anything.

A plugin is plain text: worldlets and Pythello, nothing else. Installing one never runs Elixir code.

Want to write one? See [writing a plugin](./plugins/authoring.md).

## What comes with your game

Your game already uses two plugins, in the `plugins` directory:

- **base** is what most games start from: the generic entities (`generic/room`, `generic/player`...), the common commands (`look`, `say`, `get`, `help`, `apply`...) and the login menus. Other plugins usually depend on it.
- **farm** is a tutorial zone, teaching how to build by fixing what's broken in it.

Your own worldlets are in `worldlets`. They are loaded last, so they have the last word.

## The commands

None of these need a running server. Those changing plugins only touch files, and end by telling you to run `bin/apply` or restart.

| Command | What it does |
|---|---|
| `plugin list` | online, installed and local plugins, their versions, and whether they were modified |
| `plugin verify [key]` | compare installed plugins with what was installed |
| `plugin install <key>[@version]` | download a plugin and what it depends on |
| `plugin update [key]` | update one plugin, or all of them. `-f` loses your edits to a modified plugin |
| `plugin remove <key>` | delete a plugin. Its entities stay in the database |
| `plugin eject <key>` | make a plugin part of your own worldlets |
| `plugin package <key>` | validate a plugin and build its archive |
| `plugin scenario <key>` | play a plugin's scenarios, in isolation |

## Overriding: same key, nothing else

To change something a plugin defines, declare the entity again in your own worldlets, with the same key, and give only what should change:

```
!farm/room/road!
title = "A Muddy Road"
```

That's the whole mechanism. Attributes and methods are merged one by one, and everything you don't mention is kept. There is no marker to add and no need to repeat `parent`. Overriding a method replaces the whole method, which is why good plugins are written with small methods you can replace one at a time.

Plugins load in order, dependencies first, and your worldlets after all of them: yours always win. And since your overrides aren't in the plugin's files, updating the plugin keeps them.

Use `apply` with no argument after changing an override. Applying only a plugin's directory (`apply plugins/farm`) applies that plugin as written, on top of your world, and your overrides of it stay undone until the next full `apply` or restart.

## Turning a command off

There's no way to remove an entity altogether, because whatever refers to it (children, exits, methods) would break. Visible features can be turned off, though. For a command:

```
!command/emote!
name = None
```

See [commands](./commands.md#turning-a-command-off).

## What "modified" means

`plugins.lock`, at the root of your game, records what was installed, along with a hash of each file. Commit it with your game. If you edit an installed plugin's files directly, Pythelix notices:

```
Plugin rooms was modified in place, and these edits would be lost when it is updated:
  changed: worldlets/room.txt
To change a plugin, override it from your own worldlets (see docs/plugins.md), or take it over with `plugin eject rooms`.
```

You see this when applying, in `check` and in the server's log when it starts. The game still runs: refusing to start over a fixed typo would be worse than the problem. What's refused is `plugin update`, since that's where your edits would be destroyed. Add `-f` if you really mean to lose them.

Line endings don't count, so git's `autocrlf` won't make a plugin look modified.

A directory in `plugins` that isn't in the lock file is a **local plugin**: it's loaded, never hash-checked and never updated. That's the case of `base` and `farm` as they come with your game, and of any plugin you are writing. To get updates for a local plugin that's also published, replace it with `plugin install <key> -f`.

## Taking a plugin over

If you'd rather own a plugin outright, eject it:

```
bin/plugin eject rooms
```

Its parts go where your game keeps such things, and it won't get updates any more:

| From `plugins/rooms/` | To |
|---|---|
| `worldlets/` | `worldlets/rooms/` |
| `scenarios/` | `scenarios/rooms/` |
| `scenarios/fixtures/` | `scenarios/fixtures/rooms/` |
| `docs/` | `docs/plugins/rooms/` |

The manifest goes away, so `!plugin/rooms!` no longer exists after a restart. A plugin others depend on can't be ejected or removed until they are gone.

## Removing a plugin

```
bin/plugin remove rooms
```

The directory and the lock entry go away. The entities it created stay in the database, as with any worldlet you stop using: cleaning up is your call. A [script](./scripting.md) makes that easy.

To be careful, `remove` refuses to delete a modified plugin, or a local one (there's no other copy), unless you add `-f`.

## From Pythello

A plugin's manifest is an entity like another, so code can ask about it:

```
> py !plugin/farm!.version
"1.0.0"
```

It's virtual: it comes from `plugin.txt` at every start, and is never saved.

## Is it safe?

Plugins are text that anyone can read, every published plugin is reviewed by a person, and each carries scenarios showing that it works. Downloads are checked against the hash the registry publishes, and an archive holding anything other than `.txt` and `.md` files, or trying to write outside its directory, is refused before anything is written.

Pythello is sandboxed, but a plugin can still grant powerful commands. If that matters to you, read what you install: `plugin.txt` and the `worldlets` directory are all there is.

## When something doesn't load

These stop the world from applying, and name every problem at once, in the server's log, in `apply` and in `check`:

- a plugin needs another that isn't installed;
- the versions don't fit, or the plugin needs another version of Pythelix;
- plugins depend on each other in a circle;
- a manifest can't be read.

`PLUGINS_PATH` in your [settings](./settings.md) says where plugins are, if not in `plugins`.
