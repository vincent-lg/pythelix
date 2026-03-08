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

## First login

Your first step is to login to Pythelix. You can use your favorite MUD client, use `localhost` as host name and `4000` as port. Pythelix needs to be running (see the previous sections).

Once you have connected to Pythelix, in your MUD client, you might see something like:

```
  ____        _   _          _ _
 |  _ \ _   _| |_| |__   ___| (_)_  __
 | |_) | | | | __| '_ \ / _ \ | \ \/ /
 |  __/| |_| | |_| | | |  __/ | |>  <
 |_|    \__, |\__|_| |_|\___|_|_/_/\_\
        |___/
        Welcome to the Pythelix Engine
-------------------------------------------------------------------------------
Enter your username or 'new' to create a new one.
```

Pythelix welcomes you with some basic ASCII art. It's not pretty and, of course, can be changed to fit your game. But before diving into building, we need an account. So create one. Enter `new` in your MUD client:

    > new

    Welcome, new user! Enter your new username.

You can create an account with whatever name you want. For this example,w e'll use the name `admin`, but it's definitely not mandatory:

    > admin

    Enter your new account's password.

Choose a password (long is better).

    > MyAdminPassword

    Enter your username or 'new' to create a new one.

This is obviously an example.

We're not back to the initial connection.

Enter `admin` (our username):

    > admin

    Enter the password for this account.

We've chosen `MyAdminPassword` for a password, so let's enter that:

    > MyAdminPassword

    Welcome to Pythelix!

You've created your first account. And because it's the first, Pythelix grants it administrator privileges. So you have access to all the administrator commands. but in Pythelix, there aren't many, because building doesn't happen from your MUD client by default.

