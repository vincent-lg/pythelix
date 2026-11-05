# Why is the default login menu like this in Pythelix?

Pythelix gives you some basic [worldlets](../worldlets.md) (files that describe the default world). You can (and should!) modify them. but to modify them, you need to understand them first. So let's see what they do.

We'll focus mostly on the `worldlets/emnu.txt` file in this document.

<details markdown="1">
<summary>I cannot find the "worldlets" directory, where is it?</summary>

If you have downloaded an archive (a .tar.gz file or .zip file), the `worldlets` directory should be right inside of it, next to the `bin` directory.

If you are running from source, the `worldlets` folder is right at the root of the project, like `lib` or `assets`.
</details>

## The login process, in summary

Before diving into the file, you should at least know what it does:

- When you first login (with a MUD client) to the game (`localhost:4000`), you see the MOTD (Message Of The Day) screen.
- You're then asked to enter a username or `new` to create one.
- If you enter a valid username :

  - You're asked to enter the accout's password.
  - If it's valid :

    - You're asked to connect or create a new character.

  - If the password isn't valid, you're asked to try again in 3 seconds.

- If you enter `new` instead, you can create a new account with its password.

The default login is supposed to be simple and easy to customize. Not too complex that you would have to fight against it to dismantle it (a very common occurrence in gamedesining with a game engine), but with enough feature to be the base of your future game.

Still, it has to make an assertion, and this one is important:

**Accounts** are not **players**. In fact, Pythelix assumes several separations:

1. The account is where your username and password is stored. It's where you have settings on all your players most likely, where you can store an email address or whatever else makes sense.
2. An account has, by default, many players. In fact, the first time you create an account, you're instructed to create the first character in this account. By default, players just have a name (so your account can hold several players).
3. Pythelix uses the generic character to represent any character. The player is to be understood as a Player-Character (it's a form of player with a connection). Non-Playing-Characters (NPCs) are characters too. Think of a character which can be either a player or a NPC. That's how Pythelix makes the distinction. Most things will sit on character, because they will be common to players and NPCs.

These are design choices. If you're unhappy with them, remember: nothing prevents you from changing any of them. Pythelix had to choose a default approach. It's not the only one. It's not beter in all cases. It's definitely not necessarily the best for your game. Youre are the one to decide.

On the other hand, you have to understand these choices: not to adopt them, but to know how to come up with a better implementation that fits your game and design.

The most common question at this point is:

> But I don't want to separate accounts and players. Players should have a username, password and can log into the game and play. Let it be simple.

We'll comeback to the question at the end of the document, because it's not a simple one and, again, better to understand what exists before dismantling it.

## First login

Pythelix offers the concept of [menus](../menus.md). Menus are entities (virtual entities to be precise, so they're not stored in your database). Each menu entity describes a step in the connection process.

All menus have been grouped in `plugins/base/worldlets/menu.txt`. You can, of course, adopt a different strategy (put them in a directory).

First of all: how does Pythelix know what to do when a client connects to `localhost:4000`:

It calls a menu. but which menu? By default, Pythelix tries to find a menu with a key of `menu/motd` (Message Of The Day).

And at the top of your `plugins/base/worldlets/menu.txt` file, you should see it:

```
!menu/motd!
parent = "generic/menu"
text = """
  ____        _   _          _ _
 |  _ \ _   _| |_| |__   ___| (_)_  __
 | |_) | | | | __| '_ \ / _ \ | \ \/ /
 |  __/| |_| | |_| | | |  __/ | |>  <
 |_|    \__, |\__|_| |_|\___|_|_/_/\_\
        |___/

        Welcome to the Pythelix Engine
-------------------------------------------------------------------------------
"""
```

First, let's notice the key of the menu, `menu/motd`. This is the one automatically called by Pythelix when a new connection occurs.

The parent of the entity, like all [menus](../menus.md) is `"generic/menu"`.

The `text` attribute contains the text of the menu: each menu can have a text and a promp.

The text is displayed when the user enters the menu. The prompt (if present) id displayed after the text, and also after every message the user receives while in the menu.

> Why a prompt?

It can serve as a reminder. "Enter your username". And that would appear below every message received during the menu.

But during the login process, I've found that prompts are more noise than very useful. This is a choice, nothing prevents your from defining a `prompt` attribute containing a string.

So the `text` attribute contains a multiline string (you can see the triple double-quotes). The text contains ASCII art. This is what greets new clients when they connect to `localhost:4000`.

As a matter of fact, let's look farther, because our entity isn't fullyd escribed just yet:

```
!menu/motd!
parent = "generic/menu"
text = """
  ____        _   _          _ _
 |  _ \ _   _| |_| |__   ___| (_)_  __
 | |_) | | | | __| '_ \ / _ \ | \ \/ /
 |  __/| |_| | |_| | | |  __/ | |>  <
 |_|    \__, |\__|_| |_|\___|_|_/_/\_\
        |___/

        Welcome to the Pythelix Engine
-------------------------------------------------------------------------------
"""

def enter(client):
    client.location = !menu/username!
```

We also have an `enter` method defined on this menu. This method is called automatically when a connection enters this menu (again, the default behavior).

Our `enter`  method might look strange:

```
def enter(client):
    client.location = !menu/username!
```

It takes the client and... alter its location?

A menu doesn't sit anywhere: a client alays contains a menu. When a new connection occurs, a client entity is created. It's location is set to `menu/motd`. Changing `client.location` will effectively change the menu where the client is.

In this context: we want the client, once it has entered `menu/motd`, to change menu... right away, for `menu/username`.

It means, as soon as the client connects, it enters `menu/motd` and then changes to `menu/username`.

So `menu/motd` is just a step in the process and not even blocking.

> Why this choice?

The `menu/username` menu is meant to either accept a username or `new`. The MOTD is meant to display the Message Of The Day. These are two distinct features so they've been kept in different menus. This won't be the last we see of this strategy, but it might make more sense later.

## Entering a username or NEW

The `menu/username` menu looks pretty simple in terms of attributes:

```
!menu/username!
parent = "generic/menu"
text = """
Enter your username or 'new' to create a new one.
"""
```

Again, some text but no prompt.

But things get interesting with its only method:

```
def unknown_input(client, input):
    account = search.one(!generic/account!, username=input.strip().lower())

    if account:
        client.account = account
        client.location = !menu/password!
    else:
        client.msg(f"The username {input} doesn't exist. Want to create one? Enter NEW.")
    endif
```

Menus are, of course, not only here to display nice text. They're also here to process input from the user.

In this context, we need to do something when the user enters something.

The `unknown_input` method is usually the right way to do it.

> Why unknown?

The method is called `unknown_input`, because it checks all commands in the menu and only handles input that doesn't match any command. We'll soon this behavior in action.

The command looks a bit complicated, so let's examine it step by step:

- First notice the command signature (the parameters it accepts). Here, the client and the input.
- Next, we use `search.one` to see if there is any account with the criteria we specify. This could be translated as: get any entity, child of `!generic/account!`, whichh has an attribute `username` matching the enter input (lowercased). We'll see how accounts are created in a future menu. But for the being, note `search.one`. It tries to find an entity, child of a given entity but with matching attributes. This is usually the way to find entities in Pythelix.
- If we found an account, we store it in the client (we'll need it later) and move the client to the `!menu/password!`.
- Otherwise, we display a useful error message: there is no account with that name. If the client wants to create it, they should use the `new` command.

> A `nnew` command? Where is it?

It's just below in the worldlet:

```
!command/username/new!
parent = "generic/command"
location = "menu/username"
name = "new"

def run(client):
    client.location = !menu/new/username!
```

Commands are a bit like menus: they inherit from a geniric entity (`generic/command` in this case) and their behavior is controlled by methods (`run` in most cases). The `run` method is called when the command is used by the client (in other words, when the client enters `new`).

Notice that the command's location is set to the menu as well (`location = "menu/username"`). This is important, because most commands are defined in the game menu (so accessible when the player is logged in). If not, we need to set `location` explicitly. And of course, the `new` command will only be active as long as the user is inside `menu/username`.

To recap:

Inside the `menu/username`, the client can:

- Enter `new`, it will fire a command and move the client inside `!menu/new/username!` (we'll see that one later, it's a new account).
- Enter anything else. In this case, we call `uknknown_input` with the entered input, check that this is indeed an account. If so, move to `menu/password`. If not, display a helpful message.

## Entering the account's password

Next, let's look at `menu/password`. By then, you may be familiar with the syntax and inner workings:

```
!menu/password!
parent = "generic/menu"
text = """
Enter the password for this account.
"""

def unknown_input(client, input):
    account = client.account

    if account.password.verify(input):
        client.location = !menu/account!
    else:
        client.location = !menu/invalid/password!
    endif
```

The attributes shouldn't be too surprising.

The method is the same: `unknown_input`. But the code might look quite cryptic:

- First, what is `client.account`? This attribute has been created in the previous menu (`menu/username`) and holds, as you might remember, the account to which we're trying to login.
- And `account.password`? Now, it's an attribute we haven't seen yet. What does it hold?

In Pythelix, passwords are handled separately. You could store the password directly in a string attribute, and then, `account.password` would containg something like `mySecretPassword`. And the code would probably look like:

```
if account.password == input:
    # They match
endif
```

When it comes to password, this isn't a great idea. It would then store the password in the database. You could read any player's password and take over their account and change their password.

> But I'm an administrator, why would I do that?

Who knows? Even if you have no harmful intent, your trusted builders might not have the same goal in mind. Authorize even one builder to run arbitrary Pythello code and sooner or  later, one of them will still the passwords of other accounts (yes, including your own) and wreck havoc on the game.

But in any case, storing a raw password isn't a great security practice.

So to solve these situations, Pythelix has added the `password` module. Using it from Pythello is quite simple: to create a masked password, use the `password.hash` function:

    py password.hash("myTopSecretPassword")

You can enter this command from an administrator account.

And you should see something like:

    <Password using "pbkdf2">

The `password.hash` function takes a clear password and returns a hashed version. Pythello doesn't display a hashed version, it just displays the algorithm that was used (your password has been turned into a quite long mix of letters and digits).

> Hm, but how do I turned it back to plain text?

You don't. You call the same algorithm to know if it would produce the same long mix of letters and digits.

In fact, Pythello offers you a method, `verify`, on the password object: it accepts a plain password and tells you if the hashed password matches the clear password.

Let's look at this in a Pythello console. Again, from an administrator account, you can enter:

    py secret = password.hash("SecretPassword")

This creates a new variable, you can check it from your console:

    py secret

But its real interest is that it has a `verify` method:

    py secret.verify("something else")

This should displays:

    False

The string to be verified `"something else"` didn't match the original password `SecretPassword`.

But if you enter:

    py secret.verify("SecretPassword")

You'll see:

    True

The hash and the verified passwords are the same.

Back to our `unknown_input` method. You might now understand what it does:

```
def unknown_input(client, input):
    account = client.account

    if account.password.verify(input):
        client.location = !menu/account!
    else:
        client.location = !menu/invalid/password!
    endif
```

1. It gets the stored account.
2. It checks an attribute `password` on the account. We can infer it contains a hashed password. It calls its `verify` method with the input.
3. If it matches: the client entered the right password, proceed to `menu/account`.
4. If not, redirect to another menu, `menu/invalid/password`.

We'll be able to connect the dots when we examine `menu/new/password` in particular.

## Wrong password? Try again.

Next is the `menu/invalid/password` menu. We redirect to it if the user entered the wrong password to connect to the selected account. By then, you should be able to follow its logic:

!menu/invalid/password!
parent = "generic/menu"
text = """
Invalid password. Wait before retrying...
"""

def enter(client):
    wait 3
    client.location = !menu/password!

def unknown_input(client, _input):
    client.msg("Wait a bit...")
```

The attributes aren't surprising.

There are two methods:

- `enter`: called when the user enters the menu (so right away, when we execute `client.location = !menu/invalid/password`);
