defmodule Torrentex.Torrent.Torrent do
  @moduledoc """
  Start downloading a torrent given a path to a torrent file or a magnet link

  {:ok, pid} = Torrentex.Torrent.Torrent.start_link("data/ubuntu-20.04.2.0-desktop-amd64.iso.torrent")

  """
  alias Torrentex.Torrent.Parser
  alias Torrentex.Torrent.Tracker
  alias Torrentex.Torrent.PeerConnection

  use GenServer
  require Logger

  defmodule State do
    defmodule DownloadStatus do
      defstruct downloaded: 0, uploaded: 0, left: 0

      def for_torrent(info) do
        case info do
          %Bento.Metainfo.SingleFile{length: length} -> %__MODULE__{left: length}
        end
      end
    end

    defstruct [:source, :torrent, :info_hash, :peer_id, :tracker_response, :download_status]

    def init(source, torrent, hash, peer_id) do
      status = DownloadStatus.for_torrent(torrent.info)

      %__MODULE__{
        source: source,
        torrent: torrent,
        info_hash: hash,
        peer_id: peer_id,
        tracker_response: nil,
        download_status: status
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

    state = State.init(source, torrent, info_hash, peer_id)

    Logger.info("Starting torrent for state #{inspect(state.torrent)}")
    send(self(), {:call_tracker, "started"})
    Process.flag(:trap_exit, true)
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

  # workers in case they die.
  @impl true
  def handle_info({:EXIT, from, reason}, state) do
    Logger.info("Process #{inspect(from)} exited with reason #{inspect(reason)}")
    {:noreply, state}
  end

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

    Logger.debug("New peers are #{inspect(new_peers)}")

    new_peers
    |> Enum.map(fn peer ->
      PeerConnection.start_link(peer, state.peer_id, state.info_hash, state.torrent)
    end)

    Logger.debug("Tracker retry after #{response["interval"]}")
    Process.send_after(self(), {:call_tracker, nil}, response["interval"] * 1000)

    {:noreply, updated_state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Worker for torrent #{state.source} terminating with reason #{reason}")
  end
end
