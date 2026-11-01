---
title: Scenarios
---

A scenario says what should happen when someone plays, written the way it looks in a MUD client:

```
given Alice in !room/bakery!
given Bob in !room/bakery!

Alice> say is anyone here
Alice sees "is anyone here"
Bob sees "is anyone here"
```

Run it:

```
mix pythello.scenario
```

```
  ok    scenarios/bakery.txt (10 steps)

1 scenario passed.
```

Scenarios live in a `scenarios` directory next to your `worldlets` one, as `.txt` files. Subdirectories are read too, so you can group them as you like.

In a release, use `bin/scenario` (or `bin\scenario.bat` on Windows) instead. It works the same way and with no argument reads the `scenarios` directory shipped beside `worldlets`, exactly as `bin/apply` does. Point it elsewhere with the `SCENARIOS_PATH` environment variable, or give it a file or directory:

```
bin/scenario
bin/scenario scenarios/harvest.txt
bin/scenario scenarios/quests
```

## Writing them on Windows

Scenario files are read the same way worldlets are, so your editor's defaults don't matter:

- **Line endings** — CRLF, LF or a lone CR all work. A file saved by Notepad behaves exactly like one saved on Linux.
- **Encoding** — UTF-8 is read as UTF-8. If a file isn't valid UTF-8, it is decoded using `WORLDLETS_ENCODING` from your [settings file](./settings.md) (one of `utf-8`, `iso-8859-1`, `iso-8859-15` or `cp1252`; when empty, the players' `DEFAULT_ENCODING`), so an accented character typed in a Latin-1 editor still matches the accented character in your game. The scenario runner tells you when a file needed that fallback. A UTF-8 byte-order mark is ignored rather than becoming part of the first line.

## Why bother

[Checking a worldlet](./pythello-for-llms.md#checking-before-applying) tells you your script is valid Pythello. It cannot tell you the quest works, that the door is locked to the right people, or that the whisper stayed private. Those are questions about *behavior*, and the only honest way to answer them is to play.

A scenario is a description of playing that the computer can carry out for you. Three things fall out of that:

- **You write it before the code.** "When Alice harvests, Bob should see her do it" is a sentence you already have in your head when you start. Writing it down first means you know when you're finished.
- **It reads like the game, not like a test.** You can hand a scenario to someone who has never programmed, and they can tell you whether it describes what they wanted. That is not true of the worldlet.
- **It keeps being true.** Six months later, when you change how rooms announce things, the scenario tells you which of your fifty quests you just broke.

## The constructs

That is the whole language. There are no variables, no conditions and no expressions — on purpose. A scenario you can't read at a glance isn't doing its job.

### `apply <path>`

Apply a worldlet file or directory before playing:

```
apply worldlets/farm
```

Optional and repeatable. **Your game's own worldlets are always applied first**, so you never `apply` the thing you are testing — only extra worldlets.

The path is resolved inside `scenarios/fixtures/` first, so `apply combat/goblins.txt` finds `scenarios/fixtures/combat/goblins.txt`. Otherwise it is resolved against your game's root — so `apply worldlets/farm` means the same thing whether you run the command from the game directory or from inside `bin`.

### `given <Name> in !<key>!`

A player of that name, in that room, already logged in:

```
given Alice in !farm/room/field!
```

Names are ordinary words — `Alice`, `Bob`, `guard_captain`. The player is built the way your login menus build one, then handed to `menu/near_game`, so if you change how players enter the world, scenarios follow.

### `connect <Name>`

A client that has just connected, sitting in whatever menu greets people — not logged in, with no character yet:

```
connect Newcomer
Newcomer sees "Enter your username"

Newcomer> new
Newcomer sees "Enter your new username"
```

This is how you test the menus themselves: logging in, creating an account, choosing a name. Use `given` when the menus are not what you're testing.

### `given <count> !<prototype>! in <somewhere>`

Put things in the world. `<somewhere>` is an entity key, or a player's name to mean their inventory:

```
given !object/sword! in !room/bakery!
given 30 !object/gold_coin! in !room/bakery!
given 5 !object/gold_coin! in Alice
```

The count is optional and defaults to one. A prototype marked `stackable = True` becomes a single stack of that many; anything else becomes that many copies. Which one it is is the prototype's business — a scenario says "30 gold coins", not how they are stored.

Told apart from a player by the key: `given Alice in !room/a!` is a person, `given !object/x! in !room/a!` is a thing.

### `<Name>> <input>`

That player types that line, exactly as they would:

```
Alice> harvest wheat
Alice> say hello, everyone
```

This goes through the same code the telnet server uses, so exits, channels, command matching and menus all behave normally.

### `<Name> sees "<text>"` and `<Name> does not see "<text>"`

What reached them since they last typed:

```
Alice sees "You harvest a bundle of wheat."
Bob sees "Alice bends down and harvests some wheat."
Bob does not see "You harvest"
```

The text is matched **anywhere** in what they received, so a scenario survives a prompt, a colour code, or a reworded sentence around the part you care about. Matching is case-sensitive: `Alice sees "command not found"` will not match `Command not found.`

`does not see` is worth as much as `sees`. Whispers that stay private, invisible administrators, the item that shouldn't appear in a room description — those are all things only a negative can check.

Every expectation after one input asks about that same exchange, so you can write as many as you like:

```
Alice> look
Alice sees "A bakery"
Alice sees "Obvious exits: south."
Alice does not see "Bob"
```

Lines starting with `#` are comments. Blank lines are ignored and can be used to separate phases of the scenario.

## Fixtures

A scenario often needs something in place before it can play: a locked door, an NPC with three hit points rather than ten, a quest already half finished. Those are entities, so they belong in a worldlet — but one that must not reach the real game.

Put them in `scenarios/fixtures/`. Files there are **never played as scenarios**, and are applied only by the scenarios that ask for them:

```
# scenarios/fixtures/goblins.txt

!test/weak_goblin!
parent = "npc/goblin"
hp = 3
location = "room/cave"
```

```
# scenarios/combat.txt

apply goblins.txt

given Alice in !room/cave!

Alice> hit goblin
Alice sees "The goblin collapses."
```

Two variants of the same thing are two fixtures — `!test/weak_goblin!` and `!test/tough_goblin!`. That is deliberate: a name says what the fixture is *for*, where `hp = 3` written inside a transcript would not, and it keeps setup in the format built for it. Setup lives in worldlets; behaviour lives in scenarios.

## What happens when one fails

```
  FAIL  scenarios/harvest.txt
  5  Alice sees "a bundle of wheat"
    Alice did not see it
    received:
      | You reach for the wheat, but your hands are full.
```

The point is the last part. Knowing Alice didn't see what you expected is half an answer; seeing what she *did* see is usually the whole one.

Playing continues past a failure, so one wrong line doesn't hide the other four.

## Isolation

Every scenario gets a world of its own: a fresh database that is thrown away afterwards, an empty cache, and your worldlets applied from scratch. Scenarios can create, break and destroy anything, in any order, without affecting each other or any real game. Nothing you run here can touch your live database.

## Where to go next

- [Worldlets](./worldlets.md) — the files that describe your world
- [Commands](./commands.md) — what players can type
- [Pythello for Python programmers](./pythello-for-llms.md) — the scripting language, and `mix pythello.check`
