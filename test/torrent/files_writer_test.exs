defmodule Torrentex.Torrent.FilesWriterTest do
  alias Torrentex.Torrent.FilesWriter
  use ExUnit.Case

  test "short_pieces" do
    files = %{"a" => %{length: 69}, "b" => %{length: 33}}
    short = FilesWriter.short_pieces(files, 16)
    assert short == %{4 => 5, 7 => 1}

    files = %{"a" => %{length: 64}, "b" => %{length: 32}}
    short = FilesWriter.short_pieces(files, 16)
    assert short == %{}

    files = %{"a" => %{length: 98}}
    short = FilesWriter.short_pieces(files, 15)
    assert short == %{6 => 8}
  end

  test "partition_piece" do
    partitioned = FilesWriter.partition_piece(32, 16)
    assert partitioned == %{0 => 16, 16 => 16}

    partitioned = FilesWriter.partition_piece(39, 16)
    assert partitioned == %{0 => 16, 16 => 16, 32 => 7}

    partitioned = FilesWriter.partition_piece(39, 16)
    assert partitioned == %{0 => 16, 16 => 16, 32 => 7}
  end


  test "should load downloaded file correctly" do
    # this file was downloaded with transmission, sha256 match with original
    # if missing download it and place it in the folder.
    {metainfo, _info_hash} = Torrentex.Torrent.Parser.decode_torrent("data/ubuntu-20.04.2.0-desktop-amd64.iso.torrent")
    {:ok, files_writer} = FilesWriter.start_link(metainfo: metainfo.info, download_folder: "data/downloaded")
    written = FilesWriter.downloaded_pieces(files_writer)
    num_pieces = byte_size(metainfo.info.pieces) / 20
    assert MapSet.size(written) == num_pieces
  end
end
