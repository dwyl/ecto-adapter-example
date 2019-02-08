defmodule Example.TestApp.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    opts = [strategy: :one_for_one, name: Example.TestApp.Supervisor]

    Supervisor.start_link([Example.TestApp.Repo], opts)
  end
end
