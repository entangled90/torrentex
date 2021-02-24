defmodule Torrentex.Torrent.Supervisor do
  alias Torrentex.Torrent.Worker
  require Logger
  use GenServer

  @moduledoc """
  {:ok, pid} = GenServer.call(TorrentSupervisor, {:start, "data/ubuntu-20.04.2.0-desktop-amd64.iso.torrent"})
  {:ok, pid} = GenServer.call(TorrentSupervisor, {:start, "data/Fedora-KDE-Live-x86_64-33.torrent"})

  """
  def start_link(_default) do
    GenServer.start_link(__MODULE__, nil, name: TorrentSupervisor)
  end

  @impl true
  @spec init(any) :: {:ok, nil}
  def init(_opts) do
    Logger.info("Torrent supervisor started: #{inspect(self())}")
    {:ok, nil}
  end

  @impl true
  def handle_call({:start, source}, _from, state) do
    pid = GenServer.start_link(Worker, source)
    {:reply, pid, state}
  end
end
