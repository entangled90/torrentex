defmodule TorrentexLib.Torrent.Peer do
  @type t() :: %__MODULE__{
          id: binary(),
          ip: {integer(), integer(), integer()},
          port: integer()
        }
  defstruct [:id, :ip, :port]

  def show(%__MODULE__{ip: {ip1, ip2, ip3, ip4}, port: port}),
    do: "#{ip1}.#{ip2}.#{ip3}.#{ip4}@#{port}"
end
