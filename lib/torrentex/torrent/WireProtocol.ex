defmodule Torrentex.Torrent.WireProtocol do
  @protocol "BitTorrent protocol"
  @keep_alive <<0::8>>

  @typedoc """
    Messages sent to other peers.
  """
  @type message() ::
          {:bitfield
           | :cancel
           | :have
           | :interested
           | :not_interested
           | :piece
           | :port
           | :request
           | :unchoke
           | :choke,
           nil | binary | integer | {integer, integer, binary | integer} | MapSet.t(integer())}

  @spec choke :: message()
  def choke(), do: {:choke, nil}

  @spec unchoke :: message()
  def unchoke(), do: {:unchoke, nil}

  @spec interested :: message()
  def interested(), do: {:interested, nil}

  @spec not_interested :: message()
  def not_interested(), do: {:not_interested, nil}

  @spec port(integer()) :: message()
  def port(port), do: {:port, port}

  @spec have(integer()) :: message()
  def have(index), do: {:have, index}

  @spec piece(integer, integer, binary) :: message()
  def piece(index, begin, bin) when is_binary(bin) and is_integer(index) and is_integer(begin),
    do: {:piece, {index, begin, bin}}

  @spec bitfield(binary) :: message()
  def bitfield(bitfield) when is_binary(bitfield), do: {:bitfield, bitfield}

  @spec parseMulti(binary) :: [message()]
  def parseMulti(binary) do
    parseMulti(binary, [])
  end

  defp parseMulti(binary, acc) do
    {rest, msg} = parse(binary)
    acc = [msg | acc]
    if byte_size(rest) > 0, do: parseMulti(rest, acc), else: acc
  end

  @spec parse(<<_::32, _::_*8>>) :: {binary, message()}
  def parse(binary) when is_binary(binary) do
    <<len::32, msg::binary-size(len), rest::binary>> = binary
    <<id::8, payload::binary>> = msg

    event =
      case id do
        0 ->
          {:choke, nil}

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
          <<index::32, begin::32, length::32>> = payload
          {:request, {index, begin, length}}

        7 ->
          <<index::32, begin::32, block::binary>> = payload
          {:piece, {index, begin, block}}

        8 ->
          <<index::32, begin::32, length::32>> = payload
          {:cancel, {index, begin, length}}

        9 ->
          <<port::16>> = payload
          {:port, port}
      end

    {rest, event}
  end

  @spec encode(message()) :: <<_::40, _::_*8>>
  def encode({:choke, nil}), do: <<1::32, 0::8>>
  def encode({:unchoke, nil}), do: <<1::32, 1::8>>
  def encode({:interested, nil}), do: <<1::32, 2::8>>
  def encode({:not_interested, nil}), do: <<1::32, 3::8>>
  def encode({:have, index}), do: <<5::32, 4::8, index::32>>

  def encode({:bitfield, bitfield}),
    do: <<1 + byte_size(bitfield)::32, 5::8, bitfield::binary>>

  def encode({:request, {index, begin, length}}),
    do: <<13::32, 6::8, index::32, begin::32, length::32>>

  def encode({:piece, {index, begin, block}}) when is_binary(block),
    do: <<9 + byte_size(block)::32, 7::8, index::32, begin::32, block::binary>>

  def encode({:cancel, {index, begin, length}}),
    do: <<13::32, 8::8, index::32, begin::32, length::32>>

  def encode({:port, port}), do: <<3::32, 9::8, port::16>>

  @spec bitfield_to_set(binary) :: MapSet.t(integer())
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
