---
title: Getting started with Pythelix
---

Pythelix is a text-based game engine. It can be used to create your own text-based game (MUD, or Multi-User Dungeon). It is meant to be flexible and easy to use.

This page assumes no prior knowledge about Pythelix. You don't have to do anything or install anything before reading. If you've never worked with Pythelix before, it might be worth following the steps described here one at a time. Doing is everything.

## Downloading Pythelix

Pythelix offers binary versions for ease-of-use: you don't have to install a programming language. Just download an archive.

<details markdown="1">
<summary>Show instructions for Windows (x64)</summary>

First, [download Pythelix for Windows x64](https://github.com/vincent-lg/pythelix/releases/download/latest-windows/pythelix-windows.zip) .

This is just a ZIP archive. When downloaded, extract it somewhere.

The archive contains several directories, like `bin`, `lib`, `release`, `worldlets`. We'll see them later. For now, go into `bin`.

This directory contains several files to start the game. You can:

1. Double-click on the `.bat` file (we'll see which one). That's simple. The drawback is, you might not see the result.
2. Open a console (recommended): in the explorer's address bar, enter `cmd` and press RETURN. This will open a command line inside this folder. You can, of course, start the command differently and `cd` into the `bin` folder in a different way. Then you could run the `.bat` scripts by typing their names. That might be better because you would see the result of the operation.

In any case:

1. First, run `migrate.bat`: this script runs the database migrations. If you check in the parent directory, you might see a file called `pythelix.db`. This is your database (you don't need to open it).
2. Then, start the game, by running `pythelix.bat`. This should start the server. You should see several messages to indicate the server has started.

Now you can open your favorite MUD client (zMUD, VIPMud, CocoMUD...) and connect to hostname `localhost`, port 4000.

You should see the welcome message for Pythelix.

To shutdown the server, just go back to the console where you started `pythelix.bat` and press CTRL + C twice (maybe three times on Windows, depending).

</details>

<details markdown="1">
<summary>Show instructions for Linux (x64)</summary>

First, [download Pythelix for Linux x64](https://github.com/vincent-lg/pythelix/releases/download/latest-linux/pythelix-linux.tar.gz) .

    wget https://github.com/vincent-lg/pythelix/releases/download/latest-linux/pythelix-linux.tar.gz

This is just a TAR archive. When downloaded, extract it somewhere.

    tar -xzf pythelix-linux.tar.gz

The archive contains several directories, like `bin`, `lib`, `release`, `worldlets`. We'll see them later. For now, go into `bin`.

    cd bin

This directory contains several files to start the game.

1. First, run `./migrate`: this script runs the database migrations. If you check in the parent directory, you might see a file called `pythelix.db`. This is your database (you don't need to open it).
2. Then, start the game, by running `./pythelix`. This should start the server. You should see several messages to indicate the server has started.

Now you can open your favorite MUD client (Telnet, TinTin++...) and connect to hostname `localhost`, port 4000.

    telnet localhost 4000

You should see the welcome message for Pythelix.

To shutdown the server, just go back to the console where you started `./pythelix` and press CTRL + C twice.

</details>

<details markdown="1">
<summary>Show instructions for other platforms</summary>

If you are not running a x64 version of Windows or Linux, you would need to install Pythelix from source. This is not hard but you'll need to [install Elixir](https://elixir-lang.org/install.html) on your system. Choose a recent version of Elixir and OTP.

To download the code, you can use Git:

    git clone https://github.com/vincent-lg/pythelix.git

Then you can `cd` and perform the usual command for an Elixir project:

    cd pythelix
    mix deps.get
    mix ecto.create
    mix ecto.migrate

And finally, start the server:

    ./dev

On Windows, there's also `dev.bat`.

This will start the server. You can connect your MUD client to `localhost` port 4000.

If you want to open IEX to debug, use `./devex` or `devex.bat`.

</details>
