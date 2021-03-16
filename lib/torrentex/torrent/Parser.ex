defmodule Torrentex.Torrent.Parser do


  @spec decode_torrent(binary()) :: {Bento.Metainfo.Torrent.t(), binary()}
  def decode_torrent(source) do
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
