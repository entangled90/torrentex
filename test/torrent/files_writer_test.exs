defmodule Torrentex.Torrent.FilesWriterTest do
  alias Torrentex.Torrent.FilesWriter
  use ExUnit.Case

  test "short_pieces" do
    files = %{"a" => %{length: 69}, "b" => %{length: 33}}
    short = FilesWriter.short_pieces(files, 16)
    assert short == %{5 => 5, 8 => 1}

    files = %{"a" => %{length: 64}, "b" => %{length: 32}}
    short = FilesWriter.short_pieces(files, 16)
    assert short == %{}
  end

  test "partition_piece" do
    partitioned = FilesWriter.partition_piece(32, 16)
    assert partitioned == %{0 => 16, 16 => 16}

    partitioned = FilesWriter.partition_piece(39, 16)
    assert partitioned == %{0 => 16, 16 => 16, 32 => 7}

    partitioned = FilesWriter.partition_piece(39, 16)
    assert partitioned == %{0 => 16, 16 => 16, 32 => 7}
  end
end
