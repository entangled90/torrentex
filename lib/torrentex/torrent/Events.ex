defmodule Torrentex.Torrent.Events do
  use GenServer
  require Logger

  def start_link(args \\ [], opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(args) do
    log_level = Keyword.get(args, :log_level, :debug)
    metadata = Keyword.get(args, :metadata, %{})
    {:ok, %{log_level: log_level, metadata: metadata, subscribers: %{}}}
  end

  def subscribe(pid) do
    GenServer.call(pid, :subscribe)
  end

  def publish(pid, event) do
    GenServer.cast(pid, {:event, event})
  end

  @impl true
  def handle_call(:subscribe, {from, _}, state) do
    mon_ref = Process.monitor(from)
    log(state, "Pid #{inspect(from)} subscribed")
    {:reply, :ok, %{state | subscribers: Map.put(state[:subscribers], mon_ref, from)}}
  end

  @impl true
  def handle_cast({:event, event} = evt, state) do
    for {_, pid} <- state[:subscribers] do
      log(state, "Publishing event to #{inspect pid}: #{inspect event}")
      send pid, evt
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _, _}, state) do
    {:noreply, Map.delete(state, ref)}
  end


  defp log(state, msg), do:    Logger.log(state[:log_level], msg, state[:metadata])
end
