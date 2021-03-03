defmodule Torrentex.Torrent.FilesWriter do
  use GenServer
  require Logger
  alias Torrentex.Torrent.Torrent

  # 16 KB
  @sub_piece_length :math.pow(2, 14) |> round()

  defmodule State do
    defmodule File do
      @enforce_keys [:length, :num_pieces, :pieces_for_file, :starting_idx]

      @type t() :: %__MODULE__{
              length: pos_integer(),
              num_pieces: pos_integer(),
              pieces_for_file: [binary()],
              starting_idx: non_neg_integer(),
              downloaded_pieces: MapSet.t(integer())
            }
      defstruct [
        :length,
        :num_pieces,
        :pieces_for_file,
        :starting_idx,
        downloaded_pieces: MapSet.new(),
        file_handle: nil
      ]
    end

    @enforce_keys [:metainfo, :download_folder, :piece_length, :pieces]
    @type t() :: %__MODULE__{
            metainfo: map(),
            download_folder: binary(),
            piece_length: pos_integer(),
            pieces: binary(),
            download_status: MapSet.t(integer()),
            files: map()
          }
    defstruct [:metainfo, :download_folder, :piece_length, :pieces, :download_status, :files]
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    metainfo = Keyword.fetch!(args, :metainfo)
    download_folder = Keyword.get(args, :download_folder, File.cwd!())
    %{"piece length": piece_length, pieces: pieces} = metainfo |> Map.from_struct()

    {:ok,
     %State{
       metainfo: metainfo,
       download_folder: download_folder,
       piece_length: piece_length,
       pieces: pieces
     }, {:continue, :ok}}
  end

  def piece_length_info(pid) when is_pid(pid) do
    GenServer.call(pid, :piece_length_infos)
  end

  def persist(pid, idx, bin) do
    GenServer.call(pid, {:persist, idx, bin})
  end

  @impl true
  def handle_call(:piece_length_infos, _from, state) do
    {:reply,
     %{
       piece_length: state.piece_length,
       short_pieces: short_pieces(state.files, state.piece_length)
     }, state}
  end

  @impl true
  def handle_call({:persist, idx, bin}, _from, %State{} = state) do
    Logger.debug("Persisting piece #{idx}")

    for file_info <- state.files |> Map.values do
      if file_info.starting_idx <= idx && file_info.starting_idx + file_info.num_pieces > idx do
        offset = (idx - file_info.starting_idx) * state.piece_length
        :file.position(file_info.file_handle, offset)
        :ok = :file.write(file_info.file_handle, bin)
      end
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_continue(:ok, %State{} = state) do
    {:ok, state} = load_from_disk(state)
    Logger.info("Files loaded from disk #{inspect(state)}")
    {:noreply, state}
  end

  defp load_from_disk(%State{metainfo: metainfo} = state) do
    base_folder = state.download_folder

    files =
      case Map.from_struct(metainfo) do
        %{name: name, length: len} ->
          file_path = Path.join(base_folder, name)

          %{
            file_path => %State.File{
              length: len,
              num_pieces: (len / state.piece_length) |> ceil(),
              pieces_for_file: Torrent.State.binary_in_chunks(state.pieces, 20),
              starting_idx: 0
            }
          }

        %{files: files} ->
          {files, _} =
            for file <- files, reduce: {%{}, state.pieces, 0} do
              {map, pieces, starting_idx} ->
                path = Path.join(base_folder, file["path"])
                len = file["length"]
                num_pieces = (len / state.piece_length) |> ceil()
                {raw_pieces, pieces} = pieces |> :erlang.split_binary(num_pieces)
                # raw_piecs is a single concatenated binary
                pieces_for_file = Torrent.State.binary_in_chunks(raw_pieces, 20)

                new_map =
                  Map.put(map, path, %State.File{
                    length: len,
                    num_pieces: num_pieces,
                    pieces_for_file: pieces_for_file,
                    starting_idx: starting_idx
                  })

                {new_map, pieces, starting_idx + num_pieces}
            end

          files
      end

    files =
      for {path, file_info} <- files, into: %{} do
        {file_handle, downloaded_pieces} = load_file(path, state.piece_length, file_info)

        {path, %{file_info | downloaded_pieces: downloaded_pieces, file_handle: file_handle}}
      end

    {:ok, %{state | files: files, piece_length: state.piece_length}}
  end

  @spec load_file(binary(), pos_integer(), map()) :: {:file.io_device(), MapSet.t(integer())}
  def load_file(path, piece_length, %{pieces_for_file: pieces_for_file})
      when piece_length > 0 and pieces_for_file > 0 do
    downloaded_pieces =
      case File.stat(path) do
        {:ok, _} ->
          File.stream!(path, [], piece_length)
          |> Enum.zip(pieces_for_file)
          |> Enum.with_index()
          |> Enum.filter(fn {{chunk, hash}, _} -> :crypto.hash(:sha, chunk) == hash end)
          |> Enum.map(fn {{_, _}, idx} -> idx end)
          |> MapSet.new()

        {:error, :enoent} ->
          MapSet.new()
      end

    {:ok, file} = :file.open(path, [:write, :raw])
    {file, downloaded_pieces}
  end

  @spec short_pieces(map(), pos_integer()) :: any()
  def short_pieces(files, piece_length) do
    {_, map} =
      Enum.reduce(files, {0, %{}}, fn {_, %{length: len}}, {idx, map} ->
        last_piece = div(len, piece_length)

        if rem(len, piece_length) != 0 do
          short_piece = idx + last_piece + 1
          {short_piece, Map.put(map, short_piece, rem(len, piece_length))}
        else
          {idx + last_piece, map}
        end
      end)

    map
  end

  @spec partition_piece(integer, pos_integer()) :: map
  def partition_piece(piece_length, size \\ @sub_piece_length) when size > 0 do
    full_sub_piece = div(piece_length, size)
    remainder = rem(piece_length, size)
    num_pieces = if remainder == 0, do: full_sub_piece, else: full_sub_piece + 1

    for id <- 0..(num_pieces - 1), into: %{} do
      len =
        if id == num_pieces - 1 do
          if remainder == 0, do: size, else: remainder
        else
          size
        end

      {id * size, len}
    end
  end
end
