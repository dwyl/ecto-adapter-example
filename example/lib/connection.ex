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

  @impl
  def execute_ddl({command, table, columns}) when command in [:create, :create_if_not_exists] do
    [
      [
        "CREATE TABLE IF NOT EXISTS ",
        [?", to_string(table.name), ?"],
        ?\s,
        [?(, column_map(columns, []), get_pk(columns), ?)]
      ]
    ]
  end

  defp column_map([{_, name, type, _} | []], acc) do
    acc ++ [?", to_string(name), ?", ?\s, get_type(type)]
  end

  defp column_map([{_, name, type, _} | remaining], acc) do
    column_map(remaining, acc ++ [?", to_string(name), ?", ?\s, get_type(type), ?,, ?\s])
  end

  defp get_type(type) do
    case type do
      time
      when time in [:utc_datetime, :utc_datetime_usec, :naive_datetime, :naive_datetime_usec] ->
        ["timestamp", ?(, ?0, ?)]

      :string ->
        "varchar"

      _ ->
        to_string(type)
    end
  end

  defp get_pk(columns) do
    case Enum.find(columns, fn {_, _, _, opts} -> Keyword.get(opts, :primary_key) == true end) do
      {_, name, _, _} -> [?,, " PRIMARY KEY ", ?(, ?", to_string(name), ?", ?)]
      nil -> []
    end
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

      {:info, message, []}
    end
  end

  @impl true
  def prepare_execute(conn, name, sql, params, opts) do
    Postgrex.prepare_execute(conn, name, sql, params, opts)
  end

  @impl true
  def insert(_, table, header, rows, _, _) do
    values = [
      ?\s,
      ?(,
      header_map(header, []),
      ?),
      " VALUES ",
      ?(,
      rows |> List.first() |> Enum.with_index() |> value_map([]),
      ?)
    ]

    ["INSERT INTO ", table, values]
  end

  defp header_map([header | []], acc) do
    acc ++ [?", to_string(header), ?"]
  end

  defp header_map([header | remaining], acc) do
    header_map(remaining, acc ++ [?", to_string(header), ?", ?,])
  end

  defp value_map([{_, i} | []], acc) do
    acc ++ [?$, to_string(i + 1)]
  end

  defp value_map([{_, i} | remaining], acc) do
    value_map(remaining, acc ++ [?$, to_string(i + 1), ?,])
  end
end
