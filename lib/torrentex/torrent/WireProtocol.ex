defmodule Torrentex.Torrent.WireProtocol do

  @protocol "BitTorrent protocol"
  @keep_alive <<0::8>>

  defguard is_20_bytes(binary) when is_binary(binary) and  byte_size(binary) == 20

  def handshake(info_hash, peer_id) when is_20_bytes(info_hash) and is_20_bytes(peer_id) do
    zero_bytes = <<0::size(64)>>
    <<19::8, @protocol, zero_bytes::binary, info_hash::binary, peer_id::binary>>
  end

  def match_handshake(binary) when is_binary(binary) do
    <<19, @protocol, _ ::binary-size(8), hash::binary-size(20), id::binary-size(20), rest :: binary>> = binary
    {rest, {hash, id}}
  end

end
