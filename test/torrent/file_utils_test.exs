defmodule Torrentex.Torrent.FileUtilsSpec do
  import Torrentex.Torrent.FileUtils
  alias Torrentex.Torrent.Torrent

  use ExUnit.Case

  test "write correctly chunks of file" do
    file_name = "test_file.bin"
    handle = File.open!(file_name, [:write, :raw])

    for i <- 0..127 do
      write_at(handle, i * 8, <<i::64>>)
    end

    File.close(handle)

    content =
      try do
        File.read!(file_name)
      after
        File.rm(file_name)
      end

    # 8 bytes
    chunks = Torrent.binary_in_chunks(content, 8)
    assert length(chunks) == 128

    for {chunk, i} <- chunks |> Enum.with_index() do
      assert chunk == <<i::64>>
    end
  end

  test "read pieces & verify hash correctly when hashes are correct" do
    file_name = "hashes_file.bin"


    hashes = write_idx(file_name, 0..127)

    pieces =
      try do
        load_downloaded_pieces(file_name, 8, hashes)
      after
        File.rm(file_name)
      end

    for i <- 0..127 do
      assert MapSet.member?(pieces, i)
    end
  end


  test "read pieces & verify hash correctly when not all file is written" do
    file_name = "hashes_file.bin"


    hashes = write_idx(file_name, 0..63)

    pieces =
      try do
        load_downloaded_pieces(file_name, 8, hashes)
      after
        File.rm(file_name)
      end

    for i <- 0..127 do
      assert MapSet.member?(pieces, i) == (i < 64)
    end
  end



  test "read pieces & verify hash correctly when some pieces have wrong hash" do
    file_name = "hashes_file.bin"


    hashes = write_idx(file_name, 0..127)
    wrong_hash = :crypto.hash(:sha, <<0::64>>)
    hashes = Enum.take(hashes, 64) ++ Enum.to_list(for _ <- 0..63, do: wrong_hash)
    pieces =
      try do
        load_downloaded_pieces(file_name, 8, hashes)
      after
        File.rm(file_name)
      end

    for i <- 0..127 do
      assert MapSet.member?(pieces, i) == (i < 64)
    end
  end


  def write_idx(name, idxs) do
    handle = File.open!(name, [:write, :raw])
    hashes =
      for i <- idxs do
        piece = <<i::64>>
        write_at(handle, i * 8, piece)
        :crypto.hash(:sha, piece)
      end

    File.close(handle)

    hashes
  end
end
