---
title: Random-string generators (rangen) in Pythelix
---

Some things in a game world need to look random while never repeating: phone numbers, licence plates, serial numbers, bank account codes, apartment door codes. Picking characters at random is easy — making sure you never hand out the same phone number twice, even after a server restart, is not. Random-string generators (**rangen** for short) do exactly that.

## The problem rangen solves

Say your game has mobile phones, and every character needs a number. A naive approach picks four random digits. Sooner or later, two characters get the same number — and the day it happens, your phone command starts calling the wrong person.

The obvious fix is to keep a list of every number handed out, check new candidates against it, and retry on a collision. That works until the list gets long: when 9,000 of the 10,000 possible numbers are taken, random retries mostly hit numbers already used, and generation becomes painfully slow. And you still have to store that list somewhere so it survives a restart.

A rangen handles all of this for you:

- it only ever returns a string it has never returned before;
- it remembers every string it produced, in the database, so a restart changes nothing;
- it finds the remaining combinations efficiently, even when almost everything is taken;
- it tells you when nothing is left, instead of looping forever.

## A first generator

A rangen is just an [entity](./entities.md) whose parent is `generic/rangen`. Create one in a [worldlet](./worldlets.md):

```
!rangen/plate!
parent = "generic/rangen"
patterns = ["ABCDEFGHIJKLMNOPQRSTUVWXYZ", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "-", "0123456789", "0123456789", "0123456789"]
```

Apply the worldlet and ask for a licence plate:

```
> apply
Worldlet applied ...
> py !rangen/plate!.generate()
"QF-207"
> py !rangen/plate!.generate()
"BX-940"
> py !rangen/plate!.generate()
"QF-118"
```

Each call returns a brand-new plate. Call it 676,000 times and you will get 676,000 different plates; call it once more and it will tell you there are none left.

## Patterns

Everything a generator can produce is described by its `patterns` attribute: a **list of strings, one per character position**.

Each string lists the characters allowed at that position. In the example above:

| Position | Pattern | Meaning |
| -------- | ------- | ------- |
| 1 | `"ABCDEFGHIJKLMNOPQRSTUVWXYZ"` | any uppercase letter |
| 2 | `"ABCDEFGHIJKLMNOPQRSTUVWXYZ"` | any uppercase letter |
| 3 | `"-"` | always a dash |
| 4 to 6 | `"0123456789"` | any digit |

A few consequences follow directly from that:

- **Generated strings all have the same length**: one character per pattern. Six patterns, six characters.
- **The number of possible strings is the product of the pattern lengths.** Here: 26 × 26 × 1 × 10 × 10 × 10 = 676,000.
- **A one-character pattern is a constant.** That is how the dash above is written, and it is the normal way to pin a prefix: a French mobile number always starting with `06` is `["0", "6", ...]`.
- **Repeating a character inside a pattern changes nothing.** `"aa"` offers one choice, not two.
- **Accented and non-ASCII characters work**, since patterns are split into characters, not bytes. `"éèê"` is a perfectly good pattern. See [encoding](./encoding.md) if your players connect with non-UTF-8 clients.

> `patterns` must be defined and non-empty on your generator. The `generic/rangen` parent defaults it to an empty list, which describes the empty string and nothing else — calling `generate()` on such a generator aborts the script rather than returning anything useful.

Some patterns you are likely to need:

```
# A four-digit internal phone number
patterns = ["0123456789", "0123456789", "0123456789", "0123456789"]

# A mobile number always starting with 06
patterns = ["0", "6", "0123456789", "0123456789", "0123456789", "0123456789", "0123456789", "0123456789"]

# A six-character invite code, digits and uppercase letters, no confusing 0/O or 1/I
patterns = ["ABCDEFGHJKLMNPQRSTUVWXYZ23456789"] * 6
```

## What you can do with a generator

A generator inherits five things from `generic/rangen`.

### generate()

Returns a new string that has never been produced before, and records it:

```
> py !rangen/plate!.generate()
"LM-364"
```

If every combination has already been used, it raises a `ValueError` (see [Running out](#running-out) below).

### add(string)

Marks a string as used without generating it. Useful to reserve values: a plate the police already own, a phone number reserved for an NPC, numbers imported from somewhere else.

```
> py !rangen/plate!.add("AA-000")
```

From then on, `generate()` will never return `"AA-000"`.

### remove(string)

The opposite: frees a string so it can be generated again. Call it when the thing holding that value disappears — a car is scrapped, a phone is destroyed — and you want the value back in circulation.

```
> py !rangen/plate!.remove("AA-000")
```

Removing a string that was never used does nothing at all; it is safe to call blindly.

### clear()

Forgets every string this generator has produced, in memory and in the database. The generator starts over from scratch.

```
> py !rangen/plate!.clear()
```

### count

The number of strings currently marked as used. Note that this is a **property, not a method** — no parentheses:

```
> py !rangen/plate!.count
3
```

## Filtering with check

Patterns say which characters are allowed. They cannot say things like "never generate a number starting with 013" or "no plate containing a rude word". That is what the `check` method is for.

Define `check` on your generator and it will be consulted while the string is being built. Return `True` to accept, `False` to reject:

```
!rangen/phone!
parent = "generic/rangen"
patterns = ["0", "1234", "0123456789", "0123456789"]

def check(self, text):
    return not text.startswith("013")
```

Now `0130`, `0131`, … are never produced, while the rest of the space stays available.

### check sees prefixes, not just finished strings

This is the one thing to get right about `check`. It is called at **every position**, with the string built *so far*. For a four-character generator, `check` is called with a one-character string, then a two-character string, then three, then the complete four-character one.

That is deliberate and it is what makes rangen fast: rejecting `"013"` prunes the entire branch at once, so the ten numbers below it are never even considered.

It also means a check written as if it only ever saw complete strings will silently reject everything:

```
# WRONG: `text` is one character long the first time check is called,
# so this is False at the very first position and no branch is ever explored.
def check(self, text):
    return len(text) == 4 and not text.startswith("013")
```

Such a generator raises `ValueError` on the first `generate()` call, as if it were already exhausted.

Write conditions that are true of every valid prefix. When a rule genuinely only applies to the finished string, guard it by length instead of asserting the length:

```
!rangen/phone!
parent = "generic/rangen"
patterns = ["0", "1234", "0123456789", "0123456789"]
forbidden = ["0666", "0123"]

def check(self, text):
    if len(text) < 4:
        return True
    endif

    return text not in self.forbidden
```

> If a generator has no `check` method, everything the patterns allow is accepted. If `check` raises an error or returns nothing, the candidate is accepted — a broken check will not block generation, though the error will be reported.

## Running out

A generator is finite. When every combination allowed by the patterns has been used (or rejected by `check`), `generate()` raises a `ValueError`:

```
> py !rangen/plate!.generate()
ValueError: all combinations have been exhausted
```

Catch it wherever running out is a real possibility:

```
try:
    number = !rangen/phone!.generate()
except ValueError:
    character.msg("Sorry, the network cannot allocate any more numbers.")
    return
endtry
```

`count` is the easy way to see this coming: compare it against the number of combinations your patterns allow, and widen the patterns (or `clear()` an obsolete generator) before players hit the wall.

## Persistence and performance

Two things happen when you call `generate()`:

- the new string is written to the database, in the `rangen_entries` table;
- it is inserted into an in-memory index (a trie) kept in a process dedicated to that generator.

The in-memory index is what makes generation fast even on a nearly-full generator: instead of drawing at random and retrying, the engine walks the tree of possible strings, shuffling the choices at each position and backing out of branches that are entirely used up. Finding one of the last few free combinations costs about as much as finding the first one.

The index is built lazily, the first time a generator is used after startup, from the rows stored in the database. You do not have to do anything for this to happen: restart the server, call `generate()`, and the strings handed out yesterday are still off the table.

Each generator keeps its own index and its own rows, identified by the entity key (or ID). Two generators never interfere: exhausting `rangen/plate` has no effect on `rangen/phone`.

## Things to watch out for

**Don't add the same string twice.** `add()` inserts a database row, and the same value cannot be stored twice for one generator. Calling `add("AA-000")` when `"AA-000"` is already used fails at the database level: this is not a `ValueError` you can catch with `try`/`except`, it aborts the script. If in doubt, `remove()` first, or keep track of what you reserved on your side.

**`add()` does not validate against the patterns.** A string that the patterns could never produce is accepted and stored, and only its first *N* characters (*N* being the number of patterns) count when deciding what `generate()` may still return. Feed `add()` strings of the right shape.

**Changing `patterns` on a live generator is disruptive.** The stored strings are re-read through the *current* patterns when the index is rebuilt, so changing the number of patterns changes how old values are interpreted. If you need to change the shape of what a generator produces, `clear()` it — or, better, define a new generator with a new key and leave the old one alone.

**A generator is an entity like any other.** It can hold your own attributes and methods next to `patterns` and `check`, and you can put shared behavior on an intermediate parent, exactly as described in [methods](./methods.md).

## A complete example

Here is a phone-number generator, and a command that hands a number to whoever asks for one.

In `worldlets/rangen.txt`:

```
!rangen/phone!
parent = "generic/rangen"
patterns = ["0", "6", "0123456789", "0123456789", "0123456789", "0123456789", "0123456789", "0123456789"]

def check(self, text):
    # 0600 is reserved for the emergency services.
    return not text.startswith("0600")
```

In `worldlets/commands.txt`:

```
!command/subscribe!
parent = "generic/char_command"
name = "subscribe"
category = "General"

def run(character):
    if hasattr(character, "phone_number"):
        character.msg(f"You already have a number: {character.phone_number}.")
        return
    endif

    try:
        number = !rangen/phone!.generate()
    except ValueError:
        character.msg("The network is full. Try again later.")
        return
    endtry

    character.phone_number = number
    character.msg(f"You are now reachable at {number}.")
```

Whenever a character gives up their subscription, hand the number back so someone else can get it:

```
!command/unsubscribe!
parent = "generic/char_command"
name = "unsubscribe"
category = "General"

def run(character):
    if not hasattr(character, "phone_number"):
        character.msg("You have no number to give up.")
        return
    endif

    !rangen/phone!.remove(character.phone_number)
    character.msg(f"The number {character.phone_number} is back in the pool.")
```

That is the whole system: patterns describe the shape, `check` narrows it down, `generate()` hands out values that are guaranteed to be new, and the database remembers them for as long as your game lives.
