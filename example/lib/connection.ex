defmodule Example.Connection do
  @behaviour Ecto.Adapters.SQL.Connection

  @impl true
  def child_spec(opts) do
    Postgrex.child_spec(opts)
  end

  @impl true
  def all(query) do
    name = get_name(query)
    select = ["SELECT ", get_selects(query, name)]
    from = [" FROM ", get_table(query), " AS ", name]
    where = where(query)

    [select, from, where]
  end

  defp get_name(%{sources: sources}) do
    {table, _schema, _prefix} = elem(sources, 0)

    String.first(table)
  end

  defp get_selects(%{select: %{fields: fields}}, name) do
    field_map(fields, name)
  end

  defp field_map(fields, name, acc \\ [])

  defp field_map([field | []], name, acc) do
    acc ++ [name, ?., get_field_name(field)]
  end

  defp field_map([field | remaining], name, acc) do
    field_map(remaining, name, acc ++ [name, ?., get_field_name(field), ?,, ?\s])
  end

  defp get_field_name(field) do
    field_name =
      case field do
        {{:., _, [{:&, _, [0]}, field_name]}, _, _} -> field_name
        %Ecto.Query.Tagged{value: {{:., _, [{:&, _, [0]}, field_name]}, [], []}} -> field_name
      end

    [?", to_string(field_name), ?"]
  end

  defp get_table(%{sources: sources}) do
    {table, _schema, _prefix} = elem(sources, 0)

    [?", table, ?"]
  end

  defp where(query) do
    expression = get_expression(query)

    case expression do
      nil -> []
      expr -> [" WHERE ", ?(, expr, ?)]
    end
  end

  defp get_expression(%{wheres: wheres} = query) do
    case List.first(wheres) do
      [] ->
        nil

      nil ->
        nil

      where ->
        {:==, _, [{{:., _, [{:&, _, [0]}, field]}, _, _}, value]} = where.expr

        [get_name(query), ?., [?", to_string(field), ?"], " = ", [?', value, ?']]
    end
  end

  @impl true
  def execute_ddl(ddl) do
    Ecto.Adapters.Postgres.Connection.execute_ddl(ddl)
  end

  @impl true
  def query(conn, sql, params, opts) do
    Postgrex.query(conn, sql, params, opts)
  end

  @impl true
  def ddl_logs(%Postgrex.Result{} = result) do
    %{messages: messages} = result

    for message <- messages do
      %{message: message, severity: severity} = message

      {ddl_log_level(severity), message, []}
    end
  end

  defp ddl_log_level("DEBUG"), do: :debug
  defp ddl_log_level("LOG"), do: :info
  defp ddl_log_level("INFO"), do: :info
  defp ddl_log_level("NOTICE"), do: :info
  defp ddl_log_level("WARNING"), do: :warn
  defp ddl_log_level("ERROR"), do: :error
  defp ddl_log_level("FATAL"), do: :error
  defp ddl_log_level("PANIC"), do: :error
  defp ddl_log_level(_severity), do: :info

  @impl true
  def prepare_execute(conn, name, sql, params, opts) do
    Postgrex.prepare_execute(conn, name, sql, params, opts)
  end

  @impl true
  def insert(prefix, table, header, rows, on_conflict, returning) do
    Ecto.Adapters.Postgres.Connection.insert(prefix, table, header, rows, on_conflict, returning)
  end
end
