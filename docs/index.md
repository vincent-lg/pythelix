---
title: Pythelix documentation
---

Pythelix is a flexible and dynamic text-based engine for creating multi-user games (`MU*`).

It is built in Elixir, but **ALL** of the game world can be created using Python-like scripting, hence the name.

If you're new to Pythelix and want to learn by doing, [head over to the getting started documentation](./start.md), which will show you how to download, start and build with Pythelix.

## Features

- No programming experience needed to create your world, no matter how extensive.
- [Worldlets](./worldlets.md) are a great way to build alone or in collaboration.
- [Commands](./command.md) are simply [scripts](./scripting.md) written in a friendly, Python-like language that you can learn as you go. [Menus](./menus.md) behave similarly.
- Pythelix is maintaing by a game designer and developer, so that important feature have been considered:

  - [Match](./match.md): how to create commands that work on entities in the room (like other players and objects).
  - [Names](.names.md): how to write entities with specific names depending on who sees them (handling pluralization, invisible players that remain visible to administrators and so on).
  - [Real and game-specific time](./time.md): how to handle real time and game-specific calendars.
  - [Search](./search.md): search entities in the world based on specific criteria (like "find the account with the username XXX").
  - [Stackables](./staclabkes.md): handling entities that appear in great numbers (like gold coin, bills, crafting resources...).
  - [Password management](./password.md): how to handle passwords without storing them in your database.
  - [Prompts](./prompt.md): how to handle a prompt (editing it, disabling it).
  - [Random-string generators](./rangen.md): how to randomly create unique string identifiers (phone numbers, licence plates and so on).
  - [Encoding](./encoding.md): how to handle accented characters in your games.

- The engine itself is extremely fast and can maintain high availability.
- Errors don't crash the server. At worst, they will forward a message to the user (and administrators) that can be easily fixed.
- Maintenance is simple, and there's virtually no need to restart the server (why not keep it running for years or even decades?).
- A web interface and customizable website are provided, in addition to a Telnet connection.

## Installation

Head to the [getting started documentation](./start.md) for detailed instructions about how to install and start Pythelix.
