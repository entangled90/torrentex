# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#


# PHOENIX APP Config

# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
# use Mix.Config

config :web_frontend,
  ecto_repos: [WebFrontend.Repo]

# Configures the endpoint
config :web_frontend, WebFrontendWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Wq0ZUzndhDivs8tGPW5A51rn+e3KEk1agwRVhQocv1u1X8jTuGx9sHoNSM8N82OX",
  render_errors: [view: WebFrontendWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: WebFrontend.PubSub,
  live_view: [signing_salt: "fsXBjnv6"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
