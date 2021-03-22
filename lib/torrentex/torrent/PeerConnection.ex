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
    state =
      case command_loop(state) do
        {:downloaded, state} ->
          Logger.info("Torrent download is completed. stop polling for work")
          state

        {:continue, state} ->
          Process.send_after(self(), :poll_work, @poll_interval)
          state
      end

    {:noreply, state}
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
    if socket == nil do
      raise "Socket is nil!"
    else
      if socket != state.socket do
        raise "Invalid socket sent the message!"
      end
    end

    {msgs, remaining} = WireProtocol.parse_multi([state.partial_packets, binary])
    state = %{state | partial_packets: remaining}

    state =
      msgs
      |> Enum.reduce(state, fn msg, state ->
        Logger.debug("received message #{inspect(msg)}")
        handle_msg(msg, state)
      end)

    {_, state} = command_loop(state)

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:timeout, %{id: id, sub_pieces: sub_pieces}},
        %State{socket: socket, pieces_agent: pieces_agent, downloading: downloading} = state
      ) do
    if Map.has_key?(downloading, id) do
      Logger.warn("Timeout expired while still downloading piece #{id}")

      for {begin, len} <- sub_pieces do
        send_msg(socket, WireProtocol.cancel(id, begin, len))
      end

      Pieces.download_canceled(pieces_agent, id)
    end

    {:noreply, %{state | downloading: Map.delete(downloading, id)}}
  end

  @impl true
  def handle_info(:send_keep_alive, %State{} = state) do
    _ =
      if state.socket do
        send_msg(state.socket, WireProtocol.keep_alive())
        Process.send_after(self(), :send_keep_alive, 30_000)
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

    if Map.has_key?(state.downloading, idx) do
      {:ok, piece} = state.downloading[idx] |> Piece.add_sub_piece(begin, block)

      if piece.complete do
        Logger.debug("Piece #{idx} is completed.")
        piece_hash = Map.get(state.hashes, idx)

        downloading =
          case Piece.binary(piece, piece_hash) do
            {:ok, bin} ->
              FilesWriter.persist(state.files_writer, idx, bin)
              Pieces.downloaded(state.pieces_agent, idx)
              Map.delete(state.downloading, idx)

            {:error, {:wrong_hash, wrong_hash}} ->
              Logger.warn(
                "Wrong hash for piece #{idx}. . Expected hash #{Base.encode16(piece_hash)}, actual hash #{
                  Base.encode16(wrong_hash)
                }"
              )

              :ok = Pieces.wrong_hash(state.pieces_agent, idx)
              state.downloading
          end

        %{state | downloading: downloading}
      else
        %{state | downloading: %{state.downloading | idx => piece}}
      end
    else
      state
    end
  end

  defp handle_msg({:keep_alive, nil}, state) do
    state
  end

  defp command_loop(state) when state.choked, do: {:continue, state}

  defp command_loop(state) when map_size(state.downloading) >= state.max_downloading,
    do: {:continue, state}

  defp command_loop(state) do
    case Pieces.start_downloading(state.pieces_agent, state.have, max: 1) do
      :downloaded ->
        {:downloaded, state}

      ids when map_size(ids) > 0 ->
        if !state.am_interested do
          send_msg(state.socket, WireProtocol.interested())
        end

        downloading =
          for {id, len} <- ids, into: state.downloading do
            Logger.debug "piece with id #{id} has len #{len}"
            piece_partition = FilesWriter.partition_piece(len)

            sub_pieces =
              for {begin, sub_piece_len} <- piece_partition do
                send_msg(
                  state.socket,
                  WireProtocol.request(id, begin, sub_piece_len)
                )

                {begin, sub_piece_len}
              end

            Process.send_after(
              self(),
              {:timeout, %{id: id, sub_pieces: sub_pieces}},
              @piece_timeout
            )

            {id, Piece.new(map_size(piece_partition), len)}
          end

        {:continue, %{state | downloading: downloading, interested: true}}

        _ ->
        {:continue, state}
    end
  end
end
