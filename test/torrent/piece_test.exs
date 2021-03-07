defmodule Torrentex.Torrent.PieceTest do
  use ExUnit.Case
  use ExUnitProperties
  alias Torrentex.Torrent.Piece

  @binary_size 128
  @binary_size_bits 8 * @binary_size

  property "piece is not completed until all sub_pieces are inserted" do
    check all(
            piece <- mk_piece(),
            sub_pieces <- subpieces(piece, complete: false)
          ) do
      %Piece{complete: false} =
        for begin <- sub_pieces, reduce: piece do
          piece ->
            {:ok, piece} = Piece.add_sub_piece(piece, begin, <<1::@binary_size_bits>>)
            piece
        end
    end
  end

  property "piece is completed when all sub_pieces are inserted" do
    check all(
            piece <- mk_piece(),
            sub_pieces <- subpieces(piece, complete: true)
          ) do
      %Piece{complete: true} =
        for begin <- sub_pieces, reduce: piece do
          piece ->
            {:ok, piece} = Piece.add_sub_piece(piece, begin, <<1::@binary_size_bits>>)
            piece
        end
    end
  end

  test "short piece is completed correctly" do
    piece = Piece.new(17, 130) # 16 pieces by 8, plus 1 by 4
    piece = for id <- 0..15, reduce: piece do
      piece ->
        {:ok, piece} = Piece.add_sub_piece(piece, id * 8, <<0 :: 64>>)
        piece
    end
    {:ok, piece} = piece |> Piece.add_sub_piece(128, <<0::16>>)
    assert piece.complete == true
    #1040 = 130 * 8 size in bits
    expected_hash = :crypto.hash(:sha, <<0 :: 1040>>)
    {:ok, _bin} = Piece.binary(piece, expected_hash)
    :ok = Piece.validate_hash(piece, expected_hash)
  end

  test "binary is created correctly" do
    piece = %Piece{
      num: 3,
      piece_length: 8,
      full_sub_piece_len: 3,
      sub_pieces: Map.new(0..2 |> Enum.map(fn id -> {id * 3, <<1::64>>} end)),
      complete: true
    }

    expected_hash = :crypto.hash(:sha, <<1::64, 1::64, 1::64>>)
    {:ok, binary} = Piece.binary(piece, expected_hash)
    :ok = Piece.validate_hash(piece, expected_hash)
    assert byte_size(binary) == 24
  end

  def mk_piece(),
    do:
      StreamData.integer(1..128)
      |> StreamData.map(& Piece.new(&1, &1 * @binary_size))

  def subpieces(piece, opts \\ []) do
    complete = Keyword.fetch!(opts, :complete)

    if complete do
      StreamData.constant(0..(piece.num - 1) |> Enum.map(&(&1 * @binary_size)))
    else
      begins = StreamData.integer(0..(piece.num - 1)) |> StreamData.map(&(&1 * @binary_size))
      StreamData.list_of(begins, max_length: piece.num - 1)
    end
  end
end
