defmodule WebFrontend.Torrents do
  @moduledoc """
  The Torrents context.
  """

  import Ecto.Query, warn: false
  alias WebFrontend.Repo

  alias WebFrontend.Torrents.Torrent

  @doc """
  Returns the list of torrents.

  ## Examples

      iex> list_torrents()
      [%Torrent{}, ...]

  """
  def list_torrents do
    Repo.all(Torrent)
  end

  @doc """
  Gets a single torrent.

  Raises `Ecto.NoResultsError` if the Torrent does not exist.

  ## Examples

      iex> get_torrent!(123)
      %Torrent{}

      iex> get_torrent!(456)
      ** (Ecto.NoResultsError)

  """
  def get_torrent!(id), do: Repo.get!(Torrent, id)

  @doc """
  Creates a torrent.

  ## Examples

      iex> create_torrent(%{field: value})
      {:ok, %Torrent{}}

      iex> create_torrent(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_torrent(attrs \\ %{}) do
    %Torrent{}
    |> Torrent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a torrent.

  ## Examples

      iex> update_torrent(torrent, %{field: new_value})
      {:ok, %Torrent{}}

      iex> update_torrent(torrent, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_torrent(%Torrent{} = torrent, attrs) do
    torrent
    |> Torrent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a torrent.

  ## Examples

      iex> delete_torrent(torrent)
      {:ok, %Torrent{}}

      iex> delete_torrent(torrent)
      {:error, %Ecto.Changeset{}}

  """
  def delete_torrent(%Torrent{} = torrent) do
    Repo.delete(torrent)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking torrent changes.

  ## Examples

      iex> change_torrent(torrent)
      %Ecto.Changeset{data: %Torrent{}}

  """
  def change_torrent(%Torrent{} = torrent, attrs \\ %{}) do
    Torrent.changeset(torrent, attrs)
  end
end
