defmodule WebFrontendWeb.TorrentController do
  use WebFrontendWeb, :controller

  alias WebFrontend.Torrents
  alias WebFrontend.Torrents.Torrent
  alias TorrentexLib.Torrent.Parser, as: TorrentParser

  def index(conn, _params) do
    torrents = Torrents.list_torrents()
    render(conn, "index.html", torrents: torrents)
  end

  def new(conn, _params) do
    changeset = Torrents.change_torrent(%Torrent{})

    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"torrent" => %{"torrent" => upload}}) do
    %Plug.Upload{content_type: "application/octet-stream", filename: filename, path: path} =
      upload

    {parsed, contents, info_hash} = TorrentParser.decode_torrent(path)
    IO.puts "Info hash is #{inspect info_hash}"

    params = %{name: filename, torrent_file: contents, info_hash: info_hash}
    case Torrents.create_torrent(params) do
      {:ok, torrent} ->
        conn
        |> put_flash(:info, "Torrent created successfully.")
        |> redirect(to: Routes.torrent_path(conn, :show, torrent))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    torrent = Torrents.get_torrent!(id)
    render(conn, "show.html", torrent: torrent)
  end

  def edit(conn, %{"id" => id}) do
    torrent = Torrents.get_torrent!(id)
    changeset = Torrents.change_torrent(torrent)
    render(conn, "edit.html", torrent: torrent, changeset: changeset)
  end

  def update(conn, %{"id" => id, "torrent" => torrent_params}) do
    torrent = Torrents.get_torrent!(id)

    case Torrents.update_torrent(torrent, torrent_params) do
      {:ok, torrent} ->
        conn
        |> put_flash(:info, "Torrent updated successfully.")
        |> redirect(to: Routes.torrent_path(conn, :show, torrent))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", torrent: torrent, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    torrent = Torrents.get_torrent!(id)
    {:ok, _torrent} = Torrents.delete_torrent(torrent)

    conn
    |> put_flash(:info, "Torrent deleted successfully.")
    |> redirect(to: Routes.torrent_path(conn, :index))
  end
end
