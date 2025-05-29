Pythelix is a flexible and dynamic text-based engine for creating multi-user games (`MU*`).

It is built in Elixir, but **ALL** of the game world can be created using Python-like scripting, hence the name.

## Features

- No programming experience needed to create your world, no matter how extensive.
- [Commands](./command.md) are simply [scripts](./scripting.md) written in a friendly, Python-like language that you can learn as you go.
- The game world can be defined in ["worldlets"](./worldlet.md), small files that describe your universe and facilitate replication and collaboration with builders.
- Built-in support for game features: [menus](./menus.md), optional prompts, configurable help, random string generator, stackables.
- The engine itself is extremely fast and can maintain high availability.
- Errors don't crash the server. At worst, they will forward a message to the user (and administrators) that can be easily fixed.
- Maintenance is simple, and there's virtually no need to restart the server (why not keep it running for years or even decades?).
- And if you really, absolutely need to restart your game engine, it won't disconnect any user.
- A web interface and customizable website are provided, in addition to a Telnet connection.

## Installation

Using Pythelix is easy: either run one of the binaries for your operating system, or run it directly from the source.

- [Download Pythelix for Linux x64](https://github.com/vincent-lg/pythelix/releases/download/latest-linux/pythelix-linux.tar.gz)
- [Download Pythelix for Windows x64](https://github.com/vincent-lg/pythelix/releases/download/latest-windows/pythelix-windows.zip)

Decompress the builds and execute `bin/migrate` (`bin\migrate.bat` on Windows), then `bin/server` (`bin\server.bat` on Windows) to start the server.

For more information, follow the steps in the [installation documentation](./installing.md).
