defmodule TorrentexLib.Torrent.ParserTest do
  use ExUnit.Case
  alias TorrentexLib.Torrent.Parser

  test "info hash is correct" do
    expected = "info_hash=K%A4%FB%F7%23%1A%3Af%0E%86%89%27%07%D2%5C%13U3%A1j"
    {_torrent, hash} = Parser.decode_torrent("../../data/ubuntu-20.04.2.0-desktop-amd64.iso.torrent")
    assert URI.encode_query(%{info_hash: hash}) == expected
  end
end
