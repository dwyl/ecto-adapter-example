# ecto-adapter-example

To define our module as an Ecto adapter, we need to add the following lines:

``` elixir
  use Ecto.Adapters.SQL,
    driver: :postgrex,
    migration_lock: "FOR UPDATE"
```

This also provides us with a lot of shared SQL Ecto Adapter functionality, meaning we won't need to define as much ourselves.

We also need to add the following to our `deps` in `mix.exs`

``` elixir
defp deps do
  [
    {:ecto_sql, "~> 3.0.5"},
    {:postgrex, ">= 0.0.0"}
  ]
end
```

Now, if we run `mix compile`, we'll see some errors:

```
warning: function supports_ddl_transaction?/0 required by behaviour Ecto.Adapter.Migration is not implemented (in module Example)
  lib/example.ex:1

warning: function Example.Connection.all/1 is undefined (module Example.Connection is not available)
  lib/example.ex:7

warning: function Example.Connection.delete/4 is undefined (module Example.Connection is not available)
  lib/example.ex:7

...
...
...
```

The first is letting us know that our Adapter implementation is missing a required callback: `supports_ddl_transaction?/0`. The rest are telling us that our `Adapter.Connection` module does not exist.

For the first warning, we can simply implement the callback. A DDL transaction is what we use to create or modify database objects such as tables. As our Adapter will have the ability to create tables, our callback just needs to return `true`.

http://doc.nuodb.com/Latest/Content/DDL-Versus-DML-Transaction-Behavior.htm

```
@impl true
def supports_ddl_transaction? do
  true
end
```

We add `@impl` above the function definition to declare that this is a callback implementation. If we don't add it, we'll get a compiler warning letting us know. This is to ensure we don't accidentally create an unrelated function with the same name.

To handle the rest of the warnings, we'll need to create our `Connection` module.

```
defmodule Example.Connection do
  @behaviour Ecto.Adapters.SQL.Connection

  @impl true
  def child_spec(opts) do
    Postgrex.child_spec(opts)
  end
end
```

We put `@behaviour Ecto.Adapters.SQL.Connection` at the top of the file to decalre this as an implementation of the `Ecto.Adapters.SQL.Connection` behaviour. This means the compiler will let us know if we don't fulfill the requirements for this type of module.

We then define the required `child_spec` callback, as this is simply returning the Postgrex child_spec which will actually handle the database connection details.

So now we run `mix compile` again, and we see some more warnings, letting us know what our Connection module is missing.

```
warning: function all/1 required by behaviour Ecto.Adapters.SQL.Connection is not implemented (in module Example.Connection)
  lib/connection.ex:1

warning: function child_spec/1 required by behaviour Ecto.Adapters.SQL.Connection is not implemented (in module Example.Connection)
  lib/connection.ex:1

warning: function ddl_logs/1 required by behaviour Ecto.Adapters.SQL.Connection is not implemented (in module Example.Connection)
  lib/connection.ex:1
...
...
...
```

For simplification, we're not going to define every required function in this tutorial.

The main thing our Connection module needs to implement is the query callbacks. These are the functions that receive an Ecto Query, and turn it into an executable SQL string.

If we look at the docs for the [`Ecto.Adapters.SQL.Connection`](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Connection.html#content), we can see that  our query functions (all, insert, delete etc.) need to take an Ecto query and return iodata, which is ["a list of integers representing bytes, lists and binaries"](https://hexdocs.pm/elixir/IO.html#iodata_to_binary/1)

You may also notice that we do not need to define the 'get', 'get_by', 'one' `Ecto.Repo` functions. This is because these use the `all` functionality under the hood.

If we build and log a simple query (passing it the option of `structs: false` to display it as a map), it looks like this:

```elixir
query = 
  from u in "users",
  select: u.name,
  where: u.email == "user@test.com"

IO.inspect(query, structs: false)

%{
  __struct__: Ecto.Query,
  aliases: %{},
  assocs: [],
  combinations: [],
  distinct: nil,
  from: %{
    __struct__: Ecto.Query.FromExpr,
    as: nil,
    hints: [],
    prefix: nil,
    source: {"users", nil}
  },
  group_bys: [],
  havings: [],
  joins: [],
  limit: nil,
  lock: nil,
  offset: nil,
  order_bys: [],
  prefix: nil,
  preloads: [],
  select: %{
    __struct__: Ecto.Query.SelectExpr,
    expr: {{:., [type: :any], [{:&, [], [0]}, :name]}, [], []},
    fields: [{{:., [type: :any], [{:&, [], [0]}, :name]}, [], []}],
    file: "example.exs",
    line: 8,
    params: nil,
    take: %{}
  },
  sources: {{"users", nil, nil}},
  updates: [],
  wheres: [
    %{
      __struct__: Ecto.Query.BooleanExpr,
      expr: {:==, [],
       [{{:., [], [{:&, [], [0]}, :email]}, [], []}, "user@test.com"]},
      file: "example.exs",
      line: 8,
      op: :and,
      params: nil
    }
  ],
  windows: []
}
```

Now our task is to take that query, and to turn it into a SQL string.

For the sake of brevity, we'll only implement a limited subset of the functionality of a normal `all` query here, just accepting a single `select`, `from`, and `where` clause.

First, we need to outline our `all` function in our `Connection` module.

``` elixir
@impl true
def all(query) do
  
end
```

Then we build the SQL string. We'll start with the `SELECT` clause. For this, we'll need the `select` and `sources` fields of the query

``` elixir
%{
  ...
  select: %{
    __struct__: Ecto.Query.SelectExpr,
    expr: {{:., [type: :any], [{:&, [], [0]}, :name]}, [], []},
    fields: [{{:., [type: :any], [{:&, [], [0]}, :name]}, [], []}],
    file: "example.exs",
    line: 8,
    params: nil,
    take: %{}
  },
  sources: {{"users", nil, nil}},
  ...
}
```

To start with, we'll assume there's only one field being selected in a query. We can go back and refactor this to allow for multiples later.

If we look at the `fields` field of the `select` map, we see the data we're dealing with.

``` elixir
[{{:., [type: :any], [{:&, [], [0]}, :name]}, [], []}]
```

This is a list of tuples, each containing data about the field being selected. Now, if you're familiar with elixir macros, you may recognise this syntax as a quoted expression. If we call `Macro.to_string/1` on it, it makes a little more sense:

``` elixir
iex(1)> Macro.to_string({{:., [type: :any], [{:&, [], [0]}, :name]}, [], []})
"&0.name()"
```

So we can see that this is a representation of the name field, and the `&0` represents that the field belongs to the first table in our `sources` field, "users".

So to turn this into a SQL string, we simply put the parts together. Remember, for now we're assuming one table, and one field.

``` elixir
@impl true
def all(query) do
  select = ["SELECT ", get_field(query)]
  from = []
  where = []

  [select, from, where]
end

defp get_field(%{select: %{fields: fields}}) do
  [{{:., _, [{:&, _, [0]}, field]}, _, _}] = fields

  to_string(field)
end
```

Also remember, we need to return `iodata`, so we can return a nested list of strings, binaries and bytes. This will be turned into a real SQL string by the Ecto SQL Adapter when it executes this callback.

Now that we know what we're doing, let's move on to the `FROM` clause. We already know that we only have one table, and where to find it; the `sources` field.

``` elixir
@impl true
def all(query) do
  select = ["SELECT ", get_field(query)]
  from = [" FROM ", get_table(query)]
  where = []

  [select, from, where]
end

defp get_field(%{select: %{fields: fields}}) do ...

defp get_table(%{sources: sources}) do
  {table, _schema, _prefix} = elem(sources, 0)

  [?", table, ?"]
end
```

Next, the `WHERE` clause.

``` elixir
@impl true
def all(query) do
  select = ["SELECT ", get_field(query)]
  from = [" FROM ", get_table(query)]
  where = [" WHERE ", ?(, get_expression(query), ?)]

  [select, from, where]
end

defp get_field(%{select: %{fields: fields}}) do ...

defp get_table(%{sources: sources}) do ...

defp get_expression(%{wheres: wheres}) do
  where = List.first(wheres)

  {:==, _, [{{:., _, [{:&, _, [0]}, field]}, _, _}, value]} = where.expr

  [to_string(field), " = ", ?', value, ?']
end
```

You can see here that we're getting the binary representation of parentheses and the single quote character using `?` (https://elixir-lang.org/getting-started/binaries-strings-and-char-lists.html)

## Tests

To get some tests up and running, we need to do some special setup.

In your test folder, create a folder called `support`, and add an `application.ex`, and a `repo.ex` file to it.

In the `repo` file we need to configure the test Repo to use our adapter:

``` elixir
defmodule Example.TestApp.Repo do
  use Ecto.Repo,
    otp_app: :example,
    adapter: Example
end
```

In the `application` file, we need to ensure our Repo is started:

``` elixir
defmodule Example.TestApp.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    opts = [strategy: :one_for_one, name: Example.TestApp.Supervisor]

    Supervisor.start_link([Example.TestApp.Repo], opts)
  end
end
```

Next, we add the config for our Repo to `config/config.exs`

``` elixir
use Mix.Config

config :example, Example.TestApp.Repo,
  username: "postgres",
  password: "postgres",
  database: "adapter_example_test",
  hostname: "localhost",
  pool_size: 10
```

And finally, we have to add a few lines to our `mix.exs`:

``` elixir
...
def project do
  [
    ...
    elixirc_paths: elixirc_paths(Mix.env()) # ensures our test app code is compiled when `Mix.env` is :test
  ]
end

defp elixirc_paths(:test), do: ["lib", "test/support"]
defp elixirc_paths(_), do: ["lib"]

def application do
  [extra_applications: [:logger, :postgrex]] ++ mod(Mix.env()) # ensures our application is started when we run our tests
end

defp mod(:test), do: [mod: {Example.TestApp.Application, []}]
defp mod(_), do: []

...
```

We can now write a test to ensure our `all` function is generating the correct SQL string.

``` elixir
defmodule ExampleTest do
  use ExUnit.Case

  import Ecto.Query, only: [from: 2]

  test "all" do
    query =
      from(u in "users",
        select: u.name,
        where: u.email == "test@test.com"
      )

    assert Ecto.Adapters.SQL.to_sql(:all, Example.TestApp.Repo, query) ==
             {"SELECT u.\"name\" FROM \"users\" AS u WHERE (u.\"email\" = 'test@test.com')", []}
  end
end
```

We use the `Ecto.Adapters.SQL.to_sql/3` function to view the SQL string generated by our adapter.

## Creating a database

So far we've learned how to turn a query into SQL, but we want to actually use our Adapter with a database. For this we'll need to add a few more callback implementations.

First, we need to implement the Ecto.Adapter.Storage behaviour. This is what will allow us to create and drop our database. 

``` elixir
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
```

This is our implementation of `storage_up/1` which is the function that will be called when we run `mix ecto.create`. The main thing it does is to execute the `CREATE DATABASE` command using Postgrex.

The other thing to note is our `maintenance_database`. This is required because Postgrex requires a database when we connect to it (`Postgrex.start_link/1`). So we temporarily connect it to the default postgres database, while we make our new one.

The `storage_down/1` callback is much the same, just using the `DROP DATABASE` command, as this is what's run when we call `mix ecto.drop`. You'll notice we're still using the `maintenance_database`. This is because Postgres can't drop a database while it's in use, so it has to connect to the default one before dropping ours.

``` elixir
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
```