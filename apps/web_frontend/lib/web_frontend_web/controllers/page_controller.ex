defmodule WebFrontendWeb.PageController do
  use WebFrontendWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
