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
    where = [" WHERE ", ?(, get_expression(query), ?)]

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
    {{:., _, [{:&, _, [0]}, field_name]}, _, _} = field

    [?", to_string(field_name), ?"]
  end

  defp get_table(%{sources: sources}) do
    {table, _schema, _prefix} = elem(sources, 0)

    [?", table, ?"]
  end

  defp get_expression(%{wheres: wheres} = query) do
    where = List.first(wheres)

    {:==, _, [{{:., _, [{:&, _, [0]}, field]}, _, _}, value]} = where.expr

    [get_name(query), ?., [?", to_string(field), ?"], " = ", [?', value, ?']]
  end
end
