defmodule Pythelix.Password.Finder do
  @moduledoc """
  The finder to find the available algorithms on this system.
  """

  def find() do
    Application.get_env(:pythelix, :password_algorithms, [])
    |> Enum.filter(fn module ->
      module.available()
    end)
  end
end
