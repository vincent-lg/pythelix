import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/pythelix start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :pythelix, PythelixWeb.Endpoint, server: true
end

alias Pythelix.Settings

# The game's root: PYTHELIX_DIR > RELEASE_ROOT > the working directory.
# The settings file, and every relative path in it, live there.
base_dir =
  System.get_env("PYTHELIX_DIR") ||
    System.get_env("RELEASE_ROOT") ||
    File.cwd!()

# In a release, settings come from `settings.txt` at the game's root, a plain
# NAME=value file generated with comments on first start. In development and
# test, config.exs is the source and only environment variables apply.
settings =
  if config_env() == :prod do
    settings_path = Settings.path(base_dir)

    # Before `settings.txt`, the same values lived in a hidden `.env` file in
    # the user's data directory. Carry them over (the secret key base above
    # all) so an upgrade doesn't silently sign the web sessions with a new
    # secret, then let the new file take over.
    legacy =
      case Settings.read(Path.join(:filename.basedir(:user_data, "pythelix"), ".env")) do
        {:ok, values} -> values
        :nofile -> %{}
      end

    Settings.ensure!(settings_path, legacy)
  else
    %{}
  end

# A setting is looked up in the environment first (under every name listed),
# then in the file, then falls back to the default.
setting = fn names, default -> Settings.get(settings, names, default) end

# Encodings. The list of supported names belongs to the module that does the
# decoding, so that adding one is a single change.
validate_encoding = fn name, value ->
  if Code.ensure_loaded?(Pythelix.Network.Encoding) and
       not Pythelix.Network.Encoding.supported?(value) do
    supported = Pythelix.Network.Encoding.supported_encodings() |> Enum.sort() |> Enum.join(", ")
    raise "#{name} is set to #{inspect(value)}, which is not a supported encoding (#{supported})"
  end

  value
end

default_encoding =
  setting.(["DEFAULT_ENCODING", "PYTHELIX_DEFAULT_ENCODING"], nil)

if default_encoding do
  config :pythelix, default_encoding: validate_encoding.("DEFAULT_ENCODING", default_encoding)
end

# How a worldlet or scenario file is read when it isn't valid UTF-8. Left
# empty, it follows DEFAULT_ENCODING (see `Pythelix.Encoding`).
worldlets_encoding =
  setting.(["WORLDLETS_ENCODING", "PYTHELIX_WORLDLETS_ENCODING"], nil)

if worldlets_encoding do
  config :pythelix,
    worldlets_encoding: validate_encoding.("WORLDLETS_ENCODING", worldlets_encoding)
end

# Generic entity keys. For example: GENERIC_CLIENT=my/client GENERIC_MENU=my/menu
generic_overrides =
  [:client, :character, :menu, :command, :rangen, :calendar]
  |> Enum.map(fn kind ->
    {kind, setting.(["GENERIC_" <> String.upcase(to_string(kind))], nil)}
  end)
  |> Enum.reject(fn {_kind, value} -> is_nil(value) end)

if generic_overrides != [] do
  existing = Application.get_env(:pythelix, :generic_entities, [])
  config :pythelix, :generic_entities, Keyword.merge(existing, generic_overrides)
end

# Where plugins are, for a command run from source: the registry's CI validates
# plugins kept in its own repository rather than in this one.
if config_env() != :prod do
  plugins_path = setting.(["PLUGINS_PATH"], nil)

  if plugins_path do
    config :pythelix, plugins_path: Path.expand(plugins_path)
  end
end

plugin_index_url = setting.(["PLUGIN_INDEX_URL"], nil)

if plugin_index_url do
  config :pythelix, plugin_index_url: plugin_index_url
end

if config_env() == :prod do
  # Resolve a path setting. Absolute paths are used as-is; relative paths are
  # joined with the game's root.
  resolve_path = fn key, default ->
    path = setting.([key], default)

    if Path.type(path) == :absolute do
      path
    else
      Path.join(base_dir, path)
    end
  end

  database_path = resolve_path.("DATABASE_PATH", "pythelix.db")
  worldlets_path = resolve_path.("WORLDLETS_PATH", "worldlets")
  plugins_path = resolve_path.("PLUGINS_PATH", "plugins")
  scenarios_path = resolve_path.("SCENARIOS_PATH", "scenarios")
  tasks_path = resolve_path.("TASKS_PATH", "tasks")

  config :pythelix,
    base_path: base_dir,
    worldlets_path: worldlets_path,
    plugins_path: plugins_path,
    scenarios_path: scenarios_path,
    tasks_path: tasks_path,
    telnet_port: String.to_integer(setting.(["TELNET_PORT"], "4000"))

  config :pythelix, Pythelix.Repo,
    database: database_path,
    pool_size: String.to_integer(setting.(["POOL_SIZE"], "5"))

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so it lives in the settings
  # file, generated once for this game.
  secret_key_base = setting.(["SECRET_KEY_BASE"], nil)

  host = setting.(["PHX_HOST"], "example.com")
  port = String.to_integer(setting.(["WEB_PORT", "PORT"], "8000"))

  config :pythelix, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :pythelix, PythelixWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :pythelix, PythelixWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/cert/selfsigned_key.pem". For all other options, see
  # https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :pythelix, PythelixWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :pythelix, Pythelix.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.ApiClient.Hackney for more information.
end
