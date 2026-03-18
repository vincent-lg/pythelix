---
title: Client encoding in Pythelix
---

Pythelix communicates with clients over a raw TCP connection. By default it assumes UTF-8, which works for modern clients on Linux and macOS. Windows clients (especially classic telnet or MUD clients) may use a different encoding such as CP1252 or ISO-8859-15. Pythelix can handle all of these, either globally via configuration or on a per-client basis at runtime.

## Supported encodings

| Name | Description |
|------|-------------|
| `"utf-8"` | Unicode UTF-8 (default) — modern terminals, Linux, macOS |
| `"cp1252"` | Windows-1252 — classic Windows telnet/MUD clients |
| `"iso-8859-15"` | ISO Latin-9 — Western European, common on older Unix terminals |
| `"iso-8859-1"` | ISO Latin-1 — older Western European standard |

Characters that cannot be represented in the target encoding are replaced with `?`.

## Setting the default encoding

The default encoding applies to every new client the moment it connects, before any scripting runs.

There are two ways to change the default encoding:

1. Through an environmebnt variable, `PYTHELIX_DEFAULTENCODING`.
2. Through the configuratoin.

To alter the default encoding, you can set the `DEFAULT_ENCODING` environment variable to another encoding (see the list above).

Otherwise, you can open `config/config.exs` and set the `default_encoding` key:

```elixir
config :pythelix,
  ...
  default_encoding: "cp1252"
```

Restart the server for the change to take effect. If the key is absent, `"utf-8"` is used.

## Changing the encoding per client at runtime

You can read or change the encoding of any connected client through its `encoding` attribute in scripting. This is useful when the client announces its capabilities (for example, through a telnet negotiation or a login option).

**Reading the current encoding:**

```python
enc = client.encoding   # e.g. "utf-8"
```

**Setting a new encoding:**

```python
client.encoding = "cp1252"
```

The change takes effect immediately: the very next message sent to or received from that client will use the new encoding. Setting an unsupported value raises a `ValueError` listing the accepted names.

A common pattern is to offer an encoding choice at login:

```python
def input(client):
    choice = client.last_input.strip().lower()
    if choice == "1":
        client.encoding = "utf-8"
    elif choice == "2":
        client.encoding = "cp1252"
    elif choice == "3":
        client.encoding = "iso-8859-15"
    else:
        client.msg("Invalid choice.")
        return
    client.msg("Encoding set.")
```

## Changing the default for a running server without restart

Because client entities are virtual and reset on each connection, there is no way to change the default mid-session for existing clients. However, you can update all currently connected clients at once from a command or script:

```python
for client in clients():
    client.encoding = "cp1252"
```

`clients()` is a built-in that returns all currently connected client entities.
