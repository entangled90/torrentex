defmodule TorrentexLib.Torrent.Piece do
  @enforce_keys [:num, :piece_length]

  @type t() :: %__MODULE__{
          num: pos_integer(),
          piece_length: pos_integer(),
          sub_pieces: %{pos_integer() => binary()},
          complete: boolean()
        }

  @enforce_keys [:num, :piece_length, :full_sub_piece_len]
  defstruct [:num, :piece_length, :full_sub_piece_len, sub_pieces: Map.new(), complete: false]

  @spec new(pos_integer(), pos_integer()) :: TorrentexLib.Torrent.Piece.t()
  def new(num, piece_length) do
    %__MODULE__{num: num, piece_length: piece_length, full_sub_piece_len: (piece_length / num) |> ceil()}
  end

  @spec add_sub_piece(t(), integer(), binary()) :: {:ok, t()} | {:error, {:wrong_size}}
  def add_sub_piece(%__MODULE__{} = piece, begin, sub_piece) when is_binary(sub_piece) do
    if begin + byte_size(sub_piece) == piece.piece_length  or
         byte_size(sub_piece) == piece.full_sub_piece_len do
      sub_pieces = Map.put(piece.sub_pieces, begin, sub_piece)

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
      |> Map.values()
      |> :erlang.list_to_binary()

    if :crypto.hash(:sha, bin) == expected_hash,
      do: {:ok, bin},
      else: {:error, {:wrong_hash, bin}}
  end

  def binary(_, _), do: {:error, :incomplete}
end
