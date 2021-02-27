defmodule Torrentex.Torrent.PeerConnectionTest do
  use ExUnit.Case
  alias Torrentex.Torrent.PeerConnection
  alias Torrentex.Torrent.Tracker
  alias Torrentex.Torrent.WireProtocol

  test "handshake is correct" do
    <<peer_id::binary>> = Tracker.generate_peer_id()
    # peer_id & info hash have the same length.
    <<info_hash::binary>> = Tracker.generate_peer_id()

    {"", {:handshake, {hash, id}}} =
      WireProtocol.handshake(info_hash, peer_id) |> WireProtocol.encode() |> WireProtocol.parse()

    assert hash == info_hash
    assert id == peer_id
  end
end
