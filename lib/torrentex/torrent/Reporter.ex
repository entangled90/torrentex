defmodule Torrentex.Torrent.Reporter do
  require Logger
  alias Torrentex.Torrent.{FilesWriter}
  use GenServer

  @report_interval 5_000

  @enforce_keys [:files_writer, :num_pieces, :piece_length, :pieces_downloaded]
  defstruct [
    :files_writer,
    :num_pieces,
    :piece_length,
    :pieces_downloaded,
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
    Process.send_after(self(), :report, @report_interval)
    pieces_downloaded = FilesWriter.downloaded_pieces(files_writer)

    {:ok,
     %__MODULE__{
       files_writer: files_writer,
       num_pieces: num_pieces,
       piece_length: piece_length,
       pieces_downloaded: MapSet.size(pieces_downloaded)
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

    Process.send_after(self(), :report, @report_interval)

    {:noreply, %{state | pieces_downloaded: size}}
  end
end
