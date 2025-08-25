import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :pythelix, Pythelix.Repo,
  database: Path.expand("../pythelix_test.db", __DIR__),
  #database: ":memory:",
  #database: "file::memory:?cache=shared",
  pool_size: 5,
  #pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox

# We disable the worldlet creation for tests.
config :pythelix,
  worldlets: false,
  show_stats: false,
  sync_script_execution: true

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :pythelix, PythelixWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "N+lQCXSUGqU8ES/z3I6/cWGATH4tOpR/Cz3grDfa+KupPP2Gup6vNr02lOoBhNop",
  server: false

# In test we don't send emails
config :pythelix, Pythelix.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning
config :logger, :console, format: "[$level] $message"

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Disable libcluster in text
config :libcluster,
  topologies: nil
