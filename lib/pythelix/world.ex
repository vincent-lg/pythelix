defmodule Pythelix.World do
  @moduledoc """
  Centralized world.

  This is not a process. The `init` functiln will be called during the applicaiton startup.

  """

  @generic_client "generic/client"
  @worldlet_dir "priv/worldlets"
  @worldlet_pattern "*.txt"

  alias Pythelix.Command
  alias Pythelix.Record
  alias Pythelix.Scripting
  alias Pythelix.Scripting.Namespace.Extended

  def init() do
    if Application.get_env(:pythelix, :worldlets) do
      process_worldlets()
    end
  end

  @doc """
  Apply a worldlet, a directory or a single file path.

  Args:

  - `worldlet`: the path leading to the directory or worldlet file.
  """
  @spec apply(String.t()) :: {:ok, integer()} | :error | :nofile
  def apply(worldlet) do
    if File.exists?(worldlet) do
      case process_worldlets(worldlet) do
        :error -> :error
        entities -> {:ok, length(entities)}
      end
    else
      :nofile
    end
  end

  defp process_worldlets(path \\ nil) do
    files =
      cond do
        path == nil ->
          Path.wildcard("#{@worldlet_dir}/**/#{@worldlet_pattern}")

        File.dir?(path) ->
          Path.wildcard("#{path}/**/#{@worldlet_pattern}")

        true ->
          [path]
      end

    files
    |> Enum.map(&Pythelix.World.File.parse_file/1)
    |> Enum.reduce_while([], fn
      {:ok, entities}, acc ->
        {:cont, acc ++ entities}

      {:error, reason}, _acc ->
        {:halt, {:error, reason}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      entities -> {:ok, entities}
    end
    |> maybe_add_base_entities()
    |> maybe_deduce_parents()
    |> maybe_sort_entities()
    |> maybe_create_entities()
  end

  defp maybe_add_base_entities({:error, _} = error), do: error

  defp maybe_add_base_entities({:ok, entities}) do
    {:ok,
      entities
      |> add_base_client_entity()
      |> Command.add_base_command_entity()
    }
  end

  defp add_base_client_entity(entities) do
    [
      %{
        virtual: true,
        key: @generic_client,
        attributes: %{"msg" => {:extended, Extended.Client, :m_msg}},
        methods: %{},
      } | entities
    ]
  end

  defp maybe_deduce_parents({:error, error}), do: {:error, error}

  defp maybe_deduce_parents({:ok, entities}) do
    Enum.map(entities, fn entity ->
      attributes = entity.attributes
      parent = attributes["parent"]

      parent =
        if parent do
          {:ok, parent} = Scripting.eval(parent)

          parent
        else
          nil
        end

      attributes = Map.put(attributes, "parent", parent)
      %{entity | attributes: attributes}
    end)
    |> then(&{:ok, &1})
  end

  defp maybe_sort_entities({:error, error}), do: error

  defp maybe_sort_entities({:ok, entities}) do
    entity_map = Map.new(entities, &{&1.key, &1})

    graph = for entity <- entities, into: %{} do
      parent_key = entity.attributes["parent"]

      {entity.key, List.wrap(parent_key)}
    end

    case topo_sort(graph) do
      {:ok, sorted_keys} ->
        sorted_entities = Enum.map(sorted_keys, &Map.get(entity_map, &1, empty_entity(&1)))
        {:ok, sorted_entities}

      {:error, :cyclic} ->
        {:error, :cyclic_dependency}
    end
  end

  defp empty_entity(key) do
    %{
      key: key,
      attributes: %{},
      methods: %{},
    }
  end

  defp topo_sort(graph) do
    try do
      {:ok,
       do_topo_sort(graph, [], MapSet.new(), MapSet.new())
       |> Enum.uniq()
    }
    catch
      :cycle -> {:error, :cyclic}
    end
  end

  defp do_topo_sort(graph, sorted, visited, visiting) do
    Enum.reduce(graph, sorted, fn {node, _}, acc ->
      if node in visited do
        acc
      else
        visit(node, graph, acc, visited, visiting)
      end
    end)
    |> Enum.reverse()
  end

  defp visit(node, graph, sorted, visited, visiting) do
    cond do
      node in visiting ->
        throw(:cycle)

      node in visited ->
        sorted

      true ->
        visiting = MapSet.put(visiting, node)
        deps = Map.get(graph, node, [])

        sorted =
          Enum.reduce(deps, sorted, fn dep, acc ->
            visit(dep, graph, acc, visited, visiting)
          end)

        MapSet.put(visited, node)
        [node | sorted]
    end
  end

  defp maybe_create_entities({:error, _} = error), do: error

  defp maybe_create_entities({:ok, entities}) do
    Enum.map(entities, fn entity -> create_entity(entity) end)
    |> tap(fn _ -> Record.Diff.apply() end)
  end

  defp create_entity(entity) do
    {parent, attributes} = Map.pop(entity.attributes, "parent")
    parent = (parent && Record.get_entity(parent)) || nil
    virtual_parent = (parent && parent.id == :virtual) || false
    opts = [key: entity.key, parent: parent]

    opts =
      if Map.get(entity, :virtual, virtual_parent) do
        [{:virtual, true} | opts]
      else
        opts
      end

    if Record.get_entity(entity.key) == nil do
      {:ok, _} = Record.create_entity(opts)
    end

    for {name, value} <- attributes do

      {:ok, value} =
        case value do
          code when is_binary(code) -> Scripting.eval(value)
          other -> {:ok, other}
        end

      Record.set_attribute(entity.key, name, value)
    end

    for {name, {args, code}} <- entity.methods do
      Record.set_method(entity.key, name, args, code)
    end

    Record.get_entity(entity.key)
  end
end
