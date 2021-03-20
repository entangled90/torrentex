defmodule Torrentex.Torrent.Reporter do
  require Logger
  alias Torrentex.Torrent.{FilesWriter, Pieces}
  use GenServer

  @report_interval 5_000

  @enforce_keys [:files_writer, :num_pieces, :piece_length, :pieces_downloaded, :pieces_agent]
  defstruct [
    :files_writer,
    :num_pieces,
    :piece_length,
    :pieces_downloaded,
    :pieces_agent,
    active_peers: 0,
    downloading_pieces: 0
  ]

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(args) do
    files_writer = Keyword.fetch!(args, :files_writer)
    num_pieces = Keyword.fetch!(args, :num_pieces)
    piece_length = Keyword.fetch!(args, :piece_length)
    pieces_agent = Keyword.fetch!(args, :pieces_agent)
    Process.send_after(self(), :report, @report_interval)
    pieces_downloaded = FilesWriter.downloaded_pieces(files_writer)

    {:ok,
     %__MODULE__{
       files_writer: files_writer,
       num_pieces: num_pieces,
       piece_length: piece_length,
       pieces_downloaded: MapSet.size(pieces_downloaded),
       pieces_agent: pieces_agent
     }}
  end

  def handle_info(:report, %__MODULE__{} = state) do
    pieces = FilesWriter.downloaded_pieces(state.files_writer)
    size = MapSet.size(pieces)
    new_pieces = size - state.pieces_downloaded
    scale = 1024 * 1024
    speed = new_pieces * state.piece_length / 5.0 / scale

    Logger.info(
      "Downloaded pieces: #{size}/#{state.num_pieces} = #{size / state.num_pieces}. Speed #{speed}MB/s"
    )
    %{available: available, downloading: downloading} = Pieces.query_status(state.pieces_agent)

    if MapSet.size(available) < 10 do
      Logger.info "remaining less than 10 pieces #{inspect available}. Downloading #{inspect downloading}"
    else
      Logger.info "remaining available pieces #{MapSet.size(available)}"
    end

    Process.send_after(self(), :report, @report_interval)

    {:noreply, %{state | pieces_downloaded: size}}
  end
end
