defmodule Torrentex.Torrent.PeerConnectionSupervisor do
  alias Torrentex.Torrent.{Peer, PeerConnection}

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
    peer = Keyword.fetch!(args, :peer)

    %{
      id: Peer.show(peer),
      start: {PeerConnection, :start_link, [args]},
      restart: :transient
    }
  end
end
