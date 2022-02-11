defmodule Torrentex.Torrent.FileUtils do
  require Logger

  @spec write_at(
          pid | {:file_descriptor, atom, any},
          :bof | :cur | :eof | integer | {:bof, integer} | {:cur, integer} | {:eof, integer},
          binary | iodata()
        ) :: :ok
  def write_at(file_handle, at, content) do
    :file.pwrite(file_handle, at, content)
  end


  @spec load_downloaded_pieces(
          binary,
          pos_integer,
          list(binary())
        ) :: MapSet.t(any)
  def load_downloaded_pieces(path, piece_length, hashes) do
    Logger.info "Loading downloaded pieces for #{path} with piece_length #{piece_length}"
      File.stream!(path, [], piece_length)
      |> Stream.zip(hashes)
      |> Stream.with_index()
      |> Stream.filter(fn {{chunk, hash}, _} -> :crypto.hash(:sha, chunk) == hash end)
      |> Stream.map(fn {_, idx} -> idx end)
      |> Enum.reduce(MapSet.new, fn el, acc -> MapSet.put(acc, el) end)
  end
end
