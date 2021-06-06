# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :my_app,
  ecto_repos: [MyApp.Repo]

# Configures the endpoint
config :my_app, MyAppWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "8crefPaCeFkNCpsp378uYD5OkUqXMXTwX5MTXOnmBsPKjXwnkVplDKkaaNNRpitH",
  render_errors: [view: MyAppWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: MyApp.PubSub,
  live_view: [signing_salt: "UH8gJw0o"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :my_app, MyApp.Guardian,
	issuer: "my_app",
	secret_key: "EI2tyig/pR4E5LD/PbEpU+aMGlbGR5g6JCktEqrVzU6dVO8YK/QkLGCWFM4lPWAE",
  ttl: {3, :days}

# config :my_app, MyApp.AuthAccessPipeline,
#   module: MyApp.Guardian,
#   error_handler: MyApp.AuthErrorHandler

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
