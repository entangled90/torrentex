defmodule Torrentex.Torrent.Piece do
  @enforce_keys [:num, :piece_length]

  @type t() :: %__MODULE__{
          num: integer(),
          piece_length: integer(),
          sub_pieces: %{integer() => binary()},
          complete: boolean()
        }
  defstruct [:num, :piece_length, sub_pieces: Map.new(), complete: false]

  def new(num, piece_length) do
    %__MODULE__{num: num, piece_length: piece_length}
  end

  @spec add_sub_piece(t(), integer(), binary()) :: {:ok, t()} | {:error, {:wrong_size}}
  def add_sub_piece(piece, id, sub_piece) when is_binary(sub_piece) do
    if (id == piece.num - 1 and byte_size(sub_piece) <= piece.piece_length) or
         (id < piece.num and byte_size(sub_piece) == piece.piece_length) do
      sub_pieces = Map.put(piece.sub_pieces, id, sub_piece)

      {:ok,
       %__MODULE__{piece | sub_pieces: sub_pieces, complete: map_size(sub_pieces) == piece.num}}
    else
      {:error, :wrong_size}
    end
  end

  @spec binary(t(), <<_::160>>) ::
          {:ok, binary()} | {:error, :incomplete | {:wrong_hash, binary()}}
  def binary(piece, expected_hash) when piece.complete do
    bin =
      piece.sub_pieces
      |> Enum.to_list()
      |> Enum.map(fn {_, v} -> v end)
      |> :erlang.list_to_binary()

    if :crypto.hash(:sha, bin) == expected_hash,
      do: {:ok, bin},
      else: {:error, {:wrong_hash, bin}}
  end

  def binary(_, _), do: {:error, :incomplete}
end
