defmodule TorrentexLib.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: TorrentexLib.Worker.start_link(arg)
      {TorrentexLib.TorrentSupervisor, [name: TorrentexLib.TorrentSupervisor]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TorrentexLib.AppSupervisor]
    {:ok, _pid} = Supervisor.start_link(children, opts)

  end



end
