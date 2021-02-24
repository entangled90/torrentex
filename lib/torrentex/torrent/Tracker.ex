defmodule Torrentex.Torrent.Tracker do
  require Logger

  def generate_peer_id() do
    :crypto.hash(:sha, "#{inspect(node())}-#{:os.system_time(:millisecond)}}")
  end

  def call_tracker(
        url,
        info_hash,
        peer_id,
        download_status,
        event
      ) do
    uri =
      url
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

      if error != nil do
        {:error, error}
      else
        decoded_peers = decode_peers(decoded["peers"])
        {:ok, decoded |> Map.put("peers", decoded_peers)}
      end
    end
  end

  defp decode_peers(peers) when is_list(peers), do: peers

  # Decode response binary format
  defp decode_peers(<<>>), do: []

  defp decode_peers(<<ip1::8, ip2::8, ip3::8, ip4::8, port::16, tail::binary>> = peers)
       when is_binary(peers) do
    ip = {ip1, ip2, ip3, ip4}
    [%{ip: ip, port: port, id: nil} | decode_peers(tail)]
  end
end
