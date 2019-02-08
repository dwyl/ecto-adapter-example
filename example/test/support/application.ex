defmodule Example.TestApp.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children =
      case Code.ensure_compiled(Example.TestApp) do
        {:error, _} ->
          []

        {:module, Example.TestApp} ->
          [supervisor(Example.TestApp.Repo, [])]
      end

    opts = [strategy: :one_for_one, name: Example.TestApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
