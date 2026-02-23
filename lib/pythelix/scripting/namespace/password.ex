defmodule Pythelix.Scripting.Namespace.Password do
  @moduledoc """
  Module defining the password object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  defmet __bool__(script, _namespace), [] do
    {script, true}
  end

  defmet __repr__(script, namespace), [] do
    {script, inspect(namespace.self)}
  end

  defmet __str__(script, namespace), [] do
    {script, inspect(namespace.self)}
  end

  defmet verify(script, namespace), [
    {:password, index: 0, type: :str}
  ] do
    password = Store.get_value(namespace.self)
    module = password.algorithm

    {script, module.verify(password.hash, namespace.password)}
  end
end
