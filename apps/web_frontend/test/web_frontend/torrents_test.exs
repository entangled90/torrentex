defmodule WebFrontend.TorrentsTest do
  use WebFrontend.DataCase

  alias WebFrontend.Torrents

  describe "torrents" do
    alias WebFrontend.Torrents.Torrent

    @valid_attrs %{downloaded: 42, name: "some name", path: "some path"}
    @update_attrs %{downloaded: 43, name: "some updated name", path: "some updated path"}
    @invalid_attrs %{downloaded: nil, name: nil, path: nil}

    def torrent_fixture(attrs \\ %{}) do
      {:ok, torrent} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Torrents.create_torrent()

      torrent
    end

    test "list_torrents/0 returns all torrents" do
      torrent = torrent_fixture()
      assert Torrents.list_torrents() == [torrent]
    end

    test "get_torrent!/1 returns the torrent with given id" do
      torrent = torrent_fixture()
      assert Torrents.get_torrent!(torrent.id) == torrent
    end

    test "create_torrent/1 with valid data creates a torrent" do
      assert {:ok, %Torrent{} = torrent} = Torrents.create_torrent(@valid_attrs)
      assert torrent.downloaded == 42
      assert torrent.name == "some name"
      assert torrent.path == "some path"
    end

    test "create_torrent/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Torrents.create_torrent(@invalid_attrs)
    end

    test "update_torrent/2 with valid data updates the torrent" do
      torrent = torrent_fixture()
      assert {:ok, %Torrent{} = torrent} = Torrents.update_torrent(torrent, @update_attrs)
      assert torrent.downloaded == 43
      assert torrent.name == "some updated name"
      assert torrent.path == "some updated path"
    end

    test "update_torrent/2 with invalid data returns error changeset" do
      torrent = torrent_fixture()
      assert {:error, %Ecto.Changeset{}} = Torrents.update_torrent(torrent, @invalid_attrs)
      assert torrent == Torrents.get_torrent!(torrent.id)
    end

    test "delete_torrent/1 deletes the torrent" do
      torrent = torrent_fixture()
      assert {:ok, %Torrent{}} = Torrents.delete_torrent(torrent)
      assert_raise Ecto.NoResultsError, fn -> Torrents.get_torrent!(torrent.id) end
    end

    test "change_torrent/1 returns a torrent changeset" do
      torrent = torrent_fixture()
      assert %Ecto.Changeset{} = Torrents.change_torrent(torrent)
    end
  end
end
