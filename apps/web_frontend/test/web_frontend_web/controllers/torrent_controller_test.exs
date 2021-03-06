defmodule WebFrontendWeb.TorrentControllerTest do
  use WebFrontendWeb.ConnCase

  alias WebFrontend.Torrents

  @create_attrs %{downloaded: 42, name: "some name", path: "some path"}
  @update_attrs %{downloaded: 43, name: "some updated name", path: "some updated path"}
  @invalid_attrs %{downloaded: nil, name: nil, path: nil}

  def fixture(:torrent) do
    {:ok, torrent} = Torrents.create_torrent(@create_attrs)
    torrent
  end

  describe "index" do
    test "lists all torrents", %{conn: conn} do
      conn = get(conn, Routes.torrent_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Torrents"
    end
  end

  describe "new torrent" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.torrent_path(conn, :new))
      assert html_response(conn, 200) =~ "New Torrent"
    end
  end

  describe "create torrent" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.torrent_path(conn, :create), torrent: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.torrent_path(conn, :show, id)

      conn = get(conn, Routes.torrent_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Torrent"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.torrent_path(conn, :create), torrent: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Torrent"
    end
  end

  describe "edit torrent" do
    setup [:create_torrent]

    test "renders form for editing chosen torrent", %{conn: conn, torrent: torrent} do
      conn = get(conn, Routes.torrent_path(conn, :edit, torrent))
      assert html_response(conn, 200) =~ "Edit Torrent"
    end
  end

  describe "update torrent" do
    setup [:create_torrent]

    test "redirects when data is valid", %{conn: conn, torrent: torrent} do
      conn = put(conn, Routes.torrent_path(conn, :update, torrent), torrent: @update_attrs)
      assert redirected_to(conn) == Routes.torrent_path(conn, :show, torrent)

      conn = get(conn, Routes.torrent_path(conn, :show, torrent))
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn, torrent: torrent} do
      conn = put(conn, Routes.torrent_path(conn, :update, torrent), torrent: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Torrent"
    end
  end

  describe "delete torrent" do
    setup [:create_torrent]

    test "deletes chosen torrent", %{conn: conn, torrent: torrent} do
      conn = delete(conn, Routes.torrent_path(conn, :delete, torrent))
      assert redirected_to(conn) == Routes.torrent_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.torrent_path(conn, :show, torrent))
      end
    end
  end

  defp create_torrent(_) do
    torrent = fixture(:torrent)
    %{torrent: torrent}
  end
end
