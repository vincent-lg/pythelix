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

# Generic entity names can be overridden via environment variables.
# For example: GENERIC_CLIENT=my/client GENERIC_MENU=my/menu
generic_overrides =
  [
    {:client, System.get_env("GENERIC_CLIENT")},
    {:character, System.get_env("GENERIC_CHARACTER")},
    {:menu, System.get_env("GENERIC_MENU")},
    {:command, System.get_env("GENERIC_COMMAND")},
    {:rangen, System.get_env("GENERIC_RANGEN")},
    {:calendar, System.get_env("GENERIC_CALENDAR")}
  ]
  |> Enum.reject(fn {_k, v} -> is_nil(v) end)

if generic_overrides != [] do
  existing = Application.get_env(:pythelix, :generic_entities, [])
  config :pythelix, :generic_entities, Keyword.merge(existing, generic_overrides)
end

if config_env() == :prod do
  # Load (or create and load) an environment file.
  env_path = :filename.basedir(:user_data, "pythelix")

  if !File.exists?(env_path) do
    File.mkdir_p!(env_path)
  end

  env_file = Path.join(env_path, ".env")

  if !File.exists?(env_file) do
    IO.puts("Generating default environment file: #{env_file}")

    secret =
      :crypto.strong_rand_bytes(64)
      |> Base.encode64()

    File.write!(env_file, """
    DATABASE_PATH=pythelix.db
    WORLDLETS_PATH=worldlets
    TASKS_PATH=tasks
    SECRET_KEY_BASE=#{secret}
    """)
  end

  env_vars =
    File.read!(env_file)
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      [key, val] = String.split(String.trim(line), "=", parts: 2)
      {key, val}
    end)
    |> Enum.into(%{})

  # Base directory: PYTHELIX_DIR > RELEASE_ROOT > cwd
  base_dir =
    System.get_env("PYTHELIX_DIR") ||
      System.get_env("RELEASE_ROOT") ||
      File.cwd!()

  # Resolve a path config value: env var > .env file > default.
  # Absolute paths are used as-is; relative paths are joined with base_dir.
  resolve_path = fn key, default ->
    path = System.get_env(key) || env_vars[key] || default

    if Path.type(path) == :absolute do
      path
    else
      Path.join(base_dir, path)
    end
  end

  database_path = resolve_path.("DATABASE_PATH", "pythelix.db")
  worldlets_path = resolve_path.("WORLDLETS_PATH", "worldlets")
  tasks_path = resolve_path.("TASKS_PATH", "tasks")
  default_encoding = System.get_env("PYTHELIX_DEFAULT_ENCODING", "utf-8")

  if !Enum.member?(["iso-8859-1", "iso-8859-15", "cp1252", "utf-8"], default_encoding) do
    raise "unknown default encoding #{default_encoding}"
  end

  config :pythelix,
    worldlets_path: worldlets_path,
    tasks_path: tasks_path,
    default_encoding: default_encoding

  config :pythelix, Pythelix.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base = env_vars["SECRET_KEY_BASE"]

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "8000")

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
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
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
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
