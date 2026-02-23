---
title: Client Control in Pythelix
---

In Pythelix, a **client** is the [entity](./entities.md) that represents a network connection. When a player connects, a client entity is created automatically. But a client is not a character: the client is the connection, while the character is the in-game persona. Connecting the two is called **client control**, and it is both possible and preferable to set up.

## Why use client control?

Without client control, all your [commands](./commands.md) and [menus](./menus.md) receive the `client` entity as their first argument. This means all game state (inventory, location, health, etc.) would have to live on the client entity itself. But clients are temporary: they are created when a player connects and destroyed when they disconnect.

In short: you need to store some data. Clients aren't the place to do that, unless this is very temporary data, lost at disconnection.

By connecting a client to a character entity, you gain several advantages:

- **Persistent state**: The character entity is stored in the database and persists across connections. A player can disconnect and reconnect later, and their character retains all its attributes.
- **Separation of concerns**: The client handles the connection (sending and receiving text), while the character holds game state (location, inventory, stats, etc.).
- **Multi-client support**: Multiple clients can potentially control the same character (useful for testing or multiboxing).
- **Cleaner methods**: Commands and menus receive the character as their first argument, so you can write `{run(character)}` and work directly with the game entity.

First, a clarification: we talk a lot about characters. You can come up with another system entirely. The important part is to connect a client with an entity. Which entity is your choice. It could be a vehicle, a room or anything you fancy. But it usually is a character, so that's what this documentation describes. If you have another working approach though, adaptation is quite simple.

## How it works

Client control relies on two mechanisms:

1. **`client.owner`**: Associates the client with a single entity (usually a character).
2. **`client.controls`**: A `Controls` object that tracks which entities this client can influence.

When a client has an owner, Pythelix passes the **owner entity** (not the client) as the first positional argument to command `run`/`refine` methods and menu `input`/`unknown_input` methods. This is why you can write `{run(character)}` in your commands and receive the character directly.

> Why the two mechanisms with owner and controls?

The owner is used on input: what to do when a client sends a command (like `get 3 apples`). By default, Pythellix will run the command as the owned entity (the entity associated with this client). And a client can only own one entity at a time. This is important.

The client controls are called for output: when you want to send a message to the entity (the character), it looks for the client controlling it. There can be several clients, so it sends the message to all of them.

The owner works on input, the controls on output.

This system was adopted to handle most use cases: if a builder wants to take control of a non-playing character, for instance: the client will own the builder. Client commands are sent to the builder (which then decides to run them on the NPC). However, the NPC becomes a control for this client: messages sent to this NPC will be sent to the builder's client. Along with message sent to the builder. This sounds more advanced and will become clearer with examples.

## Setting up client control

The typical place to connect a client to a character is during login, after verifying the player's credentials. Here is the relevant excerpt from the menu [worldlet](./worldlets.md) example (found in the `worldlets/` directory):

```
[menu/password]
parent: "generic/menu"
text: """
Enter the password for this account.
"""

{input(client, input)}
account = client.account
if account.password.verify(input):
    character = account.character
    client.msg("Login successful")
    client.owner = account.character
    client.controls.add(account.character)
    client.location = !menu/game!
else:
    client.location = !menu/invalid/password!
endif
```

The connection happens in two steps:

1. **`client.owner = account.character`**: Sets the client's owner to the character entity. This tells Pythelix that this client "is" this character. From this point on, commands and menus will receive the character as their first argument instead of the client.
2. **`client.controls.add(account.character)`**: Adds the character to the client's control set. This is used by `clients.controlling()` (see below) to find which clients are controlling a given entity.

Both steps are needed. Setting the owner changes what entity is passed to methods. Adding to controls allows reverse lookups (finding which clients control a character).

After that, `client.location = !menu/game!` moves the client to the game menu where commands are available.

## Sending messages to a character

Once a client controls a character, you need a way to send text from the character back to the client. After all, only the client can actually display text to the player.

The `clients.controlling()` function returns all clients currently controlling a given entity. The character [worldlet](./worldlets.md) example uses this to define a `msg` method on the character:

```
[generic/character]
{msg(self, text)}
for client in clients.controlling(self):
    client.msg(text)
done
```

With this method, any code can call `character.msg("some text")` and the message is automatically routed to whatever client(s) currently control that character. This is the recommended pattern: define `msg` on your character entity so that other code does not need to know about clients.

## Using character in commands

Once client control is set up, your commands can declare `character` (or any name you choose) as their first argument. Pythelix will pass the owner entity instead of the client:

```
[command/system]
parent: "generic/command"
name: "system"

{run(character)}
character.msg(f"You are connected as {character.key}.")
```

This works because Pythelix checks whether the client has an owner. If it does, the owner is passed as the first positional argument to the command's methods. If not, the client itself is passed (as described in the [commands documentation](./commands.md)).

The same applies to menu methods like `input` and `unknown_input`. When a client has an owner, those methods receive the owner entity as their first argument.

## The `clients` module

The `clients` module provides functions to query active clients:

| Function                         | Description |
| -------------------------------- | ----------- |
| `clients.active()`               | Returns a list of all currently connected clients. |
| `clients.controlling(entity)`    | Returns a list of all clients whose `controls` set contains the given entity. |
| `clients.owning(entity)`         | Returns the client whose `owner` is the given entity, or `None` if no client owns it. |

`clients.controlling()` is the one you will use most often, typically inside a character's `msg` method as shown above.

`clients.owning()` is useful when you need to find the specific client that "owns" a character (for example, to disconnect them or change their menu location).
