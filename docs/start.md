---
title: Getting started with Pythelix
---

Pythelix is a text-based game engine. It can be used to create your own text-based game (MUD, or Multi-User Dungeon). It is meant to be flexible and easy to use.

This page assumes no prior knowledge about Pythelix. You don't have to do anything or install anything before reading. If you've never worked with Pythelix before, it might be worth following the steps described here one at a time. The best way to learn is by doing.

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

You can create an account with whatever name you want. For this example, we'll use the name `admin`, but it's definitely not mandatory:

    > admin

    Enter your new account's password.

Choose a password (long is better).

    > MyAdminPassword

    Enter your username or 'new' to create a new one.

This is obviously an example.

We're now back to the initial connection.

Enter `admin` (our username):

    > admin

    Enter the password for this account.

We've chosen `MyAdminPassword` for a password, so let's enter that:

    > MyAdminPassword

    Welcome back!
    A bakery
       The warm, inviting scent of freshly baked bread and sweet pastries fills
    the air upon entering this cozy little shop. A fine dusting of flour clings
    lightly to the wooden floorboards and countertops. Shelves and display
    cases brim with golden-baked goodsâloaves of crusty bread, delicate
    pastries, and confections in all shapes and sizes. Icing glistens under
    soft lighting, while nuts, berries, and chocolate chips adorn many of the
    treats with artistic precision.
       At the back of the shop, an antique wooden cash register rests atop a
    counter, its brass details dulled slightly with age and use.

You've created your first account. And because it's the first, Pythelix grants it administrator privileges. Don't expect too many admin commands, though — in Pythelix, most building happens outside the MUD client.

## Administration, first glance at Pythelix concepts

First, let's see the commands we have access as administrator:

```
> help
General
  look           quit
Information
  help
Administrator
  pythello       system
```

The output can of course be different. The important point though is that... there aren't many commands. Especially administrator commands. We have two:

- pythello: run Pythello code ;
- system: see system information.

You can run the system command. It gives quite technical details about the Pythelix system currently running. This information can become useful to debug or make sure the server isn't drowning under a lot of players.

But the most important, of course, is the pythello command.

Pythelix has its own scripting language. Its name is Pythello. It looks a lot like Python, but isn't exactly the same — Pythello is tailored for game scripting, with built-in support for entities, references, and game-specific features. If you don't know Python syntax, no worries: we'll explain things with examples, which is often the best way to learn.

To start with: you need to enter the pythello command (you can write it as `py`) followed by some code. Something very simple for the first test:

```
> py 35 * 4
140
```

Incredibly impressive, I know. You entered some Pythello code (`35 * 4`) and the engine responded with 140.

Of course, we can do many powerful things with Pythello, but the principle will be the same: we enter the command with code and see the result in answer.

### Entities

Pythelix uses two important concepts: one is [entities](./entities.md).

An entity in Pythelix is a piece of the world or the gameplay. A room is an entity. A NPC is an entity. A character is an entity. So are more surprising things, like menus, commands... and even clients (individual connections). If you are familiar with LambdaMOO, you can think of entities as objects: they have pretty much the same behavior, though the term entities has been chosen to avoid confusion.

That might sound a bit abstract, so let's make it more practical. In your MUD client, you can type:

```
> py self
Entity(id=13)
```

`self` is just a variable containing our player (the one who calls `py`). In this example we see `self` is the entity of ID 13. IDs are unique numbers (no two entities can have the same ID). Here, our player is the entity of ID 13 (this number might be quite different for you).

Let's see another example: I said rooms are entities too. So let's see the room where the player stands:

```
> py location
!room/bakery!
```

`location` is another variable always accessible in the `pythello` command. It contains the player's location (in this case, the room).

The result is a bit different: we don't see the ID, but something between exclamation marks. This something is the entity key. An entity can have a key (a unique string, containing letters and other characters). In this very case, the location has a key of `room/bakery`.

> Why is it useful to have both IDs and keys?

As we'll see later, there are entities that don't have IDs. Just a key. And entities need a key when they are created by the building system (we'll see why shortly).

The important thing to remember:

- Entities can have an ID (a number)
- Entities can have a key (a string of letters or other characters).
- IDs and keys are unique (no two entities can have the same ID or key).

> Can entities have both IDs and keys?

Yes. Our location displays its key, but it also has an ID:

```
> py location.id
3
```

We can access attributes with the syntax `entity.ATTRIBUTE_NAME`. `id` is a special attribute on all entities: it contains the entity ID. In our example, we see that the room has key `room/bakery` but also ID of 3. So it's not impossible (or even uncommon) for entities to have both.

Let's examine the concept more closely with worldlets.

### Worldlets

A [worldlet](./worldlets.md) is just a file (a text file). It specifies the entities that should always be present. Maybe you didn't wonder where the `room/bakery` entity came from: the answer is from a worldlet.

Specifically: open the `worldlets` directory.

<details markdown="1">
<summary>I cannot find the "worldlets" directory, where is it?</summary>

If you have downloaded an archive (a .tar.gz file or .zip file), the `worldlets` directory should be right inside of it, next to the `bin` directory.

If you are running from source, the `worldlets` folder is right at the root of the project, like `lib` or `assets`.
</details>

Inside the directory, you should find many text files. You can open any of them. But right now, let's open the `room.txt` file. At the top, you should see our bakery:

```
!room/bakery!
parent = "generic/room"
title = "A bakery"
description = Description("""
The warm, inviting scent of freshly baked bread and sweet pastries fills
the air upon entering this cozy little shop. A fine dusting of flour clings
lightly to the wooden floorboards and countertops. Shelves and display cases
brim with golden-baked goods—loaves of crusty bread, delicate pastries,
and confections in all shapes and sizes. Icing glistens under soft lighting,
while nuts, berries, and chocolate chips adorn many of the treats with artistic
precision.

At the back of the shop, an antique wooden cash register rests
atop a counter, its brass details dulled slightly with age and use.
""")
```

You probably recognize our entity. It's a blueprint: when Pythelix starts, it will read all worldlets from the directory and create them in game or update them (if they already exists). So this is not where the entity is stored: this is just what created the entity in the first place.

The first line, `!room/bakery!`, shows the entity key. All entities in a worldlet need a key.

The next lines define attributes in this entity: `parent`, `title`, `description`. Their definition is pretty close to the way a variable is created.

Let's not worry about `parent` right now. Let's first see `title`. As you can guess, this is the title of the room. You can access it in the same way, from Pythello:

```
> py location.title
"A bakery"
```

The client answers with a title (surrounded by double-quotes to indicate it is a string). Attributes can be of different types. In this case, it's a string. It can be a number or something else entirely, like a list or dictionary.

Notice something important: the worldlet doesn't define the ID. It just defines the key. When this entity is first created in the game, it can obtain an ID which will never change as long as the entity exists.

The important thing to remember: all entities defined in worldlets have to have a key. It should always be unique (one key per entity). It's not possible to define an entity without a key inside of a worldlet.

> But then... it means that our player wasn't in any worldlet?

No, worldlets don't define everything. It wouldn't make sense to store players in worldlets for instance: a player is created in game. It doesn't have a key, only an ID.

> But then, why are keys useful?

You have noticed a typo in the description of the bakery. Or you just want to modify it. In Pythelix, the best way to do that is to modify the worldlet file (room.txt). And then, either restart the game or apply the worldlet. What happens? Pythelix will browse the list of worldlets, will see a room with key of `room/bakery`, will say "hey, I know this one, it has been saved under ID 3, let's see if anything has changed", it will notice the description has indeed changed and refresh entity of ID 3 in-game. It won't create it again because it already has an entity of this key.

To illustrate, let's modify the title of the entity. In `worldlets/room.txt`, modify this line:

    title = "A bakery"

Replace it with:

    title = "A brightly-lit bakery"

Save the file. Nothing should happen. From your MUD client, if you query the title attribute:

```
> py location.title
"A bakery"
```

... that's the old value. Now let's apply. From the MUD client, you can call the `apply()` function:

```
> py apply()
"Worldlet applied from ...\\pythelix\\worldlets: 34 entities were added or updated."
> py location.title
"A brightly-lit bakery"
```

The entity has been updated. You can query its ID and notice it's still the same:

```
> py location.id
3
```

So we have the same room (same entity with the same key and ID). It has been updated by the worldlet.

Again, remember: a worldlet file is just a blueprint of entities. It's not a storage. You define entities within it and they will be created or updated depending on whether an entity of a given key already exists in game.

This is also the reason why two entities cannot have the same key: since the worldlet uses unique keys, it will get confused and update an entity which has the same key. So keep keys unique, one per entity. By default, we use the convention of writing a key of `<entity type>/<entity identifier>`. By all means, you can follow a completely different system as long as entities have unique keys.

### Modifying entities from the game

As we've seen, it's quite simple to modify entities in worldlets: just modify the text file, save it, and execute the `apply()` function.

But you might be wondering: can I modify the entity from the game, with the `py` command?

The answer is yes: but you should be extremely careful. If we modify the title from the game (entering something like this):

```
> py location.title = "a new title"
```

Then the change will work (you can type `look` to make sure).

But what happens next time the worldlet is applied?

Well, it will see an entity with key `room/bakery`, but a different title, so it will update it. In other words, the worldlet will always override the entity.

So it's best to do any modification in the worldlet. As long, of course, as the entity is present in the worldlet to begin with. As said above, not all entities are present in the worldlet: the players, the accounts, the clients themselves are never stored in worldlets.

### Parentage

You may have noticed the `parent` attribute in the bakery worldlet:

    parent = "generic/room"

This tells Pythelix that our bakery *inherits* from the entity with key `generic/room`. In practice, this means the bakery automatically gets all the attributes and methods defined on `generic/room` — unless it overrides them with its own values.

The chain can go further: a parent can itself have a parent. Attributes and methods are looked up along this chain — Pythelix checks the entity first, then its parent, then the parent's parent, and so on, until it finds a match.

You can see this at work with commands. Open `worldlets/command.txt`. Near the top, you'll find:

```
!generic/char_command!
parent = "generic/command"
```

This entity is a "generic character command" — a parent for all commands available to characters. It inherits from `generic/command` (an even more basic entity). Further down, you'll see:

```
!command/look!
parent = "generic/char_command"
name = "look"
aliases = ["l"]
category = "General"
```

The `look` command inherits from `generic/char_command`, which itself inherits from `generic/command`. That's three levels of parentage. The `look` command doesn't need to redefine everything from scratch — it only specifies what's unique to it (its name, aliases, category) and inherits the rest.

> Can an entity have multiple parents?

No. Each entity has at most one parent. This is a deliberate design choice to keep things simple and predictable.

### Methods

So far, we've only looked at attributes (data stored on entities). But entities can also have *methods* — these define behavior.

Let's create a fun command to see methods in action. We'll add a `roll` command that rolls a die with a random result. Open `worldlets/command.txt` and add the following at the end of the file:

```
!command/roll!
parent = "generic/char_command"
name = "roll"
category = "General"

def run(character):
    result = random.randint(1, 6)
    if result == 1:
        character.msg("You roll... a 1. Ouch. The dice gods are not with you today.")
    elif result == 6:
        character.msg("You roll a 6! Critical luck! You feel unstoppable.")
    else:
        character.msg(f"You roll a {result}. Not bad, not great.")
    endif
```

Let's break this down:

- `!command/roll!` is the entity key.
- `parent = "generic/char_command"` means this command inherits from the generic character command — so any character can use it.
- `name = "roll"` is the command name that players will type.
- `category = "General"` determines where it appears in the `help` output.

Then comes the method:

- `def run(character):` defines a method called `run`. This is the method Pythelix calls when a player types the command. It receives `character` — the player who typed it.
- `random.randint(1, 6)` picks a random number between 1 and 6.
- `character.msg(...)` sends a message to the player.
- `if`, `elif`, `else`, `endif` work much like in Python (except for `endif` which closes the block, since Pythello doesn't use indentation for blocks).

Save the file and apply the worldlet:

```
> py apply()
```

Now you can test your new command:

```
> roll
You roll a 4. Not bad, not great.
> roll
You roll a 6! Critical luck! You feel unstoppable.
```

Try it a few times — you'll get different results each time. You should also see the `roll` command when you type `help`.

This is the general pattern for adding behavior in Pythelix: define an entity in a worldlet, add methods to it, apply, and test. Methods are inherited just like attributes: if you define a parent command with shared behavior, all child commands get it for free. You only override what needs to be different.

To learn more about methods (arguments, type hints, return types, default values), see the [methods documentation](./methods.md).

## Where to go from here?

You've learned how to start the Pythelix server, how to modify and add entities (rooms and commands in particular), how to manipulate attributes and methods. The good news is: most of Pythelix uses these very concepts.

So you have enough knowledge to pick a particular topic that interests you. Each topic assumes you have read this guide, so understanding what entities, worldlets, attributes, methods and inheritance means is critical.

Explore one of these tutorials freely, in the order you like:

- [All about commands](./commands.md): learn to add a command and handle common use cases (commands with arguments, commands that pause...).
- [Read more about entities](./entitiess.md): a more thorough explanation about entities including some less-known concepts (virtual entities, sub-entities...).
- [Read more about worldlets](./worldlets.md): a more detailed explanation of worldlets syntax for curiosity's sake.
- [Understanding methods and nested method calls](/methods.md): examples to better understand how methods work and what their role is.
- [Adding custom messages depending on who views the player](./names.md): learn how to have entity names (like player names) that are different depending on who views them.
- [Understanding menus](./menus.md): how to add, update and extend the login menus or in-game menus.
- [Creating, changing, removing the prompt](./prompt.md): learn how to customize the prompt (the line that appears under every message).
- [Matching and searching](./match.md): learn how to search in a room or in the entire world using simple methods.
- [Using game modes to handle parallel game environments](./modes.md): learn about game modes and how to use them to have several in-game menus opened at the same time (useful, in particular for builders).
- [Manipulating real and game-specific time](./time.md): learn how to handle real time and game-specific time.
- [Stackable entities for coins, bills, crafting resources](./stackables.md): learn how to handle entities that are meant to be stacked in great quantity (not unique), particularly useful for coins.
- [Randomly-generated strings for realism](./rangen.md): learn how to use rangen to create random phone numbers, licence plates, Social security fake codes and so on.
- [Handling passwords safely](./password.md): learn how to manipulate passwords safely to avoid storing them directly in your entities.
- [Understanding client and client controllers](./controls.md): learn about the transition between client (a connection) and a character (the controller).
- [Altering encoding for a client](./encoding.md): learn how to alter the way accented characters appear for a single connection or for everyone (useful for some games using a non-English world).
