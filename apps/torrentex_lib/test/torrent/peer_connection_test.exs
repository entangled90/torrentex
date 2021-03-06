defmodule TorrentexLib.Torrent.PeerConnectionTest do
  use ExUnit.Case
  alias TorrentexLib.Torrent.PeerConnection
  alias TorrentexLib.Torrent.Tracker
  alias TorrentexLib.Torrent.WireProtocol

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
