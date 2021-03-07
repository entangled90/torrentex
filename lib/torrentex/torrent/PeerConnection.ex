defmodule Torrentex.Torrent.PeerConnection do
  alias Torrentex.Torrent.WireProtocol
  alias Torrentex.Torrent.Peer
  alias Torrentex.Torrent.Pieces
  alias Torrentex.Torrent.Piece
  alias Torrentex.Torrent.FilesWriter
  use GenServer
  require Logger

  @poll_interval 5_000

  @piece_timeout 60_000

  defmodule State do
    @enforce_keys [
      :socket,
      :peer,
      :my_peer_id,
      :info_hash,
      :pieces_agent,
      :files_writer,
      :max_downloading,
      :hashes
    ]
    defstruct [
      :socket,
      :peer,
      :my_peer_id,
      :info_hash,
      :pieces_agent,
      :files_writer,
      :max_downloading,
      :hashes,
      partial_packets: <<>>,
      other_peer_id: nil,
      handshake_done: false,
      have: MapSet.new(),
      # Map id -> Piece
      downloading: Map.new(),
      choked: true,
      interested: false,
      am_choking: false,
      am_interested: false
    ]
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    peer = Keyword.fetch!(args, :peer)
    peer_id = Keyword.fetch!(args, :peer_id)
    info_hash = Keyword.fetch!(args, :info_hash)
    pieces_agent = Keyword.fetch!(args, :pieces_agent)
    files_writer = Keyword.fetch!(args, :files_writer)
    max_downloading = Keyword.get(args, :max_downloading, 5)
    hashes = Keyword.fetch!(args, :hashes)
    Process.send_after(self(), :send_keep_alive, 30_000)
    Logger.metadata(peer: Peer.show(peer))

    Logger.info("Starting connection for peer #{Peer.show(peer)}")

    {:ok,
     %State{
       peer: peer,
       my_peer_id: peer_id,
       socket: nil,
       info_hash: info_hash,
       pieces_agent: pieces_agent,
       files_writer: files_writer,
       max_downloading: max_downloading,
       hashes: hashes
     }, {:continue, :ok}}
  end

  @impl true
  def handle_continue(:ok, %State{} = state) do
    connect(state)
  end


  @impl true
  def handle_info(:poll_work, state) do
    Process.send_after(self(), :poll_work, @poll_interval)
    {:noreply, command_loop(state)}
  end

  @impl true
  def handle_info({:tcp_closed, _pid}, state) do
    Logger.warn("tcp socket closed. Stopping")
    # TODO  restart instead of stop
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, _port, reason}, state) do
    Logger.warn("Tcp error #{inspect(reason)} encountered. Stopping")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:tcp, socket, binary}, state)
      when is_binary(binary) do
    if socket != state.socket do
      raise "Invalid socket sent the message!"
    end

    {msgs, remaining} = WireProtocol.parseMulti(state.partial_packets <> binary)
    state = %{state | partial_packets: remaining}

    state =
      msgs
      |> Enum.reduce(state, fn msg, state ->
        Logger.debug("received message #{inspect(msg)}")
        handle_msg(msg, state)
      end)

    downloading_pieces = map_size(state.downloading)

    state = if downloading_pieces < state.max_downloading, do: command_loop(state), else: state

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:timeout, %{id: id, sub_pieces: sub_pieces}},
        %State{socket: socket, pieces_agent: pieces_agent, downloading: downloading} = state
      ) do
    if Map.has_key?(downloading, id) do
      Logger.warn "Timeout expired while still downloading piece #{id}"
      for {begin, len} <- sub_pieces do
        send_msg(socket, WireProtocol.cancel(id, begin, len))
      end

      Map.delete(downloading, id)
      Pieces.download_canceled(pieces_agent, id)
    end
    {:noreply, %{state | downloading: Map.delete(downloading, id) }}
  end

  @impl true
  def handle_info(:send_keep_alive, %State{} = state) do
    _ =
      if state.socket do
        send_msg(state.socket, WireProtocol.keep_alive())
        Process.send_after(self(), :send_keep_alive, 10_000)
      end

    {:noreply, state}
  end

  defp connect(%State{peer: %Peer{ip: ip, port: port}} = state) do
    case :gen_tcp.connect(ip, port, [:binary, :inet, {:active, true}, {:packet, 0}], 30_000) do
      {:ok, socket} ->
        send_msg(
          socket,
          WireProtocol.handshake(state.my_peer_id, state.info_hash)
        )

        {:noreply, %{state | socket: socket}}

      {:error, reason} ->
        Logger.warn("Cannot connect to peer, for reason #{reason}")
        {:stop, :normal, state}
    end
  end

  defp send_msg(socket, msg) do
    Logger.debug("sending msg #{inspect(msg)}")

    case :gen_tcp.send(socket, WireProtocol.encode(msg)) do
      :ok -> :ok
      {:error, reason} -> Process.exit(self(), reason)
    end
  end

  defp handle_msg({:handshake, {peer, handshake_hash}}, %State{info_hash: info_hash} = state)
       when info_hash == handshake_hash do
    %{state | handshake_done: true, other_peer_id: peer}
  end

  defp handle_msg({:hanshake, _}, _) do
    Logger.info("Invalid info hash received, stopping")
    Process.exit(self(), :exit)
  end

  defp handle_msg({:unchoke, _}, state) do
    %{state | choked: false}
  end

  defp handle_msg({:choke, _}, state) do
    %{state | choked: true}
  end

  defp handle_msg({:bitfield, {bit, _len}}, state) do
    %{state | have: MapSet.union(state.have, bit)}
  end

  defp handle_msg({:have, idx}, state) do
    %{state | have: MapSet.put(state.have, idx)}
  end

  defp handle_msg({:piece, {idx, begin, block}}, %State{} = state) do
    Logger.debug("Received piece #{idx}, #{begin}")

    {:ok, piece} = state.downloading[idx] |> Piece.add_sub_piece(begin, block)

    if piece.complete do
      Logger.debug("Piece #{idx} is completed.")
      piece_hash = Map.get(state.hashes, idx)

      downloading =
        case Piece.validate_hash(piece, piece_hash) do
          :ok ->
            FilesWriter.persist(state.files_writer, idx, piece)
            Pieces.downloaded(state.pieces_agent, idx)
            Map.delete(state.downloading, idx)

          {:error, {:wrong_hash, wrong_hash}} ->
            Logger.warn(
              "Wrong hash for piece #{idx}. . Expected hash #{
                Base.encode16(piece_hash)
              }, actual hash #{Base.encode16(wrong_hash)}"
            )

            :ok = Pieces.wrong_hash(state.pieces_agent, idx)
            state.downloading
        end

      %{state | downloading: downloading}
    else
      %{state | downloading: %{state.downloading | idx => piece}}
    end
  end

  defp handle_msg({:keep_alive, nil}, state) do
    state
  end


  defp command_loop(state) do
    if !state.choked do
      ids = Pieces.start_downloading(state.pieces_agent, state.have, max: 1)

      if !state.am_interested do
        send_msg(state.socket, WireProtocol.interested())
      end

      downloading =
        for {id, len} <- ids, into: state.downloading do
          piece_partition = FilesWriter.partition_piece(len)

          sub_pieces =
            for {begin, sub_piece_len} <- piece_partition do
              send_msg(
                state.socket,
                WireProtocol.request(id, begin, sub_piece_len)
              )

              {begin, sub_piece_len}
            end

          Process.send_after(self(), {:timeout, %{id: id, sub_pieces: sub_pieces}}, @piece_timeout)

          {id, Piece.new(map_size(piece_partition), len)}
        end

      %{state | downloading: downloading}
    else
      state
    end
  end
end
