defmodule Pythelix.World do
  @moduledoc """
  Centralized world.

  This is not a process. The `init` functiln will be called during the applicaiton startup.

  """

  require Logger

  @motd_menu "menu/motd"
  @game_menu "menu/game"

  alias Pythelix.Generic

  alias Pythelix.Command
  alias Pythelix.Game.{Epoch, Modes, TickManager}
  alias Pythelix.Record
  alias Pythelix.Scripting
  alias Pythelix.Scripting.Namespace.Extended
  alias Pythelix.World.{Check, Sources}
  alias Extended.Menu, as: ExtendedMenu

  def init() do
    if Application.get_env(:pythelix, :worldlets) do
      apply(:all)
      |> tap(&report_notices/1)
    else
      :ok
    end
  end

  # At startup nobody is reading the result of applying, so what deserves
  # attention goes to the log.
  defp report_notices({:ok, _path, _number, notices}) do
    Enum.each(notices, &Logger.warning/1)
  end

  defp report_notices(_result), do: :ok

  @doc """
  Apply a worldlet, a directory or a single file path.

  Args:

  - `worldlet` (or `:all`): the path leading to the directory or worldlet file.

  Returns `{:ok, path, number_of_entities, notices}`, the notices being
  sentences worth showing the builder even though the worldlet applied (a
  file that wasn't UTF-8, say).
  """
  @spec apply(Sources.source() | :static) ::
          {:ok, String.t(), integer(), [String.t()]} | {:error, String.t()} | :nofile
  def apply(:static = worldlet), do: do_apply(worldlet, {:ok, []})

  def apply(worldlet) when is_binary(worldlet) do
    worldlet = Pythelix.Paths.resolve(worldlet)

    do_apply(worldlet, Sources.files(worldlet))
  end

  def apply(source), do: do_apply(source, Sources.files(source))

  defp do_apply(_source, :nofile), do: :nofile

  defp do_apply(_source, {:error, reason}), do: {:error, reason}

  defp do_apply(source, {:ok, files}) do
    case process_worldlets(files, source) do
      {:error, reason} ->
        {:error, explain(source, reason)}

      {entities, notices} ->
        {:ok, Sources.label(source), length(entities), notices}
    end
  end

  # Whatever went wrong, say it in terms of the worldlet rather than of the
  # engine: a missing `endif` should read as a missing `endif`, not as a match
  # error with a stacktrace. When the checker has nothing to say about it, the
  # original message stands.
  defp explain(:static, reason), do: readable(reason)

  defp explain(path, reason) do
    Check.explain(path) || readable(reason)
  end

  # Some failures are reported as an atom, which reaches the administrator as
  # bare "cyclic_dependency". Say what it means and where to look.
  defp readable(:cyclic_dependency) do
    "Entities depend on each other in a circle, so they cannot be ordered. " <>
      "Check their `parent` and `location` attributes."
  end

  defp readable(reason) when is_binary(reason), do: reason
  defp readable(reason), do: inspect(reason)

  defp process_worldlets(files, source) do
    files
    |> Enum.map(&Pythelix.World.File.parse_file/1)
    |> Enum.reduce_while({[], []}, fn
      {:ok, entities, notices}, {acc, acc_notices} ->
        {:cont, {acc ++ entities, acc_notices ++ notices}}

      {:error, reason}, _acc ->
        {:halt, {:error, reason}}
    end)
    |> case do
      {:error, reason} ->
        {:error, reason}

      {entities, notices} ->
        {:ok, entities}
        |> maybe_add_base_entities(source)
        |> maybe_deduce_parents()
        |> maybe_sort_entities()
        |> maybe_create_entities()
        |> with_notices(notices)
    end
  end

  defp with_notices({:error, _} = error, _notices), do: error
  defp with_notices(entities, notices), do: {entities, notices}

  defp maybe_add_base_entities({:ok, entities}, source) do
    {:ok, base_entities(source) ++ entities}
  end

  # A single path applied on its own is a partial update of a world that
  # already exists. Bringing the built-ins back with their default values would
  # silently undo whatever a worldlet or a plugin overrode on them, and only the
  # next full apply would restore it. So they are only added if missing.
  defp base_entities(source) when is_binary(source) do
    Enum.reject(base_entities(:all), &Record.get_entity(&1.key))
  end

  defp base_entities(_source) do
    []
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
    |> add_base_plugin_entity()
    |> Command.add_base_command_entity()
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
          "encoding" => {:extended_property, Extended.Client, :encoding},
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

  # What a plugin's manifest inherits from. Its children are virtual too: they
  # come from `plugin.txt` at every start, so Pythello can ask a plugin's version
  # and they are never saved.
  defp add_base_plugin_entity(entities) do
    [
      %{
        virtual: true,
        key: "generic/plugin",
        attributes: %{
          "name" => "\"\"",
          "version" => "\"\"",
          "pythelix" => "\"*\"",
          "depends" => "{}",
          "description" => "\"\""
        },
        methods: %{}
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
          "text" => "\"\"",
          "get_commands" => {:extended, ExtendedMenu, :m_get_commands}
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
              # `parent = None` is a parent like another: it means "no parent".
              attributes = Map.put(attributes, "parent", if(parent != :none, do: parent))
              {:cont, {:ok, acc ++ [%{entity | attributes: attributes}]}}

            {:error, traceback} ->
              reason = Pythelix.Scripting.Traceback.format(traceback)

              {:halt,
               {:error,
                "error evaluating parent '#{parent}' for entity '#{entity.key}':\n#{reason}"}}
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

    # From the merged entities, not the declarations: an override rarely repeats
    # `parent`, and it must not erase the dependency the first declaration gave.
    graph =
      Map.new(entity_map, fn {key, entity} ->
        {key, List.wrap(entity.attributes["parent"])}
      end)

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

      # Phase 1: create all entities (sub-entities first, then regular).
      Enum.each(sub_entities, &create_entity(&1, sub_entity: true))
      Enum.each(entities, &create_entity/1)

      # Phase 2: assign locations.
      Enum.each(entities, fn entity ->
        case Map.get(entity.attributes, "location") do
          nil ->
            :ok

          location ->
            {:ok, location} = Scripting.eval(location)
            location = Record.get_entity(location)
            record = Record.get_entity(entity.key)
            place_entity(record, location)
        end
      end)

      default_location = Record.get_entity("menu/game")

      Enum.each(entities, fn entity ->
        record = Record.get_entity(entity.key)

        if Record.has_parent?(record, Generic.command()) do
          if exposes_name?(entity) and Record.get_location_entity(record) == nil do
            place_entity(record, default_location)
          end
        end
      end)

      # Phase 3: set attributes and methods.
      Enum.each(sub_entities, &apply_entity_attributes_and_methods/1)
      Enum.each(entities, &apply_entity_attributes_and_methods/1)

      Record.Diff.apply()
      link_commands()
      TickManager.rebuild(Enum.map(entities, & &1.key))
      Epoch.init()

      Enum.map(entities, &Record.get_entity(&1.key))
    rescue
      e -> {:error, Exception.format(:error, e, __STACKTRACE__)}
    end
  end

  # A command with `name = None` is turned off: it stays out of the menus.
  defp exposes_name?(entity) do
    Map.has_key?(entity.attributes, "name") and entity.attributes["name"] != "None"
  end

  defp create_entity(entity, opts \\ []) do
    {parent, _attributes} = Map.pop(entity.attributes, "parent")
    parent = (parent && Record.get_entity(parent)) || nil

    virtual_parent = (parent && parent.id == :virtual) || false
    virtual_parent = (opts[:sub_entity] && true) || virtual_parent
    opts = [key: entity.key, parent: parent]

    opts =
      if Map.get(entity, :virtual, virtual_parent) do
        [{:virtual, true} | opts]
      else
        opts
      end

    case Record.get_entity(entity.key) do
      nil ->
        {:ok, _record} = Record.create_entity(opts)
        :ok

      record ->
        maybe_change_parent(record, entity, parent)
    end
  end

  # `parent` is an ordinary attribute: declaring another one re-parents an entity
  # that already exists. Leaving it out says nothing and changes nothing.
  defp maybe_change_parent(record, entity, parent) do
    parent_id = parent && Pythelix.Entity.get_id_or_key(parent)

    if Map.has_key?(entity.attributes, "parent") and record.parent_id != parent_id do
      case Record.change_parent(record, parent) do
        {:error, reason} -> raise "cannot change the parent of !#{entity.key}!: #{reason}"
        _changed -> :ok
      end
    else
      :ok
    end
  end

  defp apply_entity_attributes_and_methods(entity) do
    attributes =
      entity.attributes
      |> Map.drop(["parent", "location"])

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

      try do
        Record.set_method(entity.key, name, args, code, method_location(entity, name))
      rescue
        e ->
          file = method_file(entity, name) || "unknown file"

          raise "#{file}: syntax error in method '#{name}' of entity '#{entity.key}': #{Exception.message(e)}"
      end
    end
  end

  # Where a method is defined, for tracebacks: the worldlet relative to the
  # game directory and the line of the method's first body line (the `def` is
  # on the line before). Entities the engine adds itself have neither.
  defp method_location(entity, name) do
    with file when is_binary(file) and file != "<string>" <- method_file(entity, name),
         def_line when is_integer(def_line) <- get_in(entity, [:method_lines, name]) do
      [file: Pythelix.Paths.relative(file), line: def_line + 1]
    else
      _ -> []
    end
  end

  defp method_file(entity, name), do: get_in(entity, [:method_files, name])

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
