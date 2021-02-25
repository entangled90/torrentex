defmodule Torrentex.Torrent.PeerConnection do
  alias Torrentex.Torrent.WireProtocol
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

  def start_link(peer, peer_id, info_hash, metainfo) do
    Logger.debug("Starting connection for peer #{inspect(peer)}")
    GenServer.start_link(__MODULE__, [peer, peer_id, info_hash, metainfo])
  end

  @impl true
  def init([peer, peer_id, info_hash, metainfo]) do
    Process.send_after(self(), :keep_alive, 30_000)

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
        send_msg(socket, WireProtocol.handshake(state.info_hash, state.my_peer_id))
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
  def handle_info({:tcp, socket, binary}, %State{info_hash: info_hash} = state)
      when is_binary(binary) do
    if socket != state.socket do
      raise "Invalid socket sent the message!"
    end

    state =
      if state.handshake_done do
        raise "Not implemented yet!"
      else
        {rest, {^info_hash, id}} = WireProtocol.match_handshake(binary)
        Logger.debug("Handshake completed with peer_id #{inspect(id)}")
        %{state | other_peer_id: id}
      end

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
    :gen_tcp.send(socket, msg)
  end
end
