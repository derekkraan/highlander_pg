defmodule HighlanderPGTest.Repo do
  use Ecto.Repo,
    otp_app: :horde_pro,
    adapter: Ecto.Adapters.Postgres

  def init(_context, config) do
    {:ok, Keyword.put(config, :url, "ecto://postgres:postgres@localhost:5431/highlander")}
  end
end
