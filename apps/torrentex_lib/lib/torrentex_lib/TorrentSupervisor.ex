defmodule TorrentexLib.TorrentSupervisor do
  alias TorrentexLib.Torrent.Torrent

  use DynamicSupervisor

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_peer_connection(pid, args) do
    DynamicSupervisor.start_child(pid, peer_child_spec(args))
  end

  defp peer_child_spec(args) do
    %{
      id: Torrent,
      start: {PeerConnection, :start_link, [args]},
      restart: :transient
    }
  end
end
