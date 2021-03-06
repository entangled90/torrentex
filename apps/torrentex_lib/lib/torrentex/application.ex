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
      # {TorrentexLib.Torrent.Torrent, "../../data/ubuntu-20.04.2.0-desktop-amd64.iso.torrent"}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TorrentexLib.Supervisor]
    {:ok, _pid} = Supervisor.start_link(children, opts)

  end



end
