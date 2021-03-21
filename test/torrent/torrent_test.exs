defmodule Torrentex.Torrent.ChunkTest do
  alias Torrentex.Torrent.Torrent

  use ExUnit.Case, async: true
  use ExUnitProperties

  property "binary_in_chunks" do
    check all(
            size <- StreamData.positive_integer(),
            binary <- StreamData.binary(length: size * 8),
            chunk_len <- StreamData.integer(1..size)
          ) do
      chunked = Torrent.binary_in_chunks(binary, chunk_len)
      assert length(chunked) >= div(size, chunk_len)
      Enum.each(chunked, fn chunk -> assert byte_size(chunk) <= chunk_len end)
    end
  end

  test "binary_in_chunks - specific input" do
    binary = <<0::16>>
    chunk_len = 1
    chunked = Torrent.binary_in_chunks(binary, chunk_len)
    assert chunked == [<<0::8>>, <<0::8>>]
  end
end
