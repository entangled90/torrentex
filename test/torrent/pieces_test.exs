defmodule Torrentex.Torrent.PiecesTest do
  use ExUnit.Case
  import Mock
  alias Torrentex.Torrent.{Pieces, FilesWriter}

  test "can start download everything" do
    with_mock FilesWriter, downloaded_pieces: fn _pid -> MapSet.new() end do
      {:ok, pid} =
        Pieces.start_link(
          num_pieces: 32,
          piece_lengths: Map.new(),
          default_piece_length: 4,
          files_writer: nil
        )

      valid = Pieces.start_downloading(pid, MapSet.new(0..31), max: 32)
      assert map_size(valid) == 32
    end
  end

  test "should not download pieces already downloaded before startup" do
    with_mock FilesWriter, downloaded_pieces: fn _pid -> MapSet.new(0..5) end do
      {:ok, pid} =
        Pieces.start_link(
          num_pieces: 32,
          piece_lengths: Map.new(),
          default_piece_length: 4,
          files_writer: nil
        )
      valid = Pieces.start_downloading(pid, MapSet.new(0..31), max: 32)
      assert map_size(valid) == (32 - 6)
    end
  end

  test "two processes cannot download the same piece" do
    with_mock FilesWriter, downloaded_pieces: fn _pid -> MapSet.new() end do
      {:ok, pid} =
        Pieces.start_link(
          num_pieces: 32,
          piece_lengths: Map.new(),
          default_piece_length: 4,
          files_writer: nil
        )

      valid = Pieces.start_downloading(pid, MapSet.new([31]))
      assert %{31 => 4} == valid

      empty = Pieces.start_downloading(pid, MapSet.new([31]))
      assert map_size(empty) == 0
    end
  end

  test "a piece can become downloading and then downloaded" do
    with_mock FilesWriter, downloaded_pieces: fn _pid -> MapSet.new() end do
      {:ok, pid} =
        Pieces.start_link(
          num_pieces: 32,
          piece_lengths: %{31 => 1},
          default_piece_length: 4,
          files_writer: nil
        )

      %{31 => 1} = Pieces.start_downloading(pid, MapSet.new([31]))
      :ok = Pieces.downloaded(pid, 31)
    end
  end

  test "a piece which was not downloading cannot become downloaded" do
    with_mock FilesWriter, downloaded_pieces: fn _pid -> MapSet.new() end do
      {:ok, pid} =
        Pieces.start_link(
          num_pieces: 32,
          piece_lengths: Map.new(),
          default_piece_length: 4,
          files_writer: nil
        )

      {:error, :not_downloading} = Pieces.downloaded(pid, 31)
    end
  end
end
