
{:ok, pid} = Torrentex.Torrent.Torrent.start_link(source: "data/ubuntu-21.10-desktop-amd64.iso.torrent")

:timer.sleep(120_000)
