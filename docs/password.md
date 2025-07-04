---
title: Password handling in Pythelix
---

Pythelix offers a convenient abstraction for password generation and verification. Using the tool is quite simple, but if you're curious, there are more explanations below.

## How to Use the Interface?

Sooner or later, you will need to store passwords—if only those used by your players. Passwords should **not** be stored in your database as plain text, where anyone with access could easily read them. Instead, it is much better to *hash* them; that is, store only a string representation of each password that nobody (not even you) can read.

But what is the point? Because these hashes can be used to verify another password. Consider this scenario:

- A new account is created.
- A password linked with this account is hashed, and the hash (a long string) is stored in the database (not the password itself).
- When anyone wants to access this account, the player needs to enter a password.
- If the hashed password verifies it (i.e., the entered password is the same), the player can log into that account. Otherwise, access is denied.

Most services only store a password hash, not your actual password. This provides several layers of security. Indeed, the service doesn’t even have your password (only the hash), and if you lose it (which might have happened to you before), you need to regenerate it. The service cannot say, "By the way, your password is ..."; it needs to create a new hash.

In Pythelix, creating a hash is very simple. Use the `password` module, particularly the `hash` function. For example:

```
>>> password.hash("my secret password")
<Password using "pbkdf2">
>>>
```

Pythelix returns a convenient password object. It indicates to you the algorithm it used (`pbkdf2` here, if that helps), but it doesn’t display the very long hash string itself. Pythelix is extra careful and treats these as sensitive data—you can store and verify them, but you cannot display the hash to avoid password manipulation (even of the hash itself). This also helps limit the temptation to brute-force.

You cannot do much with this object except use its `verify` method, which is usually all you need:

```
>>> hash = password.hash("my secret password")
>>> hash.verify("my secret password")
True
>>> hash.verify("or something else")
False
>>> hash.verify("my secret Password")
False
>>>
```

If you're intrigued by the last test, notice that we used a capital "P" in "Password". This makes the passwords different, so `False` is returned accurately.

Of course, you can store the hash in an attribute, and that's what you will most often do:

```
>>> account = Entity(key="account/5")
>>> account.hash = password.hash("clever11")
>>> account.hash
<Password using "pbkdf2">
>>>
```

The last line indicates the password hash is stored in the `account.hash` attribute. You can restart the server and open a scripting console again:

```python
>>> account = !account/5!
>>> account.hash
<Password using "pbkdf2">
>>> account.hash.verify("clever11")
True
>>> account.hash.verify("clever12")
False
>>>
```

You probably see the idea. This is a nice security feature, and it is recommended you use it for all your passwords. If you're curious, read on for technical details; but in most cases, you don't need to worry about these to use it, since it is pretty simple.

## Password Algorithms

As you noticed, when we hash a password, we get a long string (though it’s hidden in Pythelix). We cannot "decrypt" our password from this long string. All we can do is check if another password matches the original.

This is done for security. For one, as the administrator, you don’t know the passwords used by your players. If anyone gains access to a scripting console, they won’t be able to tell either. Password algorithms transform your password into this long hash and check other passwords against it. They are designed to be compute intensive, meaning they require significant processing time.

The algorithm I use in this documentation is `"pbkdf2"`, one of several algorithms. It is quite slow (it takes about 200ms to generate a hash or verify a password), because it does a lot of work. 200ms may not sound long to you. But if someone finds the hash and tries to guess the password by brute force (trying all possible options), this delay adds up to a very long time before success—too long, for the time being.

Security continues to evolve alongside the threats it faces. One day, maybe this algorithm won’t be as resource-intensive and will be easier to breach.

Pythelix supports multiple password algorithms. Older passwords remain verifiable, but new passwords can be hashed using other algorithms. The most popular and current algorithm might be [Argon2](https://argon2.online/). Pythelix provides an implementation of Argon2, and it is the recommended algorithm to use... on Linux.

There’s the catch: for now, Argon2 doesn’t work very well on Windows. There are workarounds, but the Elixir implementation relies on C code that needs to be compiled. Windows doesn’t handle this seamlessly, and it was decided that the ease of using Pythelix on any operating system outweighed this security benefit. So on Windows, Pythelix currently provides only `"pbkdf2"`. On Linux, it provides both Argon2 (recommended) and pbkdf2, with Argon2 used by default.

You don’t need to do anything: when you start Pythelix on Windows or Linux, it will automatically detect which algorithms are available and default to the most secure option.
