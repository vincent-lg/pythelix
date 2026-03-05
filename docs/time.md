---
title: Time in Pythelix
---

Pythelix provides two complementary time systems accessible from Pythello scripts:

- **Real time** (`realtime`) — the actual wall-clock date and time on the server.
- **Game time** (`gametime`) — a fictional in-world clock, optionally tied to custom calendars with any names and units you define.

Both systems produce objects you can read, compare, and use to schedule future events. This tutorial walks through both, from the simplest use cases to building a fully fledged fantasy calendar.

## Real time

The `realtime` module gives you access to the actual date and time on the server. There is nothing to set up; it works out of the box.

### Getting the current time

`realtime.now()` returns a `RealDateTime` object representing the current moment in local server time. From the [Pythello console](./scripting.md):

```
>>> dt = realtime.now()
>>> dt
<RealDateTime 2026-02-27 19:42:00+01:00>
```

You can read individual components directly as attributes:

```
>>> dt.year
2026
>>> dt.month
2
>>> dt.day
27
>>> dt.hour
19
>>> dt.minute
42
>>> dt.second
0
>>> dt.weekday
5
>>> dt.timezone
"+01:00"
```

`str()` and `repr()` both work as expected:

```
>>> str(dt)
"2026-02-27 19:42:00+01:00"
>>> repr(dt)
"<RealDateTime 2026-02-27 19:42:00+01:00>"
```

### The raw clock

`realtime.clock` (without parentheses) returns the current Unix timestamp in seconds as an integer. This is useful when you need a simple reference point for timing:

```
>>> realtime.clock
1772201720
```

### Arithmetic: adding and subtracting time

`RealDateTime` objects are immutable. `add()` and `sub()` return a *new* object without modifying the original.

You can add or subtract an integer (or float) number of seconds, or a [Duration literal](./scripting.md):

```
>>> now = realtime.now()
>>> one_hour_later = now.add(3600)
>>> one_hour_later.hour
20
>>> now.hour        # unchanged
19
>>> yesterday = now.sub(1d)
>>> now.day - yesterday.day
1
```

### Scheduling a real-time event

You can ask the game to call a method on an entity at a specific future real time:

```
dt = realtime.now().add(3600)   # one hour from now
dt.schedule(!my_room!, "open_gates")
```

When the real clock reaches that datetime, the `open_gates` method on `my_room` will be called automatically. The call is persisted so it survives server restarts.

> Only future datetimes will trigger scheduling. If you pass a datetime already in the past, nothing happens.

## Game time

Game time is a fictional clock that flows at a configurable speed relative to real time. For example, you could make game time flow ten times faster than real time, so one real hour equals ten game hours.

Game time integrates with *calendars*: custom unit hierarchies that let you define your world's way of measuring time (sols, cycles, ages, whatever makes sense for your setting). Or, if you prefer, you can use a standard Gregorian calendar that maps game time to familiar years, months, and days.

### Setting up the game epoch

Game time requires a `game_epoch` entity anywhere in your worldlet. This entity configures how the game clock works:

```
!game_epoch!
scale = 10
```

The key is important (it needs to be `game_epoch`). The `scale` attribute sets how many game seconds pass per real second. A scale of `10` means game time flows ten times faster than real time.

When the server first encounters this entity (or after a reset), it records the current real time as the epoch's starting point. From that moment on, `gametime.clock` returns the number of game seconds elapsed since that start.

> If no `game_epoch` entity exists, the `gametime` module is inactive and all calls to `gametime.now()` will raise an error.

You do not need to set `started_at` manually; the engine handles it. If you want to restart the in-game clock from zero, see [Resetting the epoch](#resetting-the-epoch) below.

### Reading the raw game clock

Once you have set the game epoch, `gametime.clock` returns the number of game seconds that have elapsed since the epoch started:

```
>>> gametime.clock
1003
```

This nuber will be 0 if you didn't define a game epoch (by creating an entity with key of `game_epoch` and a proper scale).

Note: the gametime clock is adjusted whenever you need this information. There is no inner process that will "push" this clock forward. Rather, each time you call `gametime.clock`, the clock will be adjusted. This function is called internally by all other methods of `gametime` that needs to look for the time.

## Calendars

A calendar tells Pythelix how to interpret a raw number of game seconds as human-readable units (seconds, minutes, hours, days, etc.). You can have multiple calendars in the same world—for example, a northern-hemisphere calendar and a southern one that starts seasons three months apart.

Every calendar is an entity whose parent is `generic/calendar`:

```
!my_calendar!
parent = "generic/calendar"
type = "custom"
```

> The `generic/calendar` entity is a built-in base entity provided by Pythelix. You never define it yourself; just make your calendar entities its children.

There are two calendar types:

- `"custom"`: you define the unit hierarchy from scratch.
- `"gregorian"`: uses the standard Gregorian calendar mapped onto game time.

### Custom calendars

A custom calendar defines its own unit system. Units form a hierarchy: each unit is defined in terms of a smaller one.

You declare units in the `units` attribute, which is a dictionary. Four built-in sub-entity types handle the structure:

#### `GameTimeBaseUnit()`

Marks one unit as the foundation of the hierarchy (the equivalent of seconds). Every custom calendar must have exactly one base unit:

```
"second": GameTimeBaseUnit()
```

#### `GameTimeUnit(base, factor, start=0)`

Defines a derived unit built on top of another. Arguments:

- `base` — the name of the unit this builds on (a string matching another key in the dict).
- `factor` — how many of the base unit make one of this unit.
- `start` — the starting value (default `0`). Use this when a unit should start at `1` (e.g., days of the month) or any other offset.

```
"minute": GameTimeUnit("second", 60)
"hour": GameTimeUnit("minute", 60)
"day": GameTimeUnit("hour", 24, start=1)
"month": GameTimeUnit("day", 30, start=1)
"year": GameTimeUnit("month", 12, start=1)
```

#### `GameTimeCyclicUnit(base, cycle, start=0, offset=0)`

Defines a unit whose value cycles modularly, independent of the unit hierarchy. Unlike `GameTimeUnit`, a cyclic unit does not nest into the hierarchy — its value is computed as `(total_base_elapsed + offset) % cycle + start`.

Arguments:

- `base` — the name of the unit to count from epoch (must be a regular unit in the hierarchy).
- `cycle` — the modulus (length of the cycle).
- `start` — the starting value (default `0`). Use `1` if day-of-week should be 1-based.
- `offset` — shifts the cycle (default `0`). For example, if epoch day 0 is a Wednesday and you want weekday 1 to mean Monday, set `offset` to `-2` (or equivalently `5`).

```
"weekday": GameTimeCyclicUnit("day", 7, start=1)
```

This creates a `weekday` unit that cycles 1 through 7 based on total days elapsed. It works across month and year boundaries because it counts from the epoch, not from the current month.

You can attach `GameTimeProperty` entries to name the days:

```
properties = {
    "day_name": [
        GameTimeProperty("weekday", 1, "Moonday"),
        GameTimeProperty("weekday", 2, "Treeday"),
        GameTimeProperty("weekday", 3, "Waterday"),
        GameTimeProperty("weekday", 4, "Fireday"),
        GameTimeProperty("weekday", 5, "Earthday"),
        GameTimeProperty("weekday", 6, "Starday"),
        GameTimeProperty("weekday", 7, "Sunday")
    ]
}
```

> **Note on Gregorian calendars:** the `weekday` unit is automatically available on Gregorian calendars (1 = Monday through 7 = Sunday), following the ISO 8601 convention. You do not need to define it yourself.

#### Putting it together: a complete custom calendar

Here is a minimal earthlike calendar:

```
!calendar/earth!
parent = "generic/calendar"
type = "custom"
offset = 0
units = {
    "second": GameTimeBaseUnit(),
    "minute": GameTimeUnit("second", 60),
    "hour": GameTimeUnit("minute", 60),
    "day": GameTimeUnit("hour", 24, start=1),
    "month": GameTimeUnit("day", 30, start=1),
    "year": GameTimeUnit("month", 12, start=1)
}
```

The `offset` attribute shifts the game epoch before calculating units. A value of `0` means the clock starts at second=0, minute=0, hour=0, day=1, month=1, year=1. To start the world at year 3000, you could set:

```
!calendar/shire!
parent = "generic/calendar"
type = "custom"
offset = 0
units = {
    "second": GameTimeBaseUnit(),
    "minute": GameTimeUnit("second", 60),
    "hour": GameTimeUnit("minute", 60),
    "day": GameTimeUnit("hour", 24, start=1),
    "year": GameTimeUnit("day", 365, start=3000)
}
```

Now epoch 0 will be year 3000, increasing from then.

### Calendar offset

The `offset` attribute is added to the raw game clock before any unit calculation. It effectively shifts where in the calendar the world starts. For example, if you want the world to start at midnight on day 15 of the first month (and your units are seconds), you would set:

```
offset = (14 * 24 * 3600)   # 14 days in seconds
```

This way, when the game clock is at 0 real game seconds, the calendar reads day 15.

### Gregorian calendars

If you want game time to map to real Gregorian dates (useful, for example, if your game is set in a near-future Earth), use `type: "gregorian"`:

```
!calendar/real_world!
parent = "generic/calendar"
type = "gregorian"
offset = 0
```

No `units` attribute is needed. The engine automatically provides: `year`, `month`, `day`, `hour`, `minute`, `second`, and `weekday`, computed by interpreting game seconds as a Unix timestamp. The `weekday` unit returns 1 (Monday) through 7 (Sunday), following ISO 8601. With `offset: 0` and `scale: 1`, game time is identical to real time.

Identical, but the epoch is usually 1970. If you want to shift to another start date, use an offset (for instance, an offset of 1 billion will shift the starting date in 2001).

### Properties: named calendar conditions

Properties let you attach human-readable labels to calendar states. You define them in the `properties` attribute of a calendar, which is also a dictionary.

Each property is defined as a key mapped to a **list** of sub-entities. The engine evaluates the list in order and returns the value of the first match. If nothing matches, that property is absent from the `GameTime` object.

There are three kinds of sub-entity you can put in the list:

#### `GameTimeBoundary(unit, from, to, value)`

Returns a fixed string when a unit's value falls in `[from, to)` — inclusive lower bound, **exclusive** upper bound. Arguments:

- `unit` — the name of the unit to check (e.g., `"month"`, `"hour"`).
- `from` — the lower bound (inclusive).
- `to` — the upper bound (exclusive).
- `value` — the string to return when the condition is met.

The exclusive upper bound means adjacent ranges can be written cleanly with no gaps or overlaps:

```
GameTimeBoundary("hour", 0, 6, "night")     # 0 ≤ hour < 6
GameTimeBoundary("hour", 6, 12, "morning")  # 6 ≤ hour < 12
GameTimeBoundary("hour", 12, 18, "afternoon")
GameTimeBoundary("hour", 18, 24, "evening")
```

### `GameTimeProperty(unit, index, value)`

Returns a fixed string when a unit's value matches exactly. Arguments:

- `unit` — the unit to check.
- `index` — the exact value to match.
- `value` — the string to return.

### `GameTimeDefault(value)`

Always matches. Use it as the **last** entry in a list to catch any case not covered by the preceding boundaries or properties — the "else" branch. Argument:

- `value` — the string to return.

### Example: time of day and named days

```
!calendar/earth!
parent = "generic/calendar"
type = "custom"
offset = 0
units = {
    "second": GameTimeBaseUnit(),
    "minute": GameTimeUnit("second", 60),
    "hour":   GameTimeUnit("minute", 60),
    "day":    GameTimeUnit("hour", 24, start=1),
    "month":  GameTimeUnit("day", 30, start=1),
    "year":   GameTimeUnit("month", 12, start=1)
}
properties = {
    "time_of_day": [
        GameTimeBoundary("hour", 5, 12, "morning"),
        GameTimeBoundary("hour", 12, 18, "afternoon"),
        GameTimeBoundary("hour", 18, 22, "evening"),
        GameTimeDefault("night")
    ],
    "rest_day": [
        GameTimeProperty("day", 7, "day of rest")
    ]
}
```

> Days start at 1 here (`start=1`), so day 7 is the seventh day of each month. The `"night"` entry uses `GameTimeDefault` rather than a boundary because night wraps across midnight — hours 22–4 — which cannot be expressed as a single `[from, to)` range. The default fires whenever none of the earlier entries matched, which is exactly right here.

The key of each entry becomes an attribute on the `GameTime` object. Its value is the string returned by the first matching sub-entity in the list:

```
now = gametime.now()
now.time_of_day     # "morning", "afternoon", "evening", or "night"
now.rest_day        # "day of rest" on day 7, AttributeError otherwise
```

In a script:

```
now = gametime.now()
if now.time_of_day == "morning":
    self.msg("The sun is rising.")
elif now.time_of_day == "evening":
    self.msg("The stars are beginning to appear.")
endif
```

> A property is only present on the `GameTime` object when at least one sub-entity in its list matches. If no entry matches, accessing the attribute raises `AttributeError`.

> **Wrap-around ranges** (e.g. night spanning 22:00–05:00 across midnight) cannot be expressed as a single `GameTimeBoundary` because `[from, to)` requires `from < to`. Use `GameTimeDefault` as the last entry instead: define all the non-wrapping slots with boundaries and let the default catch everything else.

### Properties and Gregorian calendars

You can add a `properties` attribute to a Gregorian calendar exactly as you would for a custom one. The unit names available to check are `"year"`, `"month"`, `"day"`, `"hour"`, `"minute"`, and `"second"`. This is the recommended way to add localised labels like month names or season names, since those are language- and setting-specific:

```
!calendar/real_world!
parent = "generic/calendar"
type = "gregorian"
offset = 0
properties = {
    "season": [
        GameTimeBoundary("month", 3, 6, "spring"),
        GameTimeBoundary("month", 6, 9, "summer"),
        GameTimeBoundary("month", 9, 12, "autumn"),
        GameTimeDefault("winter")
    ],
    "month_name": [
        GameTimeProperty("month", 1, "January"),
        GameTimeProperty("month", 2, "February"),
        GameTimeProperty("month", 3, "March"),
        GameTimeProperty("month", 4, "April"),
        GameTimeProperty("month", 5, "May"),
        GameTimeProperty("month", 6, "June"),
        GameTimeProperty("month", 7, "July"),
        GameTimeProperty("month", 8, "August"),
        GameTimeProperty("month", 9, "September"),
        GameTimeProperty("month", 10, "October"),
        GameTimeProperty("month", 11, "November"),
        GameTimeProperty("month", 12, "December")
    ]
}
```

Then `gametime.now().season` returns `"spring"`, `"summer"`, etc., and `gametime.now().month_name` returns the full month name.

### A Martian example

Mars makes a nice calendar challenge because two things differ significantly from Earth:

- A Martian day — called a **sol** — is about 24 hours and 37 minutes. We round it to 25 hours here, close enough for a game.
- A Martian year is about **668 sols**. More importantly, Mars has a noticeably elliptical orbit, so its seasons are *not* equal in length. Northern spring and summer together last around 370 sols (more than half the year), because Mars is near aphelion (furthest from the Sun) during northern summer and moves slowly. Northern autumn and winter are shorter and harsher, around 298 sols.

Mars has no conventional months, so we go straight from sol to year. The `start=1` makes both units begin counting at 1.

```
!calendar/mars!
parent = "generic/calendar"
type = "custom"
offset = 0
units = {
    "second": GameTimeBaseUnit(),
    "minute": GameTimeUnit("second", 60),
    "hour": GameTimeUnit("minute", 60),
    "sol": GameTimeUnit("hour", 25, start=1),
    "year": GameTimeUnit("sol", 668, start=1)
}
properties = {
    "northern_season": [
        GameTimeBoundary("sol", 1, 195, "spring"),
        GameTimeBoundary("sol", 195, 373, "summer"),
        GameTimeBoundary("sol", 373, 515, "autumn"),
        GameTimeDefault("winter")
    ],
    "southern_season": [
        GameTimeBoundary("sol", 1, 195, "autumn"),
        GameTimeBoundary("sol", 195, 373, "winter"),
        GameTimeBoundary("sol", 373, 515, "spring"),
        GameTimeDefault("summer")
    ],
    "time_of_day": [
        GameTimeBoundary("hour", 5, 8, "dawn"),
        GameTimeBoundary("hour", 8, 19, "day"),
        GameTimeBoundary("hour", 19, 22, "dusk"),
        GameTimeDefault("night")
    ]
}
```

The season boundaries (sols 1–194, 195–372, 373–514, 515–668) are rough approximations of the Ls-based divisions. `GameTimeDefault` catches the tail of winter without needing a wrap-around boundary.

Southern seasons are simply the mirror: autumn and winter when the north has spring and summer, and vice versa. Both properties live on the same `GameTime` object, so you can read both at once:

```
>>> now = gametime.now(!calendar/mars!)
>>> now.sol
581
>>> now.year
3
>>> now.northern_season
"winter"
>>> now.southern_season
"summer"
>>> now.time_of_day
"day"
```

## Reading game time in scripts

### `gametime.now()`

Returns a snapshot of the current game time as a `GameTime` object. If your world has exactly one calendar, you can call it without arguments:

```
now = gametime.now()
```

If you have multiple calendars, you must specify which one:

```
now = gametime.now(!calendar/earth!)
```

### Accessing units and properties

All unit names and property names defined in the calendar become direct attributes of the `GameTime` object:

```
now = gametime.now()
year = now.year
month = now.month
day = now.day
hour = now.hour
minute = now.minute
second = now.second
```

For a calendar with custom unit names like `sol` and `cycle`:

```
now = gametime.now()
sol = now.sol
cycle = now.cycle
```

`str()` and `repr()` produce a summary of all unit values:

```
>>> repr(gametime.now())
"<GameTime day=3, hour=14, minute=22, month=1, second=7, year=1>"
```

## Projecting time forward or backward

`gt.project(**kwargs)` returns a new `GameTime` as if the clock were advanced (or rewound) by the given amounts, without actually changing the clock:

```
now = gametime.now()
later = now.project(hour=2)        # 2 hours ahead
yesterday = now.project(day=-1)        # 1 day back
far = now.project(year=1, day=5) # 1 year and 5 days ahead
```

The keyword argument names must match unit names defined in the calendar. Negative values go backward. The original `now` is unchanged.

This is useful for displaying information like "the next time it will be noon" or "what day of the week was it three days ago".

## Scheduling a game-time event

`gt.schedule(entity, method)` schedules a method call to happen when the game clock reaches the given `GameTime`. The method is called on the specified entity:

```
# Schedule the harvest festival to begin in 7 in-game days
now = gametime.now()
festival = now.project(day=7)
festival.schedule(!calendar/earth!, "start_festival")
```

The engine converts the game time to an equivalent real-time delay and uses `Process.send_after` to trigger the call. The delay survives server restarts because it is stored persistently.

> The entity and method must exist when the event fires. If the entity has been deleted by then, the call is silently ignored.

## Converting between real and game time

### Real time from a game time

Given a `GameTime` snapshot, returns the corresponding `RealDateTime`:

```
now = gametime.now()
real_now = realtime.from_gametime(now)
real_now.hour  # local hour when this game moment corresponds to
```

Of course, it is more useful with projected time. Let's assume you have a calendar `!calendar/earth!` with unit "day", and you want to see what real time it will be in 7 gametime days:

```
>>> now = gametime.now(!calendar/earth!)
>>> next_week = now.project(day=7)
>>> real = realtime.from_gametime(next_week)
>>> real
<RealDateTime 2026-02-28 07:11:08+01:00>
```

### Game time from a real time

Given a `RealDateTime`, returns the `GameTime` at that point in history (or future):

```
dt = realtime.now().add(5d) # 5 real days from now
gt = gametime.from_realtime(dt)
```

If you have multiple calendars:

```
gt = gametime.from_realtime(dt, !calendar/earth!)
```

This helps schedule events: you want to schedule something starting tomorrow at 3 PM? It's easy to do. You can predict the game time it will be then and send invitations (though you probably need to mention the real date too).

> These conversions rely on the epoch's `started_at` timestamp. They will raise a `RuntimeError` if the game epoch has not been configured.

### Time validity

You might wonder, when doing projections like that (especially far in the future), would the time remain accurate? The answer is yes: the game time is not a clock with a push button to maintain it synchronized. It's an accurate calculation based on current time.

Some factors can affect it of course:

- The server changes its time: if you change the server's date or time, the "old projection of game time" might become invalid.
- Scale is adjusted: if you manually change the Epoch's scale, game time will not match.

It is not recommended to do either (and not very likely to do either).

That said, in most cases, real time and game time will remain consistent, and the calendar(s) you use as well. In particular, game time keeps "increasing" even during a server restart (of if the server is down for 3 days).

## A complete example: a fantasy world

Here is a full worldlet excerpt for a fantasy game with a custom calendar, time-of-day labels, and a named day of rest:

```
# The game epoch: game time flows 30× faster than real time
!game_epoch!
scale = 30

# The calendar
!calendar/aetherion!
parent = "generic/calendar"
type = "custom"
offset = 0
units = {
    "heartbeat": GameTimeBaseUnit(),
    "breath": GameTimeUnit("heartbeat", 60),
    "bell": GameTimeUnit("breath", 60),
    "sol": GameTimeUnit("bell", 24, start=1),
    "sennight": GameTimeUnit("sol", 7, start=1),
    "season": GameTimeUnit("sennight", 13, start=1),
    "age": GameTimeUnit("season", 4, start=1)
}
properties = {
    "time_of_day": [
        GameTimeBoundary("bell", 5, 8, "dawn"),
        GameTimeBoundary("bell", 8, 19, "daylight"),
        GameTimeBoundary("bell", 19, 22, "dusk"),
        GameTimeDefault("darkness")
    ],
    "special_day": [
        GameTimeProperty("sol", 4, "market day"),
        GameTimeProperty("sol", 7, "day of rest")
        GameTimeDefault("")
    ]
}
```

In a script running in a room:

```
def tick:
now = gametime.now(!calendar/aetherion!)

if now.time_of_day == "dawn":
    self.announce("The first light of dawn creeps over the horizon.")
elif now.time_of_day == "dusk":
    self.announce("The last colours of sunset fade from the sky.")
endif

if now.special_day == "market day":
    self.announce("Merchants set up their stalls in the square.")
elif now.special_day == "day of rest":
    self.announce("The city is quiet today; most shops are closed.")
endif
```

## Resetting the epoch

Resetting the epoch sets the game clock back to zero—game time restarts from the beginning of your calendar. The scale and calendar definitions are unchanged.

**From a Pythello console:**

```
>>> gametime.reset_to_zero()
```

**From the command line (binary release):**

```sh
./bin/reset_game_epoch
```

Or on Windows:

```
bin\reset_game_epoch.bat
```

**From source (Mix):**

```sh
mix game.epoch.reset
```

> Resetting the epoch is permanent. The new `started_at` timestamp is saved to the database immediately.

## Quick reference

### `realtime` module

| Expression | Returns | Description |
|---|---|---|
| `realtime.clock` | integer | Unix timestamp in seconds |
| `realtime.now()` | `RealDateTime` | Current local date and time |
| `realtime.from_gametime(gt)` | `RealDateTime` | Convert a `GameTime` to real time |

### `RealDateTime` attributes and methods

| Expression | Returns | Description |
|---|---|---|
| `dt.year` | integer | Calendar year |
| `dt.month` | integer | Month (1–12) |
| `dt.day` | integer | Day of month |
| `dt.hour` | integer | Hour (0–23) |
| `dt.minute` | integer | Minute (0–59) |
| `dt.second` | integer | Second (0–59) |
| `dt.weekday` | integer | Day of the week (1 = Monday through 7 = Sunday, ISO 8601) |
| `dt.timezone` | string | UTC offset, e.g. `"+01:00"` or `"Z"` |
| `dt.add(n)` | `RealDateTime` | New datetime advanced by `n` seconds (or Duration) |
| `dt.sub(n)` | `RealDateTime` | New datetime rewound by `n` seconds (or Duration) |
| `dt.schedule(entity, method)` | None | Schedule a method call at this real time |

### `gametime` module

| Expression | Returns | Description |
|---|---|---|
| `gametime.clock` | integer | Game seconds since epoch |
| `gametime.now()` | `GameTime` | Current game time (requires exactly one calendar) |
| `gametime.now(!calendar!)` | `GameTime` | Current game time using the specified calendar |
| `gametime.from_realtime(dt)` | `GameTime` | Convert a `RealDateTime` to game time |
| `gametime.from_realtime(dt, !cal!)` | `GameTime` | Same, with an explicit calendar |
| `gametime.reset_to_zero()` | None | Reset the game clock to zero |

### `GameTime` attributes and methods

| Expression | Returns | Description |
|---|---|---|
| `gt.<unit>` | integer | Value of the named unit (e.g., `gt.hour`, `gt.sol`) |
| `gt.<property>` | string | Value of the named property, if active |
| `gt.project(**kwargs)` | `GameTime` | New snapshot with adjusted unit values |
| `gt.schedule(entity, method)` | None | Schedule a method call at this game time |

### Calendar sub-entities

| Sub-entity | Arguments | Purpose |
|---|---|---|
| `GameTimeBaseUnit()` | — | Marks the base unit (equivalent to seconds) |
| `GameTimeUnit(base, factor, start=0)` | base: str, factor: int, start: int | Defines a unit in terms of a smaller one |
| `GameTimeCyclicUnit(base, cycle, start=0, offset=0)` | base: str, cycle: int, start: int, offset: int | Defines a cyclic unit (e.g., day of the week) |
| `GameTimeBoundary(unit, from, to, value)` | unit: str, from: int, to: int, value: str | Matches when `from <= unit_value < to` (inclusive-exclusive) |
| `GameTimeProperty(unit, index, value)` | unit: str, index: int, value: str | Matches when `unit_value == index` exactly |
| `GameTimeDefault(value)` | value: str | Always matches — use as the last entry to catch remaining cases |
