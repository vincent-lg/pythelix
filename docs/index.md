Pythelix is a flexible and dynamic text-based engine to create multi-user games (`MU*`).

It is built in Elixir, but **ALL** of the game world can be created with Python-like scripting, hence the name.

## Features

- No programming experience needed to create your world, however extended ;
- Commands are just scripts written in a friendly, Python-like language that you can learn as you go ;
- The game world can be defined in ["woldlets"](./worldlet.md), small files describing your universe and helps replication and collaboration with builders ;
- The engine itself is extremely fast and can maintain a high availability ;
- Errors don't crash the server. At worst, they indicate an error to the user (and administrators) that can easily be fixed ;
- Maintenance is simple enough and there's virtually no need to restart the server (why not keep it running for a few years or decades?).
