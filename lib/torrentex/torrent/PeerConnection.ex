defmodule Torrentex.Torrent.PeerConnection do
  alias Torrentex.Torrent.WireProtocol
  alias Torrentex.Torrent.Peer

  use GenServer
  require Logger

  @keep_alive <<0::8>>

  defmodule State do
    defstruct [
      :socket,
      :peer,
      :my_peer_id,
      :info_hash,
      :metainfo,
      other_peer_id: nil,
      retries: 0,
      handshake_done: false,
      choked: false,
      interested: false,
      am_choking: false,
      am_interested: false
    ]
  end

  def start_link(args) do
    Logger.debug("Starting connection with args #{inspect(args)}")
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    peer = Keyword.fetch!(args, :peer)
    peer_id = Keyword.fetch!(args, :peer_id)
    info_hash = Keyword.fetch!(args, :info_hash)
    metainfo = Keyword.fetch!(args, :metainfo)
    Process.send_after(self(), :keep_alive, 30_000)
    Logger.metadata(peer: peer)

    {:ok,
     %State{
       peer: peer,
       my_peer_id: peer_id,
       socket: nil,
       info_hash: info_hash,
       metainfo: metainfo
     }, {:continue, peer}}
  end

  @impl true
  def handle_continue(peer, %State{} = state) do
    case connect(peer) do
      {:ok, socket} ->
        send_msg(
          socket,
          WireProtocol.handshake(state.info_hash, state.my_peer_id) |> WireProtocol.encode()
        )

        {:noreply, %{state | socket: socket}}

      {:error, :econnrefused} ->
        {:stop, :econnrefused, state}
    end
  end

  @impl true
  def handle_info({:tcp_closed, _pid}, %State{retries: retries} = state) do
    Logger.debug("Socket is closed. retrying after 30 seconds")
    Process.send_after(self(), :connect, 30_000)
    {:noreply, %{state | retries: retries + 1}}
  end

  @impl true
  def handle_info({:tcp, socket, binary}, state)
      when is_binary(binary) do
    if socket != state.socket do
      raise "Invalid socket sent the message!"
    end

    state =
      WireProtocol.parseMulti(binary)
      |> Enum.reduce(state, &handle_msg(&1, &2))

    {:noreply, state}
  end

  @impl true
  def handle_info(:keep_alive, state) do
    if state.socket do
      Logger.debug("Sending keep alive")
      send_msg(state.socket, @keep_alive)
      Process.send_after(self(), :keep_alive, 30_000)
    end
  end

  defp connect(%{ip: ip, port: port}) do
    :gen_tcp.connect(ip, port, [:binary, {:active, true}], 30_000)
  end

  defp send_msg(socket, msg) do
    :ok = :gen_tcp.send(socket, msg)
  end

  defp handle_msg({:handshake, {peer, handshake_hash}}, %State{info_hash: info_hash} = state)
       when info_hash == handshake_hash do
    %{state | handshake_done: true, other_peer_id: peer}
  end

  defp handle_msg({:hanshake, _}, _) do
    Logger.info("Invalid info hash received, stopping")
    Process.exit(self(), :exit)
  end
end
