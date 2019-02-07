defmodule Example do
  use Ecto.Adapters.SQL,
    driver: :postgres,
    migration_lock: "FOR UPDATE"

  @impl true
  def supports_ddl_transaction? do
    true
  end
end
