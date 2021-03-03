defmodule Torrentex.Torrent.PiecesTest do
  use ExUnit.Case

  alias Torrentex.Torrent.Pieces

  test "can start download everything" do
    {:ok, pid} = Pieces.start_link(num_pieces: 32, piece_lengths: Map.new(), default_piece_length: 4)
    valid = Pieces.start_downloading(pid, MapSet.new(0..31), max: 32)
    assert map_size(valid) == 32
  end

  test "two processes cannot download the same piece" do
    {:ok, pid} = Pieces.start_link(num_pieces: 32, piece_lengths: Map.new(), default_piece_length: 4)
    valid = Pieces.start_downloading(pid, MapSet.new([31]))
    assert %{31 => 4} == valid

    empty = Pieces.start_downloading(pid, MapSet.new([31]))
    assert map_size(empty) == 0
  end

  test "a piece can become downloading and then downloaded" do
    {:ok, pid} = Pieces.start_link(num_pieces: 32, piece_lengths: %{31 => 1}, default_piece_length: 4)
    %{31 => 1} = Pieces.start_downloading(pid, MapSet.new([31]))
    :ok = Pieces.downloaded(pid, 31)
  end

  test "a piece which was not downloading cannot become downloaded" do
    {:ok, pid} = Pieces.start_link(num_pieces: 32, piece_lengths: Map.new(), default_piece_length: 4)
    {:error, :not_downloading} = Pieces.downloaded(pid, 31)
  end
end
