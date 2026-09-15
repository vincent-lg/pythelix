# Add dynamic description to Pythelix

By default, Pythelix offers a way to create descriptions with dynamic content.

## What are dynamic descriptions?

They are portions of a description (like a room description) that changes based on code. So the description can change depending on external factors. Think:

- If a cloud is above the room, see less details;
- If it's just dawn, change a line of the description;
- If the player has succeeded a quest, they might see an additional detail others don't;
- ... and so on.

Obviously, you can change a room's description for a lot of reasons. As long as these can be explained in scripts, dynamic descriptions are easy to set up.

## The Description entity

The most important part of the dynamic description is the `Description` entity (note the capital D). This entity is a sub-entity (meaning it's never stored directly but inside another entity). For instance, let's look at room/bakery in `worldlets/room.txt`:

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

On the wall, you can see a clock with hands pointing to $clock.
""")
```

We use the `Description` entity much like a class (`description = Description(...)`). The description itself is just a multi-line string.

It contains three paragraphs separated by a blank line. This is important for formatting (we'll see why soon).

Look at the last paragraph:

    On the wall, you can see a clock with hands pointing to $clock.

This `$clock` part is important: it tells the `Description` entity this is a dynamic portion of the description.

When the `Description` entity sees the `$clock`, it tries to find a `describe_clock` method on the entity. And it's defined just below:

```
def describe_clock(viewer: Entity):
    now = realtime.now()
    return f"{now.hour:02}:{now.minute:02}"
```

If you're not used to format specifiers in Python, this might look a bit complex — we explain them below. The important thing is that `describe_clock` returns a string. And this string will then be inserted in the description, so that the final paragraph will be:

    On the wall, you can see a clock with hands pointing to 18:12.

<details markdown="1">
<summary>Can you explain the format specifiers? The code looks hard to read.</summary>

The first thing is to remember this is a format-string (or f-string). Notice the `f` before the opening double quotes. It means that expressions between braces `{}` will be evaluated and replaced by their value.

So in short:

    now = realtime.now()
    return f"{now.hour}:{now.minute}"

... will just be replaced with something like:

    18:12

... depending on the time of course.

If you don't know the `realtime` module, you can experiment with `py`:

    py realtime.now()

That might help you understand what we did.

The second part is the format specifier. Because our line was:

    return f"{now.hour:02}:{now.minute:02}"

- Between braces, the first part is the expression to evaluate (`now.hour` for instance).
- Then comes a colon (`:`). This introduces a format specifier.
- Then `02`: `0` means "pad with zeros" and `2` is the minimum field width. So the result will be at least two characters wide, padded with zeros on the left if needed.

So if `now.hour` is 3, the result becomes `"03"`. If `now.hour` is 12, the result is `"12"`.

`02` is a common format specifier for time values because the result is easier to read.
</details>
