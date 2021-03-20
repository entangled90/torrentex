defmodule Torrentex.Torrent.EventsSpec do
  alias Torrentex.Torrent.Events

  use ExUnit.Case, async: true

  test "subscribing & publishing event works" do
    {:ok, publisher} = Events.start_link()

    :ok = Events.subscribe(publisher)
    Events.publish(publisher, {:update, 1})

    receive do
      {:event, {:update, 1}} ->
        0

      msg ->
        raise ExUnit.AssertionError
    after
      1000 ->
        raise ExUnit.AssertionError
    end
  end
end
