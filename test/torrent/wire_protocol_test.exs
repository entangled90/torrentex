defmodule Torrentex.Torrent.WireProtocolTest do
  use ExUnit.Case
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
      msgs =
        events
        |> Enum.map(&WireProtocol.encode(&1))
        |> Enum.reduce(&(&1 <> &2))
        |> WireProtocol.parseMulti()

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

  def append_bits(bits, binary), do: <<bits::binary, binary::binary>>

  def positive_generator, do: StreamData.integer(0..1024)

  def peer_id_generator, do: StreamData.binary(length: 20)

  def event_generator do
    tuple_three = StreamData.tuple({positive_generator, positive_generator, positive_generator})

    piece_generator =
      tuple_three
      |> StreamData.bind(fn {idx, begin, len} ->
        StreamData.binary(length: len)
        |> StreamData.map(fn bin ->
          WireProtocol.piece(idx, begin, bin)
        end)
      end)

    StreamData.one_of([
      StreamData.constant(WireProtocol.choke()),
      StreamData.constant(WireProtocol.unchoke()),
      StreamData.constant(WireProtocol.interested()),
      StreamData.constant(WireProtocol.not_interested()),
      positive_generator |> StreamData.map(&WireProtocol.have(&1)),
      tuple_three |> StreamData.map(&{:request, &1}),
      tuple_three |> StreamData.map(&{:cancel, &1}),
      StreamData.integer(0..65535) |> StreamData.map(&WireProtocol.port(&1)),
      piece_generator,
      bitfield_gen(),
      StreamData.tuple({peer_id_generator, peer_id_generator}) |> StreamData.map(fn {peer_id, hash} -> WireProtocol.handshake(peer_id, hash)end )
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
