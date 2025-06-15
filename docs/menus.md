In Pythelix, menus are used to define "what the player can do." They are especially useful during login (although commands can also be used, menu-based login experiences are more common). Menus remain useful even after the user has logged in.

## Menus display and receive text

When a player connects, they usually receive a welcome message along with the Message of the Day (MOTD). From there, they may enter their username and password. Menus serve two main purposes:

1. Display information, like, the Message Of The Day, instructions to create a strong password, text to reset a lost password, and so on.
2. Handle user text input.

A menu represents a step in the user experience.

- When the user logs in, they will start in the MOTD (Message Of The Day) menu.
- If they enter a username, assuming it exists, they will move to the menu where they can log into that account.
- When they enter text, it is assumed to be their password, which is checked against the stored password.
- Finally, if all goes well, the user is logged in and can enter commands to fully enjoy the game.

Clients move from menu to menu. We often think of this as a sequence of actions. But things can go wrong at several points along this "happy path." It is important to keep the user informed about why a certain step isn't working (e.g., if the password is incorrect).

In Pythelix, a menu has a clear responsibility and a defined set of possible actions.

Like most things, menus are [entities](./entities.md). They are defined in [worldlets](./worldlets.md). Updating them is very easy—just modify a file and reapply the worldlet (or restart the server). So, rather than elaborate further, let's see them in action.

### Menus are virtual entities

Here's a very simple Message Of The Day (MOTD) menu:

```
[menu/motd]
parent: "generic/menu"
text: """
Welcome to this AWESOME MUD!!!
We hope you have fun.
                                     Powered by Pythelix.
"""
```

It looks simple. Note:

- The menu key (`menu/motd`) usually doesn't matter. It matters here because when a player connects, they are automatically placed inside this menu. This can be configured; it's just the default.
- The `parent` is very important: `generic/menu`. Like with [commands](./commands.md), a menu should always inherit from `generic/menu` (this entity is automatically created by Pythelix).
- The only other attribute is `text`. `text` is the bare minimum: it contains the text displayed when the client is placed inside this menu (this happens automatically when a client connects to the MUD).

This menu simply displays a basic welcome text. It's straightforward but not very interactive.

Let's move on to our next menu.

### Moving between menus

It becomes more interesting when multiple menus exist. Let's create another menu with contact information:

```
[menu/contact]
parent: "generic/menu"
text: """
Don't hesitate to contact us if you have any questions, if you cannot connect
to your account, or if you just want to say hi.
Email contact@myveryownmud.com
"""
```

Now we need to connect the two menus. The most common approach is to intercept client input while inside the MOTD menu. If the input matches something, we can change the client's menu. Here's our two menus fleshed out a bit:

```
[menu/motd]
parent: "generic/menu"
text: """
Welcome to this AWESOME MUD!!!
We hope you have fun.
Type CONTACT to contact us.
                                     Powered by Pythelix.
"""

{input(client, input)}
if input.lower() == "contact":
    client.location = !menu/contact!
else:
    client.msg("That's not a valid command.")
endif

[menu/contact]
parent: "generic/menu"
text: """
Don't hesitate to contact us if you have any questions, if you cannot connect
to your account, or if you just want to say hi.
Email contact@myveryownmud.com
Press ENTER to close this menu.
"""

{input(client, _input)}
client.location = !menu/motd!
```

For both menus, we redefine the `input` method. This method is called every time the client sends some text while inside this menu. It takes two arguments: the client and the input text (notice the method definition).

Our first menu (`menu/motd`) redirects to `menu/contact` if the client enters "contact." Otherwise, it provides a helpful message. Our `menu/contact` menu will, regardless of input, return to the previous menu.

Notice that we specify two arguments in our input methods (we call them `client` and `input`, but that's our choice). The second menu actually asks for `_input` (with an underscore) because we don't really need this method. This is just a convention and by no means an obligation. Both methods, regardless, takes two arguments and that's what you should focus on.

Note that in order to change the "current menu for this client", we only update `client.location`. This might seem unusual at first, but a client should always be inside a menu (and can move between menus by changing its `location`).

You can apply this worldlet and then connect to the server. You should see the MOTD text. If you type "contact", you will see the contact information (notice that the menu text is automatically displayed when we switch menus). If you type anything else (or just press RETURN), you will go back to the MOTD.

`input` is one very common method overridden in most menus. It is commonly used to intercept user input at the menu level.

### Menus and commands

If you have read [the documentation about commands](./commands.md), you might wonder where commands fit: why create commands if all input can be intercepted by the menu?

Commands provide capabilities that menus alone do not. A command is usually defined inside a menu (the command's `location` can be set to a different menu). By default, all commands are defined inside the `menu/game` menu, which is special: this is the menu where players arrive after logging in (after entering their username and password). However, commands can be assigned to different menus:

```
[command/motd/contact]
parent: "generic/command"
location: "menu/motd"
name: "contact"

{run(client)}
client.location = !menu/contact!
```

We have created a `contact` command in our `menu/motd` menu. You can now remove the `input` method from `menu/motd` because the command handles input to redirect the client to another menu when the user enters `contact`.

> How about the `menu/contact` menu? Can we define a command to go back to the MOTD menu?

You can, but in this case, we want to go back regardless of what the user entered. So it makes more sense to define an `input` method inside our `menu/contact` menu rather than a command.

> **WARNING:** Remember, commands, like all entities, should have unique keys. In our example, we used `command/motd/contact`. The idea is to avoid conflicts with other commands defined in other menus (whose keys should also be unique). By including the menu address in the command key, we help ensure uniqueness.

### Conflicts between menus and commands

Menus and commands can work together. By default, if an `input` method exists for the menu, it is called when the user sends input. Otherwise, the engine looks for a matching command. But what happens if both `input` and commands exist in the menu? The `input` method will be called, and commands will be ignored.

There are several ways to address this:

- Instead of overriding `input`, override `unknown_input`. This method is called when no command matches the entered input. It can provide a "catch-all" error message when no command is found.
- To override commands defined inside the menu, you can override `input`. Then you can return `False` to let the engine know that `input` did not handle the input (so commands should be checked), or `True` to indicate that input was handled and the engine should not check commands.

Let's see an example illustrating why this strategy is useful. We'll focus on the menu used to enter a username. The user can enter `new` to create a new account, or enter an existing username to connect. `new` is a command (best to define it in the menu). But what if the user enters a valid username? We could handle that in `unknown_input`, which will be called if the command does not match. But consider this alternative approach:

```
[menu/username]
text = """
If you have an existing account, enter its username.
If not, you can enter 'new' to create a new account.
"""

{input}
account = search.one(!account!, username=text.lower())
if account:
    client.account = account
    client.location = !menu/password!
    return True
else:
    return False
endif

{unknown_input}
client.msg("The provided username doesn't exist, try again.")
```

This menu is a bit more involved, so let's break it down:

1. The menu key and text require little explanation at this point.
2. We override the `input` method.
3. It checks whether the entered text corresponds to an account (we won't discuss `search.one(...)` here, but for more info, see [the search module documentation](./module/search.md)).
4. If it finds an account, it assigns it to the client, moves the client to the `menu/password` menu, and returns `True`.
5. If no account is found, it returns `False`.
6. We also override `unknown_input` to provide a better error message.

When the user enters something in this menu:

- First, `input` is called. If it returns `True` (i.e., if the account exists), input has been handled.
- If `input` returns `False` (i.e., no matching account), the engine will try commands in this menu (such as the `new` command).
- If no command matches, it will call `unknown_input`, which displays an error message.

This design allows you to execute code before and after commands. While this example may not be the absolute best solution for this specific need (simply overriding `unknown_input` to perform the search may be better), it demonstrates the flexibility and power of menus working together with commands.

## Menu attributes and methods

### Attributes

| Attribute    | Type        | Description |
| ------------ | ----------- | ----------- |
| `text`       | string      | The text to be displayed when a client enters this menu. Can be omitted if the `get_text` method exists. |
| `prompt`     | String      | The text to send to the client below other messages while the user is inside of this menu. Empty by default. Can be overridden with the `get_prompt` method. |

The prompt is a line of text that will appear below a message sent to the client. Messages will be grouped though, so if you have a method doing this:

    client.msg("First message")
    client.msg("Second message")

The client would receive something like:

    First message
    Second message
    Menu prompt if defined.

The menu prompt can be used to remind users what to enter, but it should preferably be a short line. Menu don't have to have a prompt.

> Do you mean, if I want to display the health point of the player in a traditional point?

Yes, this is a menu prompt in Pythelix too, because `menu/game` is a menu, `prompt` (or the `get_prompt` method) is called and can be overridden to show a prompt to the user. But it can also be used during login to "remind" users what to do (`prompt = "* Enter your username :"`).

### Methods

| Method          | Arguments                               | Description |
| --------------- | --------------------------------------- | ----------- |
| `input`         | `client, text`                          | Intercept user input from the client while inside of this menu. |
| `unknown_input` | `client, text`                          | Intercept user input from the client while inside of this menu, if no command on that menu matched the input. |
| `get_text`      | `client`                                | Provide custom text in the menu for this client. Overrides the `text` attribute. |
| `get_prompt`    | `client`                                | Provide custom prompt in the menu for this client. Overrides the `prompt` attribute. |
| `enter`         | `client`                                | When the client enters this menu. |
| `leave`         | `client`                                | When the client leaves this menu. |

> The `enter` method is particularly useful if a menu has to redirect to another menu right away (before any input is entered). The MOTD menu is usually short-lived, it just displays the MOTD and redirects to another menu.
