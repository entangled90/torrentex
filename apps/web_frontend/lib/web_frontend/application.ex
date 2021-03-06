defmodule WebFrontend.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      WebFrontend.Repo,
      # Start the Telemetry supervisor
      WebFrontendWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: WebFrontend.PubSub},
      # Start the Endpoint (http/https)
      WebFrontendWeb.Endpoint
      # Start a worker by calling: WebFrontend.Worker.start_link(arg)
      # {WebFrontend.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WebFrontend.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    WebFrontendWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
