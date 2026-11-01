---
title: Ticking in Pythelix
---

In many text-based games, the world needs to feel alive: NPCs wander around, locations display ambience messages, characters heal over time. These recurring actions are often called "ticks". Pythelix lets any [entity](./entities.md) tick, while making sure the engine doesn't waste time simulating parts of the world no one is looking at.

## The problem with ticking everything

A naive approach would be to tick every entity in the world every minute. But most of the time, most of the world has no players in it. Ticking hundreds of NPCs and locations that no one can see wastes resources and creates lag for no benefit.

Pythelix solves this without asking you to group your world by hand. You simply give an entity a `tick` interval and a tick method, and the engine decides whether to run it based on whether a player is actually around to see it.

## Two kinds of tick

An entity ticks by declaring a `tick` attribute (the interval, in seconds) and **one** of two methods:

- `on_tick` — a **simple** tick. It only fires when a player is around to see it. Use this for cosmetic, live behavior: ambience messages, idle NPC movement, flavor.
- `on_major_tick` — a **major** tick. It always fires, whether or not anyone is watching. Reserve it for global behavior that must advance regardless of observers.

If an entity defines both, the major tick wins.

```
!npc/rabbit!
parent = "generic/npc"
location = "room/forest_clearing"
tick = 60

def on_tick(self):
    exits = self.location.exits

    if exits and random.randint(1, 3) == 1:
        exit = random.choice(exits)
        self.try_exit(exit)
    endif
```

Here the rabbit has `tick = 60`, so its `on_tick` is called roughly once a minute — but only while a player can see it. When no one is near, the rabbit sits still and costs nothing.

## When is a player "around to see"?

A simple tick fires when a player **shares the entity's location chain**. Concretely, an entity ticks if either:

1. **A player is inside it** (it contains a player, directly or through nested containers), or
2. **It is inside a player's location** (it sits in the same place as a player, directly or nested).

This falls out of containment, so it does the right thing automatically. Suppose a player stands in a room, and that room is inside a vehicle:

```
vehicle
└─ room (player is here)
   ├─ an NPC
   └─ a crate
      └─ a coin
```

When the player is in the room:

- The **NPC**, the **crate**, and the **coin** tick — they're inside the player's room.
- The **room** ticks — it contains the player.
- The **vehicle** ticks — it contains the player too (the room is inside it), so a "the vehicle lurches" ambience reaches the player.

If the vehicle held a *second* room with no player in it, that other room (and anything in it) would **not** tick — no player shares its location chain. Only the occupied part of the world simulates.

> What about adjacent locations connected by an exit?

They don't tick each other. "Around to see" is about containment, not connectivity. If you want an ambience message heard from a neighboring location, send it yourself from `on_tick` (for example, `self.location.announce(...)` plus a message to neighbors). Audibility is game design, and Pythelix leaves it to you.

## State that must advance unseen

Some state needs to be correct even when no one is watching — a wound that heals over hours, a crop that grows overnight, a gate that unlocks at dawn. `on_tick` is the wrong tool for these: it is **mostly for cosmetic, live behavior**, and it deliberately does nothing while unobserved. You have three other tools, each suited to a different need:

- **accumulative state** that just needs to read correctly when next seen → lazy catch-up;
- **a one-off action at a specific time** → a scheduled call;
- **important behavior that must genuinely repeat regardless of observers** → a major tick.

### Prefer lazy catch-up

Most "advance while unobserved" state doesn't actually need to *tick* while unobserved; it just needs to be **correct when someone next looks**. Store the last update time and compute the elapsed change on access:

```
!generic/living!
parent = "generic/npc"
hp = 20
max_hp = 120
heal_rate = 5
last_heal = None

def heal_to_now(self):
    """Catch up healing based on elapsed real time."""
    now = realtime.clock
    if self.last_heal is not None and self.hp < self.max_hp:
        elapsed = now - self.last_heal
        gained = int(elapsed / 60) * self.heal_rate
        self.hp = min(self.hp + gained, self.max_hp)
    endif
    self.last_heal = now
```

Call `heal_to_now` whenever the value matters (when a player looks, attacks, etc.). No timer runs, and the result is identical to ticking every minute — at a fraction of the cost.

### Major ticks, used sparingly

When something genuinely cannot be made lazy — a world event, a scheduled spawn, weather that affects everyone — use `on_major_tick`:

```
!world/weather!
parent = "generic/object"
tick = 300

def on_major_tick(self):
    self.current = random.choice(["clear", "rain", "fog"])
```

Remember that a major tick is **cost you always pay**. A world of 5,000 NPCs each healing in `on_major_tick` is exactly the "tick everything every minute" anti-pattern. Keep major ticks few, and make them coarse — one entity batching the work rather than thousands ticking individually.

A major tick is the right tool for *recurring* important work. It is not the only way to make something happen later, though — see below.

### Schedule a one-off action

If you need a single action to happen at a specific future moment — not on a repeating interval — don't reach for a tick at all. A future `RealDateTime` (or `GameTime`) has a `schedule(entity, method)` method that calls that method **once**, at the given time. The call is a persistent task, so it survives a server restart.

```
def on_attacked(self, attacker):
    # Bramble breaks free of its chain 30 real seconds from now.
    realtime.now().add(30).schedule(self, "break_free")

def break_free(self):
    self.freed = True
    self.location.announce(f"{self} snaps its chain and bounds free!")
```

Scheduling against game time works the same way, so you can defer to an in-game moment ("at the next dawn") regardless of how fast game time runs:

```
# Re-lock the gate in two in-game hours, whatever the time scale.
gametime.now(!calendar/farm!).project(hour=2).schedule(!farm/room/gate!, "relock")
```

Use this when the *timing* is what matters and the action is one-off; use `on_major_tick` when the action genuinely needs to repeat on an interval.

## "Around to see" only works where players stand

The observation gate compares locations, so it only fires `on_tick` for entities that are **physically where players are**. An entity that lives nowhere — a controller entity meant to drive an area from outside it — never passes the gate, and its `on_tick` will never run.

That's the intended escape hatch for building your own grouping. If you want a single entity to manage a region, give it an `on_major_tick` (so it always runs) and check for players yourself:

```
!region/forest!
parent = "generic/object"
tick = 30
rooms = []

def on_major_tick(self):
    # Only do work if a player is in one of our rooms.
    occupied = False
    for client in clients.active():
        owner = client.owner
        if owner is not None and owner.location in self.rooms:
            occupied = True
        endif
    done

    if occupied:
        room = random.choice(self.rooms)
        room.announce("A cold wind stirs the branches.")
    endif
```

This rebuilds the old "zone" idea entirely in worldlet code, where you control exactly what counts as "occupied" — without the engine imposing a fixed grouping on you.

## Checking it without waiting

A tick that fires once a minute, or a call scheduled for the next dawn, is exactly the behavior you can least afford to check by hand. [Scenarios](./scenarios.md) play on a clock that moves only when told to, so `wait 3h` fires three hours' worth of ticks and scheduled calls in order and returns at once:

```
given Alice in !farm/room/field!

Alice> plant wheat
Alice sees "You plant the wheat."

wait 3h

Alice> look
Alice sees "The wheat is ready to harvest."
```

Under that clock there is no jitter, and nothing fires between two lines on its own.

## Summary

| You want… | Use |
|-----------|-----|
| Live, cosmetic behavior near players | `on_tick` (+ `tick`) |
| Accumulative state that must be right when seen | Lazy catch-up (timestamp + compute on access) |
| A single action at a specific future time | `schedule(entity, method)` on a future `RealDateTime`/`GameTime` |
| Global or action-at-a-distance events that repeat | `on_major_tick` (+ `tick`), used sparingly |
| Your own region/zone logic | `on_major_tick` + your own player check |

> What if an entity has `tick` but no method, or a method but no `tick`?

Nothing happens. Both are required. You can set `tick` on a parent and define the method only on specific children — the engine picks them up after the worldlet is applied.

> What happens when the server restarts?

Tick state is ephemeral and not persisted. On startup the engine scans all entities and resumes ticking for any that declare a tick method. There's no need to save "this NPC was 23 seconds into its cycle" across restarts.
