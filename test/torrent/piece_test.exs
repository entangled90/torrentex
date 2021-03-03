defmodule Torrentex.Torrent.PieceTest do
  use ExUnit.Case
  use ExUnitProperties
  alias Torrentex.Torrent.Piece

  @binary_size 8 * 128
  property "piece is not completed until all sub_pieces are inserted" do
    check all(
            piece <- mk_piece(),
            sub_pieces <- subpieces(piece, complete: false)
          ) do
      %Piece{complete: false} =
        sub_pieces
        |> Enum.reduce(piece, fn idx, piece ->
          {:ok, piece} = Piece.add_sub_piece(piece, idx, <<1::@binary_size>>)
          piece
        end)
    end
  end

  property "piece is completed when all sub_pieces are inserted" do
    check all(
            piece <- mk_piece(),
            sub_pieces <- subpieces(piece, complete: true)
          ) do
      %Piece{complete: true} =
        sub_pieces
        |> Enum.reduce(piece, fn idx, piece ->
          {:ok, piece} = Piece.add_sub_piece(piece, idx, <<1::@binary_size>>)
          piece
        end)
    end
  end

  test "binary is created correctly" do
    piece = %Piece{
      num: 3,
      piece_length: 8,
      sub_pieces: Map.new(0..2 |> Enum.map(fn id -> {id, <<1::64>>} end)),
      complete: true
    }

    expected_hash = :crypto.hash(:sha, <<1::64, 1::64, 1::64>>)
    {:ok, binary} = Piece.binary(piece, expected_hash)
    assert byte_size(binary) == 24
  end

  def mk_piece(),
    do: StreamData.integer(1..128) |> StreamData.map(&%Piece{num: &1, piece_length: 128})

  def subpieces(piece, opts \\ []) do
    complete = Keyword.fetch!(opts, :complete)

    if complete,
      do: StreamData.constant(0..(piece.num - 1)),
      else: StreamData.list_of(StreamData.integer(0..(piece.num - 1)), max_length: piece.num - 1)
  end
end
