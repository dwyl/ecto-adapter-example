defmodule Example.TestApp.Repo do
  use Ecto.Repo,
    otp_app: :example,
    adapter: Example
end
