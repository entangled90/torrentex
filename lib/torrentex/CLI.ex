defmodule Torrentex.Cli do

  def main(args) do
    {opts,_,_}= OptionParser.parse(args,switches: [file: :string], aliases: [f: :file])
    IO.inspect opts #here I just inspect the options to stdout
    file = Keyword.fetch!(opts, :file)
    Process.flag(:trap_exit, true)
    {:ok, pid} = Torrentex.Torrent.Torrent.start_link(file)
    receive do
      msg -> IO.inspect msg
    end
  end
end
