Pythelix is a flexible and dynamic text-based engine to create multi-user games (`MU*`).

It is built in Elixir, but **ALL** of the game world can be created with Python-like scripting, hence the name.

## Features

- No programming experience needed to create your world, however extended.
- [Commands](./command.md) is just [scripts](./scripting.md) written in a friendly, Python-like language that you can learn as you go.
- The game world can be defined in ["woldlets"](./worldlet.md), small files describing your universe and helps replication and collaboration with builders.
- Builtin support for game features: [menus](./menus.md), optional prompts, configured help, random string generator, stackables.
- The engine itself is extremely fast and can maintain a high availability.
- Errors don't crash the server. At worst, they will forward a message to the user (and administrators) that can easily be fixed.
- Maintenance is simple enough and there's virtually no need to restart the server (why not keep it running for a few years or decades?).
- And if you really, absolutely need to restart your game engine, it won't disconnect any user.
- A web interface and customizable websie is provided in addition to a Telnet connection.

## Installation

Using Pythelix is easy: either run from one of the binaries for your operating system, or directly from source. Follow the steps in the [installing documentation](./installing.md).
