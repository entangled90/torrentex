defmodule WebFrontend.Repo.Migrations.CreateTorrents do
  use Ecto.Migration

  def change do
    create table(:torrents) do
      add :name, :string
      add :downloaded, :integer
      add :torrent_file, :binary
      add :info_hash, :binary
      timestamps()
    end

  end
end
