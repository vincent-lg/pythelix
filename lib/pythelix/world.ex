defmodule Pythelix.World do
  @moduledoc """
  Centralized world.

  This is not a process. The `init` functiln will be called during the applicaiton startup.

  """

  @motd_menu "menu/motd"
  @game_menu "menu/game"

  alias Pythelix.Generic
  @worldlet_dir "worldlets"
  @worldlet_pattern "*.txt"

  alias Pythelix.Command
  alias Pythelix.Game.{Epoch, Modes}
  alias Pythelix.Record
  alias Pythelix.Scripting
  alias Pythelix.Scripting.Namespace.Extended

  def init() do
    if Application.get_env(:pythelix, :worldlets) do
      apply(:all)
    else
      :ok
    end
  end

  @doc """
  Apply a worldlet, a directory or a single file path.

  Args:

  - `worldlet` (or `:all`): the path leading to the directory or worldlet file.
  """
  @spec apply(String.t() | :all) :: {:ok, String.t(), integer()} | {:error, String.t()} | :nofile
  def apply(:all) do
    result =
      Application.get_env(:pythelix, :worldlets_path, Path.join(File.cwd!(), "worldlets"))
      |> String.replace("\\", "/")
      |> apply()

    case result do
      {:error, _} = error -> error
      other -> other
    end
  end

  def apply(worldlet) do
    if worldlet == :static or File.exists?(worldlet) do
      case process_worldlets(worldlet) do
        {:error, reason} ->
          {:error, reason}

        entities ->
          worldlet =
            if worldlet == :static do
              "static"
            else
              case :os.type() do
                {:win32, _} -> String.replace(worldlet, "/", "\\")
                _ -> worldlet
              end
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

        path == :static ->
          []

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
     |> add_game_time_base_unit()
     |> add_game_time_unit()
     |> add_game_time_cyclic_unit()
     |> add_game_time_boundary()
     |> add_game_time_property()
     |> add_game_time_default()
     |> add_base_calendar_entity()
     |> add_motd_menu_entity()
     |> add_game_menu_entity()
     |> add_base_menu_entity()
     |> add_base_client_entity()
     |> add_base_character_entity()
     |> add_base_rangen_entity()
     |> Command.add_base_command_entity()}
  end

  defp add_sub_entity(entities) do
    [
      %{
        virtual: true,
        key: "SubEntity",
        attributes: %{},
        methods: %{}
      }
      | entities
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
          }
        }
      }
      | entities
    ]
  end

  defp add_game_time_base_unit(entities) do
    [
      %{
        key: "GameTimeBaseUnit",
        parent: "SubEntity",
        attributes: %{},
        methods: %{
          "__init__" => {
            [
              {"self", keyword: "self"}
            ],
            "self.__name = 'base'"
          }
        }
      }
      | entities
    ]
  end

  defp add_game_time_unit(entities) do
    [
      %{
        key: "GameTimeUnit",
        parent: "SubEntity",
        attributes: %{},
        methods: %{
          "__init__" => {
            [
              {"self", keyword: "self"},
              {"base", index: 0, type: :str},
              {"factor", index: 1, type: :int},
              {"start", index: 2, keyword: "start", type: :int, default: 0}
            ],
            """
            self.__base = base
            self.__factor = factor
            self.__start = start
            """
          }
        }
      }
      | entities
    ]
  end

  defp add_game_time_cyclic_unit(entities) do
    [
      %{
        key: "GameTimeCyclicUnit",
        parent: "SubEntity",
        attributes: %{},
        methods: %{
          "__init__" => {
            [
              {"self", keyword: "self"},
              {"base", index: 0, type: :str},
              {"cycle", index: 1, type: :int},
              {"start", index: 2, keyword: "start", type: :int, default: 0},
              {"offset", index: 3, keyword: "offset", type: :int, default: 0}
            ],
            """
            self.__base = base
            self.__cycle = cycle
            self.__start = start
            self.__offset = offset
            self.__cyclic = True
            """
          }
        }
      }
      | entities
    ]
  end

  defp add_game_time_boundary(entities) do
    [
      %{
        key: "GameTimeBoundary",
        parent: "SubEntity",
        attributes: %{},
        methods: %{
          "__init__" => {
            [
              {"self", keyword: "self"},
              {"unit", index: 0, type: :str},
              {"from_val", index: 1, type: :int},
              {"to_val", index: 2, type: :int},
              {"value", index: 3, type: :str}
            ],
            """
            self.__unit = unit
            self.__from = from_val
            self.__to = to_val
            self.__value = value
            """
          }
        }
      }
      | entities
    ]
  end

  defp add_game_time_property(entities) do
    [
      %{
        key: "GameTimeProperty",
        parent: "SubEntity",
        attributes: %{},
        methods: %{
          "__init__" => {
            [
              {"self", keyword: "self"},
              {"unit", index: 0, type: :str},
              {"index", index: 1, type: :int},
              {"value", index: 2, type: :str}
            ],
            """
            self.__unit = unit
            self.__index = index
            self.__value = value
            """
          }
        }
      }
      | entities
    ]
  end

  defp add_game_time_default(entities) do
    [
      %{
        key: "GameTimeDefault",
        parent: "SubEntity",
        attributes: %{},
        methods: %{
          "__init__" => {
            [
              {"self", keyword: "self"},
              {"value", index: 0, type: :str}
            ],
            """
            self.__value = value
            self.__default = True
            """
          }
        }
      }
      | entities
    ]
  end

  defp add_base_calendar_entity(entities) do
    [
      %{
        key: Generic.calendar(),
        attributes: %{
          "offset" => 0,
          "type" => "\"custom\""
        },
        methods: %{}
      }
      | entities
    ]
  end

  defp add_base_client_entity(entities) do
    [
      %{
        virtual: true,
        key: Generic.client(),
        attributes: %{
          "disconnect" => {:extended, Extended.Client, :m_disconnect},
          "msg" => {:extended, Extended.Client, :m_msg},
          "controls" => "Controls()"
        },
        methods: %{}
      }
      | entities
    ]
  end

  defp add_base_character_entity(entities) do
    [
      %{
        key: Generic.character(),
        attributes: %{
          "game_modes" => %Modes{}
        },
        methods: %{}
      }
      | entities
    ]
  end

  defp add_base_rangen_entity(entities) do
    [
      %{
        virtual: true,
        key: Generic.rangen(),
        attributes: %{
          "patterns" => "[]",
          "generate" => {:extended, Extended.Rangen, :m_generate},
          "add" => {:extended, Extended.Rangen, :m_add},
          "remove" => {:extended, Extended.Rangen, :m_remove},
          "clear" => {:extended, Extended.Rangen, :m_clear},
          "count" => {:extended_property, Extended.Rangen, :count}
        },
        methods: %{
          "check" => {
            [
              {"self", keyword: "self"},
              {"text", index: 0, type: :str}
            ],
            "return True"
          }
        }
      }
      | entities
    ]
  end

  defp add_base_menu_entity(entities) do
    [
      %{
        virtual: true,
        key: Generic.menu(),
        attributes: %{
          "prompt" => "\"\"",
          "text" => "\"\""
        },
        methods: %{
          "get_prompt" => {
            [
              {"self", keyword: "self", type: {:entity, Generic.menu()}},
              {"client", index: 0, type: {:entity, Generic.client()}}
            ],
            "return self.prompt"
          },
          "get_text" => {
            [
              {"self", keyword: "self", type: {:entity, Generic.menu()}},
              {"client", index: 0, type: {:entity, Generic.client()}}
            ],
            "return self.text"
          },
          "invalid_input" => {
            [
              {"self", keyword: "self", type: {:entity, Generic.menu()}},
              {"client", index: 0, type: {:entity, Generic.client()}},
              {"input", index: 1, type: :str}
            ],
            "client.msg('Invalid input')"
          }
        }
      }
      | entities
    ]
  end

  defp add_motd_menu_entity(entities) do
    [
      %{
        virtual: true,
        key: @motd_menu,
        attributes: %{"parent" => "\"#{Generic.menu()}\""},
        methods: %{}
      }
      | entities
    ]
  end

  defp add_game_menu_entity(entities) do
    [
      %{
        virtual: true,
        key: @game_menu,
        attributes: %{"parent" => "\"#{Generic.menu()}\""},
        methods: %{}
      }
      | entities
    ]
  end

  defp maybe_deduce_parents({:error, error}), do: {:error, error}

  defp maybe_deduce_parents({:ok, entities}) do
    Enum.reduce_while(entities, {:ok, []}, fn entity, {:ok, acc} ->
      attributes = entity.attributes
      parent = attributes["parent"]

      case parent do
        nil ->
          {:cont, {:ok, acc ++ [entity]}}

        parent ->
          case Scripting.eval(parent) do
            {:ok, parent} ->
              attributes = Map.put(attributes, "parent", parent)
              {:cont, {:ok, acc ++ [%{entity | attributes: attributes}]}}

            {:error, reason} ->
              {:halt,
               {:error,
                "error evaluating parent '#{parent}' for entity '#{entity.key}': #{reason}"}}
          end
      end
    end)
  end

  defp merge_entities([entity]), do: entity

  defp merge_entities([first_entity | rest_entities]) do
    Enum.reduce(rest_entities, first_entity, fn entity, acc ->
      Map.merge(acc, entity, fn _key, acc_value, entity_value ->
        case {acc_value, entity_value} do
          # Merge nested maps (like attributes and methods)
          {acc_map, entity_map} when is_map(acc_map) and is_map(entity_map) ->
            Map.merge(acc_map, entity_map)

          # For non-maps, the newer entity value takes precedence
          _ ->
            entity_value
        end
      end)
    end)
  end

  defp maybe_sort_entities({:error, error}), do: {:error, error}

  defp maybe_sort_entities({:ok, entities}) do
    # Group entities by key and merge duplicates
    entity_map =
      entities
      |> Enum.group_by(& &1.key)
      |> Enum.map(fn {key, entity_list} ->
        merged_entity = merge_entities(entity_list)
        {key, merged_entity}
      end)
      |> Map.new()

    graph =
      for entity <- entities, into: %{} do
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
      methods: %{}
    }
  end

  defp topo_sort(graph) do
    try do
      {:ok,
       do_topo_sort(graph, [], MapSet.new(), MapSet.new())
       |> Enum.uniq()}
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
    try do
      {sub_entities, entities} =
        entities
        |> Enum.split_with(fn entity ->
          (entity.key && entity.key =~ ~r/^\p{Lu}/u) || false
        end)

      Enum.each(sub_entities, &create_entity(&1, sub_entity: true))

      entities
      |> Enum.map(&create_entity/1)
      |> tap(fn records ->
        locations =
          Enum.map(entities, fn entity ->
            {entity.key, Map.get(entity.attributes, "location")}
          end)
          |> Map.new()

        Enum.each(records, fn record ->
          case Map.get(locations, record.key) do
            nil ->
              :ok

            location ->
              {:ok, location} = Scripting.eval(location)
              location = Record.get_entity(location)
              place_entity(record, location)
          end
        end)
      end)
      |> tap(fn records ->
        default_location = Record.get_entity("menu/game")

        Enum.each(records, fn record ->
          if Record.has_parent?(record, Generic.command()) do
            if Record.get_location_entity(record) == nil do
              place_entity(record, default_location)
            end
          end
        end)
      end)
      |> tap(fn _ -> Record.Diff.apply() end)
      |> tap(fn _ -> link_commands() end)
      |> tap(fn _ -> Epoch.init() end)
    rescue
      e -> {:error, Exception.message(e)}
    end
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
      args =
        if args == :free do
          :free
        else
          Enum.filter(args, fn {set, _} -> set != "self" end)
        end

      Record.set_method(entity.key, name, args, code)
    end

    Record.get_entity(entity.key)
  end

  def link_commands() do
    Record.get_entity(Generic.menu())
    |> Record.get_children()
    |> Enum.each(fn menu ->
      commands =
        menu
        |> Record.get_contained()
        |> Enum.filter(&Record.has_parent?(&1, Generic.command()))
        |> tap(fn commands ->
          commands
          |> Enum.map(&Command.build_syntax_pattern(&1.key))
        end)
        |> Enum.flat_map(fn command ->
          command.key
          |> Command.get_command_names()
          |> Enum.flat_map(fn name ->
            1..String.length(name)
            |> Enum.map(fn len -> {String.slice(name, 0, len), command.key} end)
          end)
        end)
        |> Enum.reduce(%{}, fn {prefix, command_key}, acc ->
          Map.update(acc, prefix, [command_key], fn existing ->
            if command_key in existing, do: existing, else: existing ++ [command_key]
          end)
        end)

      Record.set_attribute(menu.key, "commands", commands)
    end)
  end

  defp place_entity(entity, location) do
    Record.change_location(entity, location)
  end
end
