defmodule Example do
  use Ecto.Adapters.SQL,
    driver: :postgrex,
    migration_lock: "FOR UPDATE"

  @impl true
  def supports_ddl_transaction? do
    true
  end

  @behaviour Ecto.Adapter.Storage

  @impl true
  def storage_down(opts) do
    Ecto.Adapters.Postgres.storage_down(opts)
  end

  @impl true
  def storage_up(opts) do
    Ecto.Adapters.Postgres.storage_up(opts)
  end
end
