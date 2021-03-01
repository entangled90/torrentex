defmodule Torrentex.Torrent.Torrent do
  @moduledoc """
  Start downloading a torrent given a path to a torrent file or a magnet link

  {:ok, pid} = Torrentex.Torrent.Torrent.start_link("data/ubuntu-20.04.2.0-desktop-amd64.iso.torrent")
  {:ok, pid} = Torrentex.Torrent.Torrent.start_link("data/Fedora-KDE-Live-x86_64-33.torrent")

  """
  alias Torrentex.Torrent.Parser
  alias Torrentex.Torrent.Tracker
  alias Torrentex.Torrent.PeerConnection
  alias Torrentex.Torrent.Peer
  alias Torrentex.Torrent.Pieces

  use GenServer
  require Logger

  defmodule State do
    defmodule DownloadStatus do
      defstruct downloaded: 0, uploaded: 0, left: 0

      def for_torrent(info) do
        length = case info do
          %Bento.Metainfo.SingleFile{length: length} -> length
          %Bento.Metainfo.MultiFile{files: files} ->
            files |> Enum.map(fn file -> file["length"] end) |> Enum.reduce(& &1 + &2)
        end
        %__MODULE__{left: length}
      end
    end

    defstruct [
      :source,
      :torrent,
      :info_hash,
      :peer_id,
      :tracker_response,
      :download_status,
      :peer_supervisor,
      :pieces_agent
    ]

    def init(source, torrent, hash, peer_id, peer_supervisor, pieces_agent) do
      status = DownloadStatus.for_torrent(torrent.info)

      %__MODULE__{
        source: source,
        torrent: torrent,
        info_hash: hash,
        peer_id: peer_id,
        tracker_response: nil,
        download_status: status,
        peer_supervisor: peer_supervisor,
        pieces_agent: pieces_agent
      }
    end
  end

  def start_link(source) do
    GenServer.start_link(__MODULE__, source)
  end

  @impl true
  def init(source) when is_binary(source) do
    {torrent, info_hash} = Parser.decode_torrent(source)
    peer_id = Tracker.generate_peer_id()
    num_pieces = div(byte_size(torrent.info.pieces), 20) # each hash is 20 byte
    {:ok, peer_supervisor} =  DynamicSupervisor.start_link(strategy: :one_for_one)
    {:ok, pieces_agent} = Pieces.start_link(num_pieces: num_pieces)
    state = State.init(source, torrent, info_hash, peer_id, peer_supervisor, pieces_agent)

    Process.flag(:trap_exit, true)
    Logger.info("Starting torrent for state #{inspect(state.torrent)}")
    send(self(), {:call_tracker, "started"})
    {:ok, state}
  end

  @impl true
  def init(_source) do
    {:error, "Invalid argument, expecting a binary"}
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

  @impl true
  def handle_info( {:EXIT, pid, reason}, state) do
    role = case pid do
      p when p == state.pieces_agent   ->      :pieces_agent
      p when p == state.peer_supervisor ->       :peer_supervisor
      _ ->       :unknown
    end
    Logger.warn "Process with pid #{inspect pid} with role #{role} shutting down with reason #{inspect reason}"
  end

  defp start_peer_connection(%Peer{} = peer, %State{}=state) do
    spec = %{
      id: Peer.show(peer),
      start:
        {PeerConnection, :start_link,
         [[
           peer: peer,
           peer_id: state.peer_id,
           info_hash: state.info_hash,
           metainfo: state.torrent,
           pieces_agent: state.pieces_agent
         ]]},
      restart: :transient
    }

    {:ok, pid} = DynamicSupervisor.start_child(state.peer_supervisor, spec)
    pid
  end

  @impl true
  def terminate(reason, state) do
    Logger.warn(
      "Torrent download #{inspect(state.source)} terminating with reason #{inspect(reason)}"
    )
  end
end
