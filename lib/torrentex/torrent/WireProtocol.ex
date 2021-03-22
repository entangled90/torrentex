defmodule Torrentex.Torrent.WireProtocol do
  @protocol "BitTorrent protocol"
  @keep_alive <<0::32>>

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
           | :choke
           | :handshake
           | :keep_alive,
           nil
           | binary()
           | integer()
           | {integer(), integer(), iolist() | binary() | integer()}
           | {binary(), binary()}
           | {MapSet.t(integer()), integer()}}

  defguard is_20_bytes(binary) when is_binary(binary) and byte_size(binary) == 20

  @spec keep_alive :: message()
  def keep_alive(), do: {:keep_alive, nil}

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

  @spec request(integer(), integer(), integer()) :: message()
  def request(idx, begin, length), do: {:request, {idx, begin, length}}

  @spec piece(integer, pos_integer, iodata()) :: message()
  def piece(index, begin, bin) when is_integer(index) and is_integer(begin),
    do: {:piece, {index, begin, bin}}

  @spec bitfield(MapSet.t(integer()), integer()) :: message()
  def bitfield(set, len), do: {:bitfield, {set, len}}

  @spec handshake(binary, binary) :: message()
  def handshake(peer_id, info_hash) when is_20_bytes(info_hash) and is_20_bytes(peer_id),
    do: {:handshake, {peer_id, info_hash}}

  @spec cancel(integer, pos_integer, pos_integer) :: message()
  def cancel(index, begin, length), do: {:cancel, {index, begin, length}}

  @spec parse_multi(iodata()) :: {[message()], binary()}
  def parse_multi(binary) do
    parse_multi(binary, [])
  end

  defp parse_multi(binary, acc) do
    {rest, msg} = parse(binary)

    if msg do
      acc = [msg | acc]
      case rest do
        [_h | _t] -> parse_multi(rest, acc)
        [] -> {acc, rest}
        <<>> -> {acc, rest}
        rest -> parse_multi(rest, acc)
      end
    else
      {acc, rest}
    end
  end

  @spec parse(iodata()) :: {iodata(), message() | nil}
  def parse(
        <<19, @protocol, _::binary-size(8), hash::binary-size(20), id::binary-size(20),
          rest::binary>>
      ),
      do: {rest, {:handshake, {id, hash}}}

  def parse([<<len::32, 7::8, index::32, begin::32, rem::binary>> | tail]) do
    case rem do
      <<block::binary-size(len), other::binary>> ->
        {combine_to_list(other, tail), piece(index, begin, block)}

      rem ->
        {_, pieces, next_pieces} =
          for bytes <- [rem | tail], reduce: {0, [], []} do
            {size, pieces, next_msg_pieces} ->
              if size >= len do
                {size, pieces, [bytes | next_msg_pieces]}
              else
                final_piece_len = len - size

                case bytes do
                  # this is the last piece for completing the block
                  <<final_piece::binary-size(final_piece_len), remaining::binary>> ->
                    {len, [final_piece | pieces], combine_to_list(remaining, next_msg_pieces)}

                  _ ->
                    {size + byte_size(bytes), [bytes | pieces], next_msg_pieces}
                end
              end
          end

        {:lists.reverse(next_pieces), piece(index, begin, :lists.reverse(pieces))}
    end
  end

  # unoptimized case for all other msg types
  def parse([_h |_t] = iolist), do: parse(IO.iodata_to_binary(iolist))
  def parse([]), do: {<<>>, nil}

  def parse(<<len::32, msg::binary-size(len), rest::binary>>) do
    event =
      if len == 0 do
        keep_alive()
      else
        <<id::8, payload::binary>> = msg

        case id do
          0 ->
            choke()

          1 ->
            unchoke()

          2 ->
            interested()

          3 ->
            not_interested()

          4 ->
            <<index::32>> = payload
            have(index)

          5 ->
            {set, len} = bitfield_to_set(payload)
            bitfield(set, len)

          6 ->
            <<index::32, begin::32, length::32>> = payload
            request(index, begin, length)

          7 ->
            <<index::32, begin::32, block::binary>> = payload
            piece(index, begin, block)

          8 ->
            <<index::32, begin::32, length::32>> = payload
            cancel(index, begin, length)

          9 ->
            <<port::16>> = payload
            port(port)
        end
      end

    {rest, event}
  end

  def parse(<<bin::binary>>), do: {bin, nil}

  @spec encode(message()) :: <<_::40, _::_*8>>
  def encode({:choke, nil}), do: <<1::32, 0::8>>
  def encode({:unchoke, nil}), do: <<1::32, 1::8>>
  def encode({:interested, nil}), do: <<1::32, 2::8>>
  def encode({:not_interested, nil}), do: <<1::32, 3::8>>
  def encode({:have, index}), do: <<5::32, 4::8, index::32>>

  def encode({:handshake, {peer_id, info_hash}})
      when is_20_bytes(info_hash) and is_20_bytes(peer_id) do
    zero_bytes = <<0::size(64)>>
    <<19::8, @protocol, zero_bytes::binary, info_hash::binary, peer_id::binary>>
  end

  def encode({:bitfield, {set, len}}) do
    bits =
      0..(len - 1)
      |> Enum.map(fn x -> if MapSet.member?(set, x), do: <<1::1>>, else: <<0::1>> end)
      |> :erlang.list_to_bitstring()
      |> pad_to_binary()

    <<1 + byte_size(bits)::32, 5::8, bits::binary>>
  end

  def encode({:request, {index, begin, length}}),
    do: <<13::32, 6::8, index::32, begin::32, length::32>>

  def encode({:piece, {index, begin, <<block::binary>>}}),
    do: <<9 + byte_size(block)::32, 7::8, index::32, begin::32, block::binary>>

  def encode({:cancel, {index, begin, length}}),
    do: <<13::32, 8::8, index::32, begin::32, length::32>>

  def encode({:port, port}), do: <<3::32, 9::8, port::16>>

  def encode({:keep_alive, nil}), do: @keep_alive

  @spec bitfield_to_set(binary()) :: {MapSet.t(integer()), integer()}
  defp bitfield_to_set(<<bits::binary>>), do: bitfield_to_set(bits, 0, MapSet.new(), 0)

  defp bitfield_to_set(<<h::1, t::bitstring>>, idx, previous, len) do
    if h == 0 do
      bitfield_to_set(t, idx + 1, previous, len + 1)
    else
      bitfield_to_set(t, idx + 1, previous |> MapSet.put(idx), len + 1)
    end
  end

  defp bitfield_to_set(<<>>, _idx, previous, len), do: {previous, next_binary_size(len)}

  defp pad_to_binary(bitstring) do
    size = bit_size(bitstring)

    if rem(size, 8) == 0 do
      bitstring
    else
      padding = next_binary_size(size) - size
      <<bitstring::bitstring, 0::size(padding)>>
    end
  end

  @spec next_binary_size(integer) :: integer
  def next_binary_size(bit_size) do
    if rem(bit_size, 8) == 0 do
      bit_size
    else
      (div(bit_size, 8) + 1) * 8
    end
  end

  defp combine_to_list(bin, list), do: if byte_size(bin) > 0, do: [bin | list], else: list

end
