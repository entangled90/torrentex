defmodule WebFrontend.Torrents.Torrent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "torrents" do
    @primary_key {:id, :binary_id, autogenerate: true}
    field :downloaded, :integer, default: 0
    field :name, :string
    field :torrent_file, :binary
    field :info_hash, :binary

    timestamps()
  end

  @doc false
  def changeset(torrent, attrs) do
    torrent
    |> cast(attrs, [:name, :torrent_file, :info_hash, :downloaded])
    |> validate_required([:name, :torrent_file, :info_hash, :downloaded])
  end
end
