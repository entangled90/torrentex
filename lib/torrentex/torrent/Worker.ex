defmodule Torrentex.Torrent.Worker do
  use GenServer
  require Logger

  defmodule DownloadStatus do
    defstruct downloaded: 0, uploaded: 0, left: 0

    def for_torrent(info) do
      case info do
        %Bento.Metainfo.SingleFile{length: length} -> %__MODULE__{left: length}
      end
    end
  end

  @impl true
  def init(source) when is_binary(source) do
    {torrent, info_hash} = decode_torrent(source)
    peer_id = :crypto.hash(:sha, "#{inspect(node())}-#{:os.system_time(:millisecond)}}")

    state = %{
      source: source,
      torrent: torrent,
      info_hash: info_hash,
      peer_id: peer_id,
      tracker_response: nil,
      download_status: DownloadStatus.for_torrent(torrent.info)
    }

    Logger.info("Starting torrent for state #{inspect(state[:torrent])}")
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

  @impl true
  def handle_info({:call_tracker, event} = evt, state) do
    state =
      case call_tracker(state, event) do
        {:ok, resp} ->
          Logger.debug("Response from tracker #{inspect(resp)}")
          Map.put(state, :tracker_response, resp)

        {:error, reason} ->
          Logger.warn("Received failure from tracker: #{inspect(reason)}")
          Process.send_after(self(), evt, 5_000)
          state
      end

    {:noreply, state}
  end

  defp call_tracker(
         %{
           torrent: %Bento.Metainfo.Torrent{announce: announce},
           info_hash: info_hash,
           peer_id: peer_id,
           download_status: download_status
         },
         event
       ) do
    Logger.info("Contacting tracker at #{announce}")

    uri =
      announce
      |> URI.parse()
      |> Map.put(
        :query,
        URI.encode_query(%{
          "info_hash" => info_hash,
          "peer_id" => peer_id,
          "uploaded" => download_status.uploaded,
          "downloaded" => download_status.downloaded,
          "left" => download_status.left,
          "compact" => 1,
          "event" => event,
          "port" => 6881
        })
      )
      |> URI.to_string()

    Logger.info("Tracker uri is #{uri}")

    with {:ok, {{_, 200, _status_string}, _header, body}} <-
           :httpc.request(:get, {uri, []}, [], []),
         {:ok, decoded} <- Bento.decode(body) do
      error = decoded["failure reason"]
      if error != nil, do: {:error, error}, else: {:ok, decoded}
    end
  end

  defp decode_torrent(source) do
    if source |> String.ends_with?(".torrent") do
      file_content = File.read!(source)
      decoded = Bento.decode!(file_content)
      hash = decoded["info"] |> Bento.encode!() |> sha1_sum()
      {Bento.torrent!(file_content), hash}
    else
      raise "Only implemented for torrent files"
    end
  end

  defp sha1_sum(binary), do: :crypto.hash(:sha, binary)
end
