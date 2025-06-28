defmodule Mix.Tasks.Compile.Pythello do
  use Mix.Task.Compiler

  @moduledoc "Compiler to build Pythello module"
  @recursive true

  def run(_args) do
    #{:ok, _} = Application.load(:pythelix)

    modules =
      :pythelix
      |> Application.spec(:modules)             # all modules in this app
      |> Enum.filter(&is_pythello?/1)

    content = generate_registry_module(modules)
    path = Path.join(["lib", "pythello.ex"])
    File.write!(path, content)
    Mix.shell().info("Generated Pythello registry with #{length(modules)} modules")

    {:ok, []}
  end

  defp is_pythello?(mod) do
    attrs = mod.__info__(:attributes)
    Keyword.get(attrs, :pythello_module, false)
  rescue
    _ -> false
  end

  defp generate_registry_module(mods) do
    body =
      mods
      |> Enum.map(fn mod ->
        attrs = mod.__info__(:attributes)
        name = Keyword.get(attrs, :pythello_module_name, [nil]) |> List.first()
        {mod, name}
      end)
      |> Enum.map(fn {mod, name} -> "    #{inspect(name)} => #{inspect(mod)}" end)
      |> Enum.join(",\n")

    """
    defmodule Pythello do
      @moduledoc "Auto-generated registry of Pyhello modules"
      def all, do: %{
    #{body}
      }
    end
    """
  end
end
