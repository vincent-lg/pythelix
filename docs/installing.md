Pythelix can be run in several ways, depending on your familiarity with Elixir.

## Binaries

You can download and run a binary version of Pythelix:

Latest versions:

- [Download Pythelix for Linux x64](https://github.com/vincent-lg/pythelix/releases/download/latest-linux/pythelix-linux.tar.gz)
- [Download Pythelix for Windows x64](https://github.com/vincent-lg/pythelix/releases/download/latest-windows/pythelix-windows.zip)

Download the most recent version for your operating system if there is a binary available. If not, you'll need to build Pythelix from source using Elixir. As long as your platform supports it (most do), this should be a straightforward process.

After downloading a binary archive, decompress it using unzip or tar. Inside the extracted directory, you will find several folders:

- **bin**: contains the binary files.
- **lib**: the libraries; you should generally avoid modifying anything here.
- **worldlets**: your [worldlet files](./worldlets.md). You may spend a lot of time here building your game.

To get started, open the "bin" directory. There are several scripts here (`.bat` files for Windows users, files without extensions otherwise):

- **apply** (or `apply.bat`): a script to apply worldlets (not needed immediately).
- **migrate** (or `migrate.bat`): a script to run database migrations.
- **script** (or `script.bat`): a script to run a [Pythelix console](./scripting.md).
- **server** (or `server.bat`): a script to start the server.

First, execute `migrate` (or `migrate.bat`) to create the database. Then, start the server by running `./server` or `server.bat` (or by double-clicking it).

This will start the Erlang Virtual Machine (BEAM). The server will request permission to use two ports — one for web connections and another for TCP connections — so you might need to allow these if your firewall prompts you (Windows may be especially cautious, so be sure to approve the access).

You can now open your favorite MUD client and connect to `localhost` on port `4000`, or connect to the web server at [http://localhost:8000](http://localhost:8000). Both ports can be configured, and you can choose to run only one of the servers if desired.

Note that `apply` and `script` need to connect to the server, so the server must be running before you use them.

To terminate the server, press CTRL + C twice in the console (on Windows, you might need to press it three times).

## Run from source

Some users prefer to run Pythelix directly from the source code. To do this, you need to install Elixir 1.18 and OTP (the higher the OTP version, the better). Installation instructions vary depending on your operating system, so you may want to [refer to the official documentation](https://elixir-lang.org/install.html).

Windows users, for example, might want to:

- [Download and install Erlang/OTP 27](https://github.com/erlang/otp/releases/download/OTP-27.3.4/otp_win64_27.3.4.exe)
- [Download and install Elixir 1.18.4 for Erlang/OTP 27](https://github.com/elixir-lang/elixir/releases/download/v1.18.4/elixir-otp-27.exe)

Once both are installed, get the code with Git:

```bash
git clone https://github.com/vincent-lg/pythelix.git
cd pythelix
mix deps.get
mix ecto.create
mix ecto.migrate
```

To start the server in development on Windows:

```bash
dev.bat
```

Or on other platforms:

```bash
./dev
```

This will start the server. You can shut it down by pressing CTRL + C twice (or three times on Windows).

You can run `apply` using `mix apply` and `script` using `mix script`. These should be run in a separate console (do not close the server console when doing so).
