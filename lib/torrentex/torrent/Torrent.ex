defmodule Torrentex.Torrent.Torrent do
  @moduledoc """
  Start downloading a torrent given a path to a torrent file or a magnet link

  {:ok, pid} = Torrentex.Torrent.Torrent.start_link("data/ubuntu-20.04.2.0-desktop-amd64.iso.torrent")
  {:ok, pid} = Torrentex.Torrent.Torrent.start_link("data/Fedora-KDE-Live-x86_64-33.torrent")

  """
  alias Torrentex.Torrent.{
    FilesWriter,
    Parser,
    Peer,
    PeerConnectionSupervisor,
    Pieces,
    Tracker
  }

  use GenServer
  require Logger

  defmodule State do
    defmodule DownloadStatus do
      defstruct downloaded: 0, uploaded: 0, left: 0

      def for_torrent(info) do
        length =
          case info do
            %Bento.Metainfo.SingleFile{length: length} ->
              length

            %Bento.Metainfo.MultiFile{files: files} ->
              files |> Enum.map(fn file -> file["length"] end) |> Enum.reduce(&(&1 + &2))
          end

        %__MODULE__{left: length}
      end
    end

    defstruct [
      :source,
      :torrent,
      :info_hash,
      :hashes,
      :peer_id,
      :tracker_response,
      :download_status,
      :peer_supervisor,
      :pieces_agent,
      :files_writer
    ]

    def init(source, torrent, hash, peer_id, peer_supervisor, pieces_agent, files_writer) do
      status = DownloadStatus.for_torrent(torrent.info)
      hashes = torrent.info.pieces |> binary_in_chunks(20) |> Enum.with_index() |> Map.new()

      %__MODULE__{
        source: source,
        torrent: torrent,
        info_hash: hash,
        hashes: hashes,
        peer_id: peer_id,
        tracker_response: nil,
        download_status: status,
        peer_supervisor: peer_supervisor,
        pieces_agent: pieces_agent,
        files_writer: files_writer
      }
    end

    @spec binary_in_chunks(binary, pos_integer()) :: [binary]
    def binary_in_chunks(binary, chunk_len) when is_binary(binary) and is_integer(chunk_len) do
      if byte_size(binary) > chunk_len do
        <<chunk::binary-size(chunk_len), rest::binary>> = binary
        [chunk | binary_in_chunks(rest, chunk_len)]
      else
        [binary]
      end
    end
  end

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(source) do
    GenServer.start_link(__MODULE__, source)
  end

  @impl true
  def init(source) do
    {torrent, info_hash} = Parser.decode_torrent(source)

    Logger.info("Starting torrent for state #{inspect(torrent)}")

    peer_id = Tracker.generate_peer_id()
    # each hash is 20 byte
    num_pieces = div(byte_size(torrent.info.pieces), 20)
    {:ok, peer_supervisor} = PeerConnectionSupervisor.start_link([])
    {:ok, files_writer} = FilesWriter.start_link(metainfo: torrent.info)

    %{piece_length: piece_length, short_pieces: short_pieces} =
      FilesWriter.piece_length_info(files_writer)

    {:ok, pieces_agent} =
      Pieces.start_link(
        num_pieces: num_pieces,
        piece_lengths: short_pieces,
        default_piece_length: piece_length
      )

    state =
      State.init(source, torrent, info_hash, peer_id, peer_supervisor, pieces_agent, files_writer)

    send(self(), {:call_tracker, "started"})
    {:ok, state}
  end

  @impl true
  def handle_call(:torrent, _from, state) do
    {:reply, state[:torrent], state}
  end

  # # workers in case they die.
  # @impl true
  # def handle_info({:EXIT, from, reason}, state) do
  #   Logger.info("Process #{inspect(from)} exited with reason #{inspect(reason)}")
  #   {:noreply, state}
  # end

  @impl true
  def handle_info({:call_tracker, event} = evt, %State{} = state) do
    updated_state =
      case Tracker.call_tracker(
             state.torrent.announce,
             state.info_hash,
             state.peer_id,
             state.download_status,
             event
           ) do
        {:ok, resp} ->
          Logger.debug("Response from tracker #{inspect(resp)}")
          %{state | tracker_response: resp}

        {:error, reason} ->
          Logger.warn("Received failure from tracker: #{inspect(reason)}")
          Process.send_after(self(), evt, 5_000)
          state
      end

    response = updated_state.tracker_response

    new_peers =
      if state.tracker_response == nil do
        response["peers"]
      else
        MapSet.new(response["peers"])
        |> MapSet.difference(MapSet.new(state.tracker_response["peers"]))
      end

    new_peers
    |> Enum.each(&start_peer_connection(&1, state))

    Logger.debug("Tracker retry after #{response["interval"]}")
    Process.send_after(self(), {:call_tracker, nil}, response["interval"] * 1000)

    {:noreply, updated_state}
  end

  defp start_peer_connection(%Peer{} = peer, %State{} = state) do
    args = [
      peer: peer,
      peer_id: state.peer_id,
      info_hash: state.info_hash,
      metainfo: state.torrent,
      pieces_agent: state.pieces_agent,
      files_writer: state.files_writer,
      hashes: state.hashes
    ]

    {:ok, pid} = PeerConnectionSupervisor.start_peer_connection(state.peer_supervisor, args)

    pid
  end
end
