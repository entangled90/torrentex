defmodule WebFrontend.Repo do
  use Ecto.Repo,
    otp_app: :web_frontend,
    adapter: Ecto.Adapters.Postgres
end
