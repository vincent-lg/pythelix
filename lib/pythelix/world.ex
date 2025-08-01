defmodule Pythelix.World do
  @moduledoc """
  Centralized world.

  This is not a process. The `init` functiln will be called during the applicaiton startup.

  """

  @generic_client "generic/client"
  @generic_menu "generic/menu"
  @motd_menu "menu/motd"
  @game_menu "menu/game"
  @worldlet_dir "worldlets"
  @worldlet_pattern "*.txt"

  alias Pythelix.Command
  alias Pythelix.Record
  alias Pythelix.Scripting
  alias Pythelix.Scripting.Namespace.Extended

  def init() do
    if Application.get_env(:pythelix, :worldlets) do
      apply(:all)
    end
  end

  @doc """
  Apply a worldlet, a directory or a single file path.

  Args:

  - `worldlet` (or `:all`): the path leading to the directory or worldlet file.
  """
  @spec apply(String.t() | :all) :: {:ok, integer()} | :error | :nofile
  def apply(:all) do
    System.get_env("WORLDLETS_PATH", "worldlets")
    |> then(fn path ->
      System.get_env("RELEASE_ROOT", File.cwd!())
      |> Path.join(path)
    end)
    |> String.replace("\\", "/")
    |> apply()
  end

  def apply(worldlet) do
    if File.exists?(worldlet) do
      case process_worldlets(worldlet) do
        :error ->
          :error

        entities ->
          worldlet =
            case :os.type() do
              {:win32, _} -> String.replace(worldlet, "/", "\\")
              _ -> worldlet
            end

          {:ok, worldlet, length(entities)}
      end
    else
      :nofile
    end
  end

  defp process_worldlets(path) do
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
      |> add_sub_entity()
      |> add_client_controls()
      |> add_motd_menu_entity()
      |> add_game_menu_entity()
      |> add_base_menu_entity()
      |> add_base_client_entity()
      |> Command.add_base_command_entity()
    }
  end

  defp add_sub_entity(entities) do
    [
      %{
        virtual: true,
        key: "SubEntity",
        attributes: %{},
        methods: %{},
      } | entities
    ]
  end

  defp add_client_controls(entities) do
    [
      %{
        key: "Controls",
        parent: "SubEntity",
        attributes: %{},
        methods: %{
          "__init__" => {
            [
              {"self", keyword: "self"}
            ],
            "self.__controls = set()"
          },
          "add" => {
            [
              {"self", keyword: "self"},
              {"entity", index: 0, type: :entity}
            ],
            "self.__controls.add(entity.id or entity.key)"
          },
          "remove" => {
            [
              {"self", keyword: "self"},
              {"entity", index: 0, type: :entity}
            ],
            "self.__controls.discard(entity.id or entity.key)"
          },
        },
      } | entities
    ]
  end

  defp add_base_client_entity(entities) do
    [
      %{
        virtual: true,
        key: @generic_client,
        attributes: %{
          "disconnect" => {:extended, Extended.Client, :m_disconnect},
          "msg" => {:extended, Extended.Client, :m_msg},
          "owner" => {:extended_property, Extended.Client, :owner}
        },
        methods: %{},
      } | entities
    ]
  end

  defp add_base_menu_entity(entities) do
    [
      %{
        virtual: true,
        key: @generic_menu,
        attributes: %{
          "prompt" => "\"\"",
          "text" => "\"\""
        },
        methods: %{
          "get_prompt" => {
            [
              {"self", keyword: "self", type: {:entity, "generic/menu"}},
              {"client", index: 0, type: {:entity, "generic/client"}}
            ],
            "return self.prompt"
          },
          "get_text" => {
            [
              {"self", keyword: "self", type: {:entity, "generic/menu"}},
              {"client", index: 0, type: {:entity, "generic/client"}}
            ],
            "return self.text"
          },
          "invalid_input" => {
            [
              {"self", keyword: "self", type: {:entity, "generic/menu"}},
              {"client", index: 0, type: {:entity, "generic/client"}},
              {"input", index: 1, type: :str}
            ],
            "client.msg('Invalid input')"
          }
        },
      } | entities
    ]
  end

  defp add_motd_menu_entity(entities) do
    [
      %{
        virtual: true,
        key: @motd_menu,
        attributes: %{"parent" => "\"#{@generic_menu}\""},
        methods: %{},
      } | entities
    ]
  end

  defp add_game_menu_entity(entities) do
    [
      %{
        virtual: true,
        key: @game_menu,
        attributes: %{"parent" => "\"#{@generic_menu}\""},
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
    {sub_entities, entities} =
      entities
      |> Enum.split_with(fn entity ->
        (entity.key && entity.key =~ ~r/^\p{Lu}/u) || false
      end)

    Enum.each(sub_entities, & create_entity(&1, sub_entity: true))

    entities
    |> Enum.map(&create_entity/1)
    |> tap(fn records ->
      locations =
        Enum.map(entities, fn entity ->
          {entity.key, Map.get(entity.attributes, "location")}
        end)
        |> Map.new()

      Enum.each(records, fn record ->
        location =
          Map.get(locations, record.key)
          |> then(fn
            nil -> nil
            location ->
              {:ok, location} = Scripting.eval(location)
              location
          end)
          |> then(& (&1 && Record.get_entity(&1)) || nil)

        place_entity(record, location)
      end)
    end)
    |> tap(fn records ->
      default_location = Record.get_entity("menu/game")

      Enum.each(records, fn record ->
        if Record.has_parent?(record, "generic/command") do
          if Record.get_location_entity(record) == nil do
            place_entity(record, default_location)
          end
        end
      end)
    end)
    |> tap(fn _ -> Record.Diff.apply() end)
    |> tap(fn _ -> link_commands() end)
  end

  defp create_entity(entity, opts \\ []) do
    {parent, attributes} = Map.pop(entity.attributes, "parent")
    {location, attributes} = Map.pop(attributes, "location")
    parent = (parent && Record.get_entity(parent)) || nil
    location =
      if location do
        {:ok, location} = Scripting.eval(location)
        Record.get_entity(location)
      else
        nil
      end

    virtual_parent = (parent && parent.id == :virtual) || false
    virtual_parent = (opts[:sub_entity] && true) || virtual_parent
    opts = [key: entity.key, parent: parent]

    opts =
      if Map.get(entity, :virtual, virtual_parent) do
        [{:virtual, true} | opts]
      else
        opts
      end

    record = Record.get_entity(entity.key)
    record =
      if record == nil do
        {:ok, record} = Record.create_entity(opts)
        record
      else
        record
      end

    if location do
      Record.change_location(record, location)
    end

    for {name, value} <- attributes do

      value =
        if is_binary(value) do
          {:ok, value} = Scripting.eval(value)

          value
        else
          value
        end

      Record.set_attribute(entity.key, name, value)
    end

    for {name, {args, code}} <- entity.methods do
      Record.set_method(entity.key, name, args, code)
    end

    Record.get_entity(entity.key)
  end

  def link_commands() do
    Record.get_entity("generic/menu")
    |> Record.get_children()
    |> Enum.each(fn menu ->
      commands =
        menu
        |> Record.get_contained()
        |> Enum.filter(& Record.has_parent?(&1, "generic/command"))
        |> tap(fn commands ->
          commands
          |> Enum.map(& Command.build_syntax_pattern(&1.key))
        end)
        |> Enum.flat_map(fn command ->
          command.key
          |> Command.get_command_names()
          |> Enum.flat_map(fn name ->
            1..String.length(name)
            |> Enum.map(fn len -> {String.slice(name, 0, len), command.key} end)
          end)
        end)
        |> Enum.into(%{})

      Record.set_attribute(menu.key, "commands", commands)
    end)
  end

  defp place_entity(entity, location) do
    Record.change_location(entity, location)
  end
end
