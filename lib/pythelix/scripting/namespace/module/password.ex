defmodule Pythelix.Scripting.Namespace.Module.Password do
  @moduledoc """
  Module defining the password module.
  """

  use Pythelix.Scripting.Module, name: "password"

  alias Pythelix.Scripting.Object.Password

  defmet hash(script, namespace), [
    {:password, index: 0, type: :str}
  ] do
    module =
      Application.get_env(:pythelix, :password_algorithms, [])
      |> List.first()

    hash = module.hash(namespace.password)
    password = %Password{algorithm: module, hash: hash}

    {script, password}
  end
end
