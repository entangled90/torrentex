
{:ok, pid} = Torrentex.Torrent.Torrent.start_link(source: "data/ubuntu-20.04.2.0-desktop-amd64.iso.torrent")

:timer.sleep(120_000)
