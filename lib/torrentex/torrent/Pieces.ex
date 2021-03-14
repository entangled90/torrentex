defmodule Torrentex.Torrent.Pieces do
  alias Torrentex.Torrent.FilesWriter
  use GenServer
  require Logger

  @type t() :: %__MODULE__{
          available: MapSet.t(integer()),
          piece_lengths: map(),
          default_piece_length: integer(),
          downloading: map(),
          downloaded: MapSet.t(integer())
        }
  @enforce_keys [:available]
  defstruct [
    :available,
    :piece_lengths,
    :default_piece_length,
    downloading: Map.new(),
    downloaded: MapSet.new()
  ]

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    num_pieces = Keyword.fetch!(args, :num_pieces)
    piece_lengths = Keyword.fetch!(args, :piece_lengths)
    default_piece_length = Keyword.fetch!(args, :default_piece_length)
    files_writer = Keyword.fetch!(args, :files_writer)

    downloaded_pieces = FilesWriter.downloaded_pieces(files_writer)

    all_pieces = MapSet.new(0..(num_pieces - 1))

    Logger.info("Short pieces are #{inspect(piece_lengths)}")

    state = %__MODULE__{
      available: MapSet.difference(all_pieces, downloaded_pieces),
      piece_lengths: piece_lengths,
      default_piece_length: default_piece_length,
      downloaded: downloaded_pieces
    }

    Logger.info "Pieces starting. available: #{MapSet.size(state.available)}, downloaded: #{MapSet.size(state.downloaded)}"

    {:ok, state}
  end

  @spec start_downloading(atom | pid | {atom, any} | {:via, atom, any}, MapSet.t(integer), [
          {atom(), any()}
        ]) :: any
  def start_downloading(pid, candidate_ids, opts \\ []) do
    GenServer.call(pid, {:start_downloading, candidate_ids, opts})
  end

  def downloaded(pid, id) do
    GenServer.call(pid, {:downloaded, id})
  end

  def wrong_hash(pid, id) do
    GenServer.call(pid, {:wrong_hash, id})
  end

  def download_canceled(pid, id) do
    GenServer.call(pid, {:download_canceled, id})
  end

  @impl true
  def handle_call({:start_downloading, candidate_ids, opts}, {from, _}, state) do
    max = Keyword.get(opts, :max, 5)
    valid = MapSet.intersection(state.available, candidate_ids) |> Enum.take(max) |> MapSet.new()
    available = MapSet.difference(state.available, valid)

    downloading =
      Map.merge(
        state.downloading,
        valid |> MapSet.to_list() |> Enum.map(&{&1, from}) |> Map.new()
      )

    result =
      for id <- valid, into: %{} do
        {id, Map.get(state.piece_lengths, id, state.default_piece_length)}
      end

    Process.monitor(from)

    {:reply, result,
     %{
       state
       | available: available,
         downloading: downloading
     }}
  end

  def handle_call({:downloaded, id}, {from_pid, _}, state) do
    downloaded_from = state.downloading[id]

    if downloaded_from == from_pid do
      downloading = Map.delete(state.downloading, id)
      downloaded = MapSet.put(state.downloaded, id)
      {:reply, :ok, %{state | downloading: downloading, downloaded: downloaded}}
    else
      {:reply, {:error, :not_downloading}, state}
    end
  end

  def handle_call({:wrong_hash, id}, {_from, _}, %__MODULE__{} = state) do
    {:reply, :ok, reset_piece(state, id)}
  end

  def handle_call({:download_canceled, id}, {_from, _}, %__MODULE__{} = state) do
    {:reply, :ok, reset_piece(state, id)}
  end

  defp reset_piece(%__MODULE__{} = state, id) do
    downloading = Map.delete(state.downloading, id)
    available = MapSet.put(state.available, id)
    %{state | downloading: downloading, available: available}
  end

  @impl true
  def handle_info({:DOWN, _, :process, pid, _}, state) do
    active_downloads =
      state.downloading
      |> Enum.to_list()
      |> Enum.filter(fn {_, p} -> p == pid end)
      |> Enum.map(fn {id, _} -> id end)

    Logger.info(
      "Process #{inspect(pid)}, which was downloading piece #{active_downloads} is down, setting pieces as available"
    )

    {:noreply,
     %{
       state
       | available: MapSet.union(state.available, MapSet.new(active_downloads)),
         downloading: Map.drop(state.downloading, active_downloads)
     }}
  end

  @impl true
  def terminate(reason, state) do
    Logger.warn(
      "Pieces process terminating with reason #{inspect(reason)} and state #{inspect(state)}"
    )
  end
end
