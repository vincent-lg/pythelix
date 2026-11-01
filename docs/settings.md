---
title: The settings file
---

A Pythelix game is configured by one file: `settings.txt`, at the root of your game, next to the `worldlets` directory. It is a plain text file, meant to be opened and edited in Notepad or any other editor.

Pythelix generates it the first time it starts (the server, `check` or `scenario` all do), with every setting present, its default value and a comment saying what it does. You never need to write it from scratch.

## What goes in it

The settings file only holds what the engine needs **before** it reads your worldlets: where the files are, which ports to listen on, how files and players are encoded, and the keys of the generic entities. Everything about how the game *behaves* belongs in a [worldlet](./worldlets.md), where you have methods and inheritance.

## The format

```
# A comment.
NAME=value
```

- One setting per line, written as `NAME=value`. Spaces around the `=` don't matter.
- Lines starting with `#` are comments. Blank lines are ignored.
- Changes take effect the next time the server starts.
- An environment variable with the same name overrides the line in the file. This is for deployment scripts; most games never need it.
- Relative paths are relative to the directory holding the file.

The file is read the same way worldlets are, so CRLF line endings, a byte-order mark or a Windows encoding won't break it.

## The settings

| Setting | Default | What it does |
|---|---|---|
| `DATABASE_PATH` | `pythelix.db` | The SQLite database holding the game. |
| `WORLDLETS_PATH` | `worldlets` | The directory of [worldlets](./worldlets.md). |
| `SCENARIOS_PATH` | `scenarios` | The directory of [scenarios](./scenarios.md). |
| `TASKS_PATH` | `tasks` | Where persistent tasks are stored. |
| `TELNET_PORT` | `4000` | The port players connect to with a MUD client. |
| `WEB_PORT` | `8000` | The port the web server listens on. |
| `DEFAULT_ENCODING` | `utf-8` | The [encoding](./encoding.md) a player's client is assumed to use when it connects. |
| `WORLDLETS_ENCODING` | *(empty)* | How a worldlet or scenario file is read when it isn't valid UTF-8 (see below). Empty means "the same as `DEFAULT_ENCODING`". |
| `GENERIC_CLIENT` | `generic/client` | The key of the entity every client inherits from. |
| `GENERIC_CHARACTER` | `generic/character` | The key of the entity every character inherits from. |
| `GENERIC_MENU` | `generic/menu` | The key of the entity every menu inherits from. |
| `GENERIC_COMMAND` | `generic/command` | The key of the entity every command inherits from. |
| `GENERIC_RANGEN` | `generic/rangen` | The key of the entity every [random-string generator](./rangen.md) inherits from. |
| `GENERIC_CALENDAR` | `generic/calendar` | The key of the entity every [calendar](./time.md) inherits from. |
| `SECRET_KEY_BASE` | *(generated)* | The secret the web server signs its cookies with. Keep it private. |

Supported encodings are `utf-8`, `iso-8859-1`, `iso-8859-15` and `cp1252`. The server refuses to start if an encoding setting is anything else, and says so.

## How worldlet files are read

Every worldlet and scenario file is tried as UTF-8 first. UTF-8 is strict about which bytes can follow which, so a file saved by an editor in a Windows encoding fails on its first accented character instead of being read as nonsense. Only then is the file decoded with `WORLDLETS_ENCODING`. The decision is made file by file, so one builder's editor doesn't have to agree with another's.

When a file needed that fallback, `apply` and `check` say so:

```
worldlets\room.txt is not UTF-8 and was read as cp1252. Save it as UTF-8 so that it reads the same everywhere.
Worldlet applied from ...\worldlets: 34 entities were added or updated.
```

The worldlet works either way. The notice is there so you learn that your editor is saving in the wrong encoding, rather than discover it the day you move the files to another machine.

## Running from source

When you run Pythelix from source with `mix` (in development or in the tests), `settings.txt` is not used: the values come from `config/config.exs`, and only the environment variables apply.
