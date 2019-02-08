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
