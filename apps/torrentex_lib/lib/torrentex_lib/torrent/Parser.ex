defmodule TorrentexLib.Torrent.Parser do

  @spec decode_torrent(binary) :: {struct, binary, binary}
  def decode_torrent(source) do
    file_content = File.read!(source)
    decoded = Bento.decode!(file_content)
    hash = decoded["info"] |> Bento.encode!() |> sha1_sum()
    {Bento.torrent!(file_content), file_content, hash}
  end

  defp sha1_sum(binary), do: :crypto.hash(:sha, binary)
end
