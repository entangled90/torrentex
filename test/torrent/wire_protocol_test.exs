defmodule Torrentex.Torrent.WireProtocolTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Torrentex.Torrent.WireProtocol

  property "wire protocol encode/decode roundtrip with exact length" do
    check all(event <- event_generator()) do
      {_, decoded} = event |> WireProtocol.encode() |> WireProtocol.parse()
      assert decoded == event
    end
  end

  property "wire protocol encode/decode multiple roundtrip" do
    check all(events <- StreamData.list_of(event_generator(), min_length: 1, max_length: 128)) do
      {msgs, <<>>} =
        events
        |> Enum.map(&WireProtocol.encode(&1))
        |> Enum.reduce(&(&1 <> &2))
        |> WireProtocol.parse_multi()

      assert events == msgs
    end
  end

  property "wire protocol encode/decode multiple roundtrip plus some binary left" do
    check all(events <- StreamData.list_of(event_generator(), min_length: 1, max_length: 128)) do
      {msgs, <<>>} =
        events
        |> Enum.map(&WireProtocol.encode(&1))
        |> Enum.reduce(&(&1 <> &2))
        |> WireProtocol.parse_multi()

      assert events == msgs
    end
  end

  property "wire protocol encode/decode roundtrip with remaining bytes" do
    check all(event <- event_generator(), remaining_bytes <- StreamData.binary(max_length: 128)) do
      {remaining_bytes, decoded} =
        event |> WireProtocol.encode() |> append_bits(remaining_bytes) |> WireProtocol.parse()

      assert decoded == event
    end
  end

  property "proper piece test: message split into multiple packets" do
    piece_len = :math.pow(2, 14) |> round()

    check all(
            bin <- StreamData.binary(length: piece_len),
            idx <- StreamData.positive_integer(),
            begin <- StreamData.positive_integer()
          ) do
      message = WireProtocol.piece(idx, begin, bin)
      encoded = WireProtocol.encode(message)
      <<first::binary-size(1024), snd::binary>> = encoded
      {[], first} = WireProtocol.parse_multi(first)
      {[decoded], <<>>} = WireProtocol.parse_multi(first <> snd)
      assert message == decoded
    end
  end

  property "piece split into iolist" do
    check all (
      piece <- piece_generator()
    ) do
      encoded = WireProtocol.encode(piece)
      len = byte_size(encoded)
      first = :binary.bin_to_list(encoded, {0, div(len, 2)})
      second = :binary.bin_to_list(encoded, {div(len, 2), len - div(len, 2)})
      {_, piece_decoded} = WireProtocol.parse([first| second])
      assert piece_decoded == piece
    end
  end

  def append_bits(bits, binary), do: <<bits::binary, binary::binary>>

  def positive_generator, do: StreamData.integer(0..1024)

  def peer_id_generator, do: StreamData.binary(length: 20)

  def tuple_three, do: StreamData.tuple({positive_generator, positive_generator, positive_generator})

  def piece_generator do
    tuple_three
    |> StreamData.bind(fn {idx, begin, len} ->
      StreamData.binary(length: len)
      |> StreamData.map(fn bin ->
        WireProtocol.piece(idx, begin, bin)
      end)
    end)
  end

  def event_generator do

    StreamData.one_of([
      StreamData.constant(WireProtocol.choke()),
      StreamData.constant(WireProtocol.unchoke()),
      StreamData.constant(WireProtocol.interested()),
      StreamData.constant(WireProtocol.not_interested()),
      positive_generator |> StreamData.map(&WireProtocol.have(&1)),
      tuple_three |> StreamData.map(&{:request, &1}),
      tuple_three |> StreamData.map(&{:cancel, &1}),
      StreamData.integer(0..65_535) |> StreamData.map(&WireProtocol.port(&1)),
      piece_generator(),
      bitfield_gen(),
      StreamData.tuple({peer_id_generator, peer_id_generator})
      |> StreamData.map(fn {peer_id, hash} -> WireProtocol.handshake(peer_id, hash) end)
    ])
  end

  def bitfield_gen() do
    StreamData.integer(1..16)
    |> StreamData.bind(fn len ->
      len = len * 8
      set = MapSet.new()

      StreamData.list_of(StreamData.integer(0..(len - 1)), min_length: len, max_length: len)
      |> StreamData.map(fn l ->
        set =
          l
          |> Enum.reduce(set, fn idx, set -> MapSet.put(set, idx) end)
          |> WireProtocol.bitfield(length(l))
      end)
    end)
  end
end
