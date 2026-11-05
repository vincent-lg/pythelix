# Base

What most games start from: the generic entities (`generic/room`,
`generic/object`, `generic/player`, `generic/account`...), the common commands
(`look`, `say`, `get`, `drop`, `help`, the administrator's `apply` and
`pythello`) and the login menus.

Other plugins can build on it by declaring `depends = {"base": ">=1.0"}`.

## Making it yours

Don't edit these files. Redeclare what you want to change in your own
worldlets, with the same key. For instance, to choose where new characters
appear:

```
!menu/new/character!

def start_location(client):
    return !room/bakery!
```

To turn off a command:

```
!command/give!
name = None
```
