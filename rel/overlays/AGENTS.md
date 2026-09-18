# This is a Pythelix game

A **Pythelix** game is a text-based multiplayer game (a MUD). Everything about
the world — its rooms, objects, characters, commands and menus — is described
in text files here, and changed by editing them. The engine itself is not
something you edit.

If the person you are helping is not a programmer, assume they want the game to
do something, not a lesson. Show them the finished thing working, and explain
only the lines that matter.

## Where everything is

| Path | What it is |
|---|---|
| `worldlets/` | The world: rooms, objects, NPCs, commands, menus. **Edit these.** |
| `scenarios/` | Transcripts proving the game behaves as intended. **Edit these.** |
| `docs/` | The documentation. **Read these.** |
| `bin/` | The commands to run — see `bin/AGENTS.md` |
| `lib/`, `releases/`, `erts-*/` | The engine itself. **Never edit.** |

## Read this before writing a single line

**`docs/pythello-for-llms.md`**

Worldlets are scripted in **Pythello**, which looks like Python and is not
Python. Blocks close with `endif` / `done` / `endtry` rather than by
indentation; there are no comprehensions, no lambdas, and no `range()`,
`print()`, `sorted()` or `pass`; and a dict literal needs a space after each
colon (`{"a": 1}`, never `{"a":1}`). That page is the complete list of
differences and takes a minute to read. Writing Python here produces code that
either fails to parse or fails in front of a player.

Then, as the task calls for it: `docs/worldlets.md` and `docs/entities.md` for
the world, `docs/commands.md` for a new command, `docs/methods.md` for
behaviour, `docs/menus.md` for login and character creation,
`docs/ticking.md` for NPCs that act on their own, and `docs/scenarios.md` for
proving any of it.

## The commands

They live in `bin/` and are usually run from there. On Windows use the `.bat`
form of the same name.

| Command | What it does | Needs the game running? |
|---|---|---|
| `bin/check` | Check the worldlets parse, and explain anything wrong | No |
| `bin/scenario` | Play the scenarios and report what didn't hold | No |
| `bin/apply` | Apply the worldlets to the running game | **Yes** |
| `bin/server` | Start the game | — |
| `bin/script` | A Pythello console, for trying one line | **Yes** |

`bin/check` and `bin/scenario` find `worldlets/` and `scenarios/` on their own,
wherever you run them from. Pass a path only to narrow the run. Neither touches
the real game: `check` only reads, and `scenario` plays against a throwaway
copy of the world, so both are safe while the game is live.

## Writing a scenario

A scenario is a transcript. This is the whole vocabulary — no variables, no
conditions, no expressions:

| | |
|---|---|
| `apply <path>` | apply an extra worldlet; the game's own are always applied first |
| `given <Name> in !<key>!` | a player of that name, in that room, logged in |
| `given <n> !<key>! in <where>` | put things somewhere — a room key, or a player's name |
| `connect <Name>` | a client at the login menu, not logged in — for testing menus |
| `<Name>> <input>` | that player types that line |
| `<Name> sees "<text>"` | the text reached them since they last typed |
| `<Name> does not see "<text>"` | it didn't |

```
given Alice in !room/bakery!
given 30 !object/gold_coin! in !room/bakery!

Alice> look
Alice sees "30 gold coins"
Alice does not see "a gold coin"
```

Text is matched anywhere in what the player received, and is case-sensitive.
Several expectations after one input all ask about that same exchange.

**Entities a scenario needs in place** — a locked door, an NPC with three hit
points instead of ten — go in `scenarios/fixtures/` as ordinary worldlets. Files there
are never played as scenarios, and `apply` looks there first, so
`apply goblins.txt` finds them. Two variants of a thing are two named
fixtures: setup belongs in worldlets, behaviour in scenarios.

## How to do a piece of work

1. **Write the scenario first**, in `scenarios/`. Put what was asked for into a
   transcript — it is the request in the requester's own words, and they can
   confirm you understood them without reading any code.
2. **Edit the worldlet** in `worldlets/`.
3. **`bin/check`** — fix anything it reports. It names the rule and the page.
4. **`bin/scenario`** — until it passes. When it fails it shows what the player
   actually saw, which is usually the answer.
5. **`bin/apply`** if the game is running, so the change is live.

Do not report something as working because it parses. `check` says the script
is valid Pythello; only a scenario says the game does what was asked.

## Things that will trip you up

- **`apply` needs a running game.** Without one it says so and does nothing.
  `check` and `scenario` never need one.
- **Worldlets are blueprints, not saves.** Applying one creates or updates the
  entities it describes; it never deletes what it doesn't mention, and player
  accounts live only in the database. Reapplying is always safe.
- **Every entity in a worldlet needs a unique key** — the `!some/key!` line.
- **Changing a worldlet does nothing until it is applied.**
- **Keep scenarios in the transcript vocabulary**, above. It has no variables
  and no conditions on purpose; the full page is
  `docs/scenarios.md`.
