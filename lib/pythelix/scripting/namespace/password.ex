defmodule Pythelix.Scripting.Namespace.Password do
  @moduledoc """
  Module defining the password object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  defmet verify(script, namespace), [
    {:password, index: 0, type: :str}
  ] do
    password = Script.get_value(script, namespace.self)
    module = password.algorithm

    {script, module.verify(password.hash, namespace.password)}
  end
end
