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
  def storage_up(opts) do
    {:ok, _} = Application.ensure_all_started(:postgrex)

    database = Keyword.fetch!(opts, :database)
    maintenance_database = Keyword.get(opts, :maintenance_database, "postgres")
    opts = Keyword.put(opts, :database, maintenance_database)

    command = ~s(CREATE DATABASE "#{database}")

    {:ok, conn} = Postgrex.start_link(opts)

    case Postgrex.query(conn, command, [], opts) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  @impl true
  def storage_down(opts) do
    {:ok, _} = Application.ensure_all_started(:postgrex)

    database = Keyword.fetch!(opts, :database)
    maintenance_database = Keyword.get(opts, :maintenance_database, "postgres")
    opts = Keyword.put(opts, :database, maintenance_database)

    command = "DROP DATABASE \"#{database}\""

    {:ok, conn} = Postgrex.start_link(opts)

    case Postgrex.query(conn, command, [], opts) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end
end
