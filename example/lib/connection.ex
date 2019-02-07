defmodule Example.Connection do
  @behaviour Ecto.Adapters.SQL.Connection

  @impl true
  def all(query) do
    select = ["SELECT ", get_name(query), ?., get_field(query)]
    from = [" FROM ", get_table(query), " AS ", get_name(query)]
    where = [" WHERE ", ?(, get_expression(query), ?)]

    [select, from, where]
  end

  defp get_name(%{sources: sources}) do
    {table, _schema, _prefix} = elem(sources, 0)

    String.first(table)
  end

  defp get_field(%{select: %{fields: fields}}) do
    [{{:., _, [{:&, _, [0]}, field]}, _, _}] = fields

    [?", to_string(field), ?"]
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
