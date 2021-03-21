defmodule Torrentex.Torrent.TrackerTest do
  use ExUnit.Case, async: true
  alias Torrentex.Torrent.Tracker
  alias Torrentex.Torrent.Parser
  alias Torrentex.Torrent.Torrent.State.DownloadStatus

  test "tracker for ubuntu replies" do
    {torrent, hash} = Parser.decode_torrent("data/ubuntu-20.04.2.0-desktop-amd64.iso.torrent")
    status = Torrentex.Torrent.Torrent.DownloadStatus.for_torrent(torrent.info)

    {:ok, decoded} =
      Tracker.call_tracker(torrent.announce, hash, Tracker.generate_peer_id(), status, "started")

    assert length(decoded["peers"]) > 0
  end
end
