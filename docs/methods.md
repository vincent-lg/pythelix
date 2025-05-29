Methods define behavior (what to do when something happens). [Entities](./entities.md) can have one or more methods. For most entities, these methods are defined in [worldlets](./worldlets.md).

## Basic syntax

Inside a [worldlet](./worldlets.md), a method is set in an entity like this:

```
[entity key]
attribute1: value1
attribute2: value2

{method name}
method code
on several
lines
```

All it takes is to create a method by writing a line with braces (`{method name}`), followed by the method code. The code itself, written in [Pythello](./scripting.md), is the behavior associated with this method.

We'll use the same example throughout this documentation: a method that simply displays a message to the client. It's a simple example, but it illustrates the power of methods.

## An animal entity

Let's begin by defining an entity representing an animal:

You can copy this code into your [worldlet](./worldlets.md) files. If you're not sure how to do that (or how to apply them), refer to the [documentation about worldlets](./worldlets.md).

```
[animal]
height: None
weight: None

{call}
client.msg("The animal calls... don't know what.")
```

We create an entity with the key `"animal"` and two attributes: height and weight, both set to `None`. Then we define a method named `call` with a single line: it just sends a generic message to the client.

> What does the client contain?

If you're used to programming, you might wonder: where does the `client` variable come from? Usually, it would be defined in the method arguments. Here it just magically appears. We'll see where it actually comes from shortly.

Apply this worldlet. Start a server (click `start.bat` or enter `mix run`), then enter a scripting session (click `script.bat` or enter `mix script`). You should see something like:

```
Starting interactive script. Press CTRL+C twice to exit.
>>>
```

Before entering anything, open a MUD client and connect to the server. We'll assume it's our very first connection (the server isn't exposed to anyone but you).

First, let's get your client: clients, like most things in Pythelix, are entities. To retrieve it, enter the key of the entity. Clients are always called `client/1`, `client/2`, `client/3`, and so on (depending on how many clients connect). So our connected client would be `client/1`. You can type in your script console:

```
client = !client/1!
```

And that's it. You now have a variable containing your client. Believe it or not. Try to send it something:

```
client.msg("Great!")
```

If you paste this line inside your scripting console, you shouldn't see anything. But if you go back to your MUD client, you should see the message.

You're not impressed, I see. Let's retrieve the `animal` entity and try to call its method:

```
animal = !animal!
```

That wasn't that complicated. You now have another variable set to our entity with the key `animal`. You can try to see its weight:

```
animal.weight
```

The result is not impressive because we set these to `None`, which isn't even displayed.

Let's call our `call` method:

```
animal.call()
```

Before seeing the result, note the syntax: the variable, a dot, the method name (`call` here), and arguments between parentheses. We have no argument, but we still need to include empty parentheses.

Now for the result:

```
>>> animal.call()
Traceback most recent call last:
  <stdin>, line 1
    animal.call()
  !animal!, method call, line 1
    client.msg("The animal calls... don't know what.")

NameError: name 'client' is not defined
>>>
```

A traceback? All that for an error?

Don't go away! The error is quite explicit and logical, as you can see in the traceback. Here, the first (and only) line in our method tries to find the `client` variable. It cannot. Not surprising: we didn't give it the client (we have a variable `client` in the scripting environment, but it is not magically transmitted to methods).

Okay, let's try again but be smarter:

```
animal.call(client=client)
```

This time, the console displays nothing (except for the three `>>>` prompts). In our client, however, we've received the message:

```
The animal calls... don't know what.
```

What's the difference? When we called our method, we specified a keyword argument (`keyword=value`). This creates a variable in our method named `client`, which is exactly what the method needs.

> Why isn't the `client` variable magically transmitted to our method?

At first glance, it might seem odd to require explicitly passing variables. But when you have tens or hundreds of method calls, if each had to guess its variables (and could modify them), your life would become complicated. This choice aligns with Python too, where methods have a specific scope and arguments must be transmitted explicitly.

Note: For advanced Python developers, it's partially true that references could be handled by the method and mutate the calling scope, and that closures exist. But it's best to keep scopes separate.

> Okay, I see why I need to send the client to the method, but why can't I just do something like:

```
animal.call(client)
```

That's a good question. Short answer: you can. But we need to dive into arguments. Nothing too complicated, don't worry.

## Method arguments

You might want to play with our method: what happens if we send it a `client` containing not a client, but a string?

```
>>> animal.call(client="ok")
Traceback most recent call last:
  <stdin>, line 1
    animal.call(client="ok")
  !animal!, method call, line 1
    client.msg("The animal calls... don't know what.")

AttributeError: 'string' object has no attribute 'msg'
>>>
```

The error is a bit strange. It tries to find `msg` on a string and, of course, fails. Thanks to a good traceback. But it could be made more explicit.

Our `call` method should take one and only one argument: the client. To enforce that, we simply update our method definition in our worldlet. Replace it with these lines:

```
[animal]
height: None
weight: None

{call(client)}
client.msg("The animal calls... don't know what.")
```

We just modified the method definition. Now, between parentheses after the method name, we add the arguments. Here we have one: `client`. We could of course have several, separated by commas.

You can apply this change by saving the worldlet file and executing in your scripting console the `apply()` function:

    apply()

No need to restart the server or even disconnect any player.

```
animal.call(client)
```

Upon executing the third line, you should see the text displayed in your MUD client.

We specified that the command takes exactly one argument: `client`. Now, if you try to call it with more or fewer arguments, it will fail clearly:

```
>>> animal.call()
Traceback most recent call last:
  <stdin>, line 1
    animal.call()

TypeError: expected positional argument client
>>>
```

Or if you enter more:

```
>>> animal.call(1, 2, 3)
Traceback most recent call last:
  <stdin>, line 1
    animal.call(1, 2, 3)

TypeError: expected at most 1 argument, got 3
>>>
```

## Typed arguments

But you can still do something like `animal.call("ok")`. Nothing prevents you from doing it. You'll get an error later, but this doesn't make it obvious what went wrong.

Enter type hints: they're called type hints (or annotations) because that's the name in Python. In Pythelix, they're not mandatory (you can omit them), but if you specify them, that's a contract. A type hint is set after the argument name followed by a colon (and a space for readability). For example:

```
{add(a: int, b: int)}
```

In our case, we want to make sure the first argument is a client.

Clients are entities. Every client has a parent of `generic/client`. So we need to enforce that the first argument inherits (directly or indirectly) from `generic/client`. Doing so is simple, especially if you're used to type hints in Python:

```
{call(client: Entity["generic/client"])}
```

The syntax might look a bit strange at first: the type hint contains the class name (`Entity` with a capital `E`), followed by square brackets, with the entity key as a string, then a closing bracket.

Pythelix will make sure:

1. The first argument is an entity.
2. The first argument inherits from `generic/client`.

Here's our new method (only the method part is shown, not the full entity):

```
{call(client: Entity["generic/client"])}
client.msg("The animal calls... don't know what.")
```

If you apply it (use the `apply()` function in your Pythello console) and try again:

```
>>> animal.call(5)
Traceback most recent call last:
  <stdin>, line 1
    animal.call(5)

TypeError: argument client expects value of type entity inheriting from "generic/client"
>>> client = !client/1!
>>> animal.call(client)
>>>
```

## Should you use type hints?

You can definitely skip type hints or use the bare minimum (just a signature like before). But there are advantages to using type hints:

- They make debugging easier if something goes wrong.
- They make error messages more explicit.
- They provide safety if someone (another builder, or even you) tries to use your methods incorrectly.

For these reasons, it's highly recommended to use type hints as much as possible. Typing them might take slightly more time but can save much time when debugging.

## Type hints and commands

You might remember: in Pythelix, [commands are entities](./entities.md). The command behavior (the code executed when the command is called) is defined by methods. The most common method for commands is `run`, followed by `refine`, which is less used. Both methods take the parsed arguments as method arguments. So, if you have a command syntax like:

```
<object> from <source>
```

... you'll get `object` and `source` as arguments.

Should you use type hints? It might sound silly to type-hint information which is automatically sent to your command by Pythelix.

But type hints can be useful here, too: if your command syntax changes and you forget to update the `run` method (yes, it happens), they will warn you or, at the very least, provide a useful error message if things go wrong. So while type hints on command methods might sound less useful, they can help. Using them is, as always, your choice.
