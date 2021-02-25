defmodule Torrentex.Torrent.WireProtocol do
  @protocol "BitTorrent protocol"
  @keep_alive <<0::8>>

  def parse(binary) when is_binary(binary) do
    <<len::8, msg::binary-size(len), rest>> = binary
    <<id::8, payload::binary>> = msg

    event =
      case id do
        1 ->
          {:unchoke, nil}

        2 ->
          {:interested, nil}

        3 ->
          {:not_interested, nil}

        4 ->
          <<index::32>> = payload
          {:have, index}

        5 ->
          {:bitfield, bitfield_to_set(payload)}

        6 ->
          <<index::8, begin::8, length::8>> = payload
          {:request, index, begin, length}

        7 ->
          <<index::8, begin::8, block::binary>> = payload
          {:piece, index, begin, block}

        8 ->
          <<index::8, begin::8, length::8>> = payload
          {:cancel, index, begin, length}

        9 ->
          <<port::16>> = payload
          {:port, port}
      end

    {rest, event}
  end

  defp bitfield_to_set(bits) when is_binary(bits), do: bitfield_to_set(bits, 0, MapSet.new())

  defp bitfield_to_set(<<h::1, t::bitstring>> = bitstring, idx, previous)
       when is_bitstring(bitstring) do
    if h == 0 do
      bitfield_to_set(t, idx + 1, previous)
    else
      bitfield_to_set(t, idx + 1, previous |> MapSet.put(idx))
    end
  end

  defp bitfield_to_set(<<>>, _idx, previous), do: previous

  defguard is_20_bytes(binary) when is_binary(binary) and byte_size(binary) == 20

  def handshake(info_hash, peer_id) when is_20_bytes(info_hash) and is_20_bytes(peer_id) do
    zero_bytes = <<0::size(64)>>
    <<19::8, @protocol, zero_bytes::binary, info_hash::binary, peer_id::binary>>
  end

  def match_handshake(binary) when is_binary(binary) do
    <<19, @protocol, _::binary-size(8), hash::binary-size(20), id::binary-size(20), rest::binary>> =
      binary

    {rest, {hash, id}}
  end
end
