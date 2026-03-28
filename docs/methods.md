---
title: Methods in Pythelix
---

Methods define behavior (what to do when something happens). [Entities](./entities.md) can have one or more methods. For most entities, these methods are defined in [worldlets](./worldlets.md).

## Basic syntax

Inside a [worldlet](./worldlets.md), a method is set in an entity like this:

```
!entity key!
attribute1 = value1

def method_name(arg1, arg2):
    method code
    on several lines
```

A method starts with the `def` keyword, followed by the method name, its arguments in parentheses, and a colon. The code itself, written in [Pythello](./scripting.md), is the behavior associated with this method.

We'll use the same example throughout this documentation: NPCs (non-player characters) that greet a player. It's a simple example, but it illustrates the power of methods and inheritance.

## A simple NPC entity

Let's begin by defining an entity representing a generic NPC:

You can copy this code into your [worldlet](./worldlets.md) files. If you're not sure how to do that (or how to apply them), refer to the [documentation about worldlets](./worldlets.md). It is advised to simply write a file `npc.txt` inside of your worldlets directory.

```
!generic/npc!

def greet(character):
    character.msg("A stranger looks at you and nods silently.")
```

We create an entity with the key `"generic/npc"` and define a method named `greet` with one argument: `character`. The method sends a message to the character.

Apply this worldlet. Start a server and connect your MUD client (see [Getting started](./start.md) for how to do that). Once logged in, you can test the method using the `py` command:

```
> py npc = !generic/npc!
> py npc.greet(self)
```

Note the syntax: the variable, a dot, the method name (`greet` here), and arguments between parentheses.

In your MUD client, you should see:

```
A stranger looks at you and nods silently.
```

`self` is your character (always available in the `py` command). We passed it as the `character` argument, so `character.msg(...)` sends the message to us.

What happens if we call the method with no argument?

```
> py npc.greet()
Traceback most recent call last:
  <stdin>, line 1
    npc.greet()

TypeError: expected positional argument character
```

Pythelix tells us explicitly: the method expects a `character` argument. Same thing if we pass too many:

```
> py npc.greet(1, 2, 3)
Traceback most recent call last:
  <stdin>, line 1
    npc.greet(1, 2, 3)

TypeError: expected at most 1 arguments, got 3
```

## Accessing the entity with self

Our NPC sends a fixed message. But what if the NPC should introduce itself by name? For that, the method needs to access the entity it belongs to. This is what `self` does when used as the first argument of a method:

```
!generic/npc!
name = "stranger"

def greet(self, character):
    character.msg(f"{self.name} says: Hello, traveler.")
```

When you call `npc.greet(my_character)`, Pythelix sets `self` to the NPC entity and `character` to whatever you pass. You still only pass one argument — `self` is filled in automatically:

```
> py npc = !generic/npc!
> py npc.greet(self)
```

In your MUD client:

```
stranger says: Hello, traveler.
```

> Why is `self` special?

When `self` is the first argument in a method definition, Pythelix automatically passes the entity the method belongs to. You don't include it yourself when calling the method — it's filled in for you. This is the same convention as Python's instance methods.

> Wait, `self` was my character before — now it's the NPC?

Don't confuse the two: in the `py` command, `self` is a special variable that always refers to your character. In a method definition, `self` as the first argument means "the entity this method belongs to". They share the same name by convention, but they live in different scopes.

## Typed arguments

You can still do something like `npc.greet("oops")`. Nothing prevents you from passing a string instead of a character. You'll get an error further down the line, but it won't be obvious what went wrong.

Enter type hints: they're called type hints (or annotations) because that's the name in Python. In Pythelix, they're not mandatory (you can omit them), but if you specify them, that's a contract. A type hint is set after the argument name, followed by a colon (and a space for readability). For example:

```
def add(a: int, b: int):
```

In our case, we want to make sure the argument is a character. Characters are entities. Every character has a parent of `generic/character`. So we need to enforce that the argument inherits (directly or indirectly) from `generic/character`. Doing so is simple, especially if you're used to type hints in Python:

```
def greet(self, character: Entity["generic/character"]):
```

The syntax might look a bit strange at first: the type hint contains the class name (`Entity` with a capital `E`), followed by square brackets, with the entity key as a string, then a closing bracket.

Pythelix will make sure:

1. The argument is an entity.
2. The argument inherits from `generic/character`.

Here's our updated method:

```
!generic/npc!
name = "stranger"

def greet(self, character: Entity["generic/character"]):
    character.msg(f"{self.name} says: Hello, traveler.")
```

If you apply it and try passing the wrong type:

```
> py npc = !generic/npc!
> py npc.greet(5)
Traceback most recent call last:
  <stdin>, line 1
    npc.greet(5)

TypeError: argument character expects value of type entity inheriting from "generic/character"
```

With `self` (our character, which inherits from `generic/character`), the call succeeds as expected.

## Should you use type hints?

You can definitely skip type hints or use the bare minimum. But there are advantages to using type hints:

- They make debugging easier if something goes wrong.
- They make error messages more explicit.
- They provide safety if someone (another builder, or even you) tries to use your methods incorrectly.

For these reasons, it's highly recommended to use type hints as much as possible. Typing them might take slightly more time but can save much time when debugging.

## Inheritance

So far, our generic NPC sends the same greeting to every character. But different NPCs should behave differently: a merchant should welcome customers, a guard should be stern.

This is where inheritance shines. Let's create a merchant NPC:

```
!npc/merchant!
parent = "generic/npc"
name = "merchant"

def greet(self, character: Entity["generic/character"]):
    character.msg(f"{self.name} says: Welcome! Care to browse my wares?")
```

The merchant inherits from `generic/npc` (via `parent = "generic/npc"`). It overrides two things: the `name` attribute and the `greet` method.

Apply and test:

```
> py merchant = !npc/merchant!
> py merchant.greet(self)
```

You see:

```
merchant says: Welcome! Care to browse my wares?
```

And the generic NPC still works as before:

```
> py npc = !generic/npc!
> py npc.greet(self)
```

```
stranger says: Hello, traveler.
```

Same method name, different behavior — that's the power of method overriding.

## Chain of calls

In practice, you'll often want shared behavior in the parent with only small differences in children. Rather than copying the entire method, you can split the behavior: one method handles the shared logic and calls another method that each child can override.

Let's refactor. The generic NPC will have two methods: `greet` handles the common logic (formatting and sending the message), while `greeting` returns the text itself:

```
!generic/npc!
name = "stranger"

def greet(self, character: Entity["generic/character"]):
    character.msg(f"{self.name} says: {self.greeting()}")

def greeting(self):
    return "Hello, traveler."
```

Now the merchant only needs to override `greeting` — it inherits `greet` from the parent for free:

```
!npc/merchant!
parent = "generic/npc"
name = "merchant"

def greeting(self):
    return "Welcome! Care to browse my wares?"
```

We can add a guard just as easily:

```
!npc/guard!
parent = "generic/npc"
name = "guard"

def greeting(self):
    return "Move along, citizen."
```

Let's test all three:

```
> py npc = !generic/npc!
> py npc.greet(self)
stranger says: Hello, traveler.
> py merchant = !npc/merchant!
> py merchant.greet(self)
merchant says: Welcome! Care to browse my wares?
> py guard = !npc/guard!
> py guard.greet(self)
guard says: Move along, citizen.
```

Here's what happens when you call `merchant.greet(self)`:

1. Pythelix looks for `greet` on `npc/merchant`. It's not there.
2. It follows the parent chain to `generic/npc` and finds `greet`.
3. `greet` calls `self.greeting()`. Since `self` is the merchant, Pythelix looks for `greeting` on `npc/merchant` — and finds it there.
4. The merchant's `greeting` returns its custom text.
5. Back in `greet`, the result is formatted and sent to the character.

This is the chain of calls: the parent's `greet` method delegates to `greeting`, which each child can override independently. You write the shared logic once and only customize what differs. As your game grows, this pattern saves a lot of repetition.
