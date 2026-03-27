defmodule Pythelix.Scripting.Namespace.Builtin do
  @moduledoc """
  Bulitin module, containing builtin functions in particular.\"""
  """

  use Pythelix.Scripting.Namespace

  require Logger

  alias Pythelix.{Entity, Record}
  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Display
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Namespace
  alias Pythelix.Scripting.Namespace.Module.Clients
  alias Pythelix.Scripting.Object.{Dict, InputState, Tuple}
  alias Pythelix.Stackable
  alias Pythelix.World

  deffun function_Entity(script, namespace), [
    {:key, keyword: "key", type: :str, default: nil},
    {:parent, keyword: "parent", type: :entity, default: nil},
    {:location, keyword: "location", type: :entity, default: nil}
  ] do
    parent = Store.get_value(namespace.parent)
    location = Store.get_value(namespace.location)

    opts = [key: namespace.key, parent: parent, location: location]
    {:ok, entity} = Pythelix.Record.create_entity(opts)

    {script, entity}
  end

  deffun apply(script, namespace), [
    {:file, index: 0, type: :str, default: :all}
  ] do
    case World.apply(namespace.file) do
      {:ok, path, number} ->
        {script, "Worldlet applied from #{path}: #{number} entities were added or updated."}

      :nofile ->
        {script, "The specified file #{inspect(namespace.file)} doesn't exist."}

      {:error, reason} ->
        {Script.raise(script, RuntimeError, reason), :none}

      :error ->
        {script, "An error occurred, applying cancelled."}
    end
  end

  deffun log(script, namespace), [
    {:message, index: 0, type: :str}
  ] do
    message = Format.String.format(namespace.message)
    Logger.info(message)

    {script, :none}
  end

  deffun entity(script, namespace), [
    {:id, index: 0, type: :int, default: nil},
    {:key, keyword: "key", type: :str, default: nil}
  ] do
    if namespace.id == nil and namespace.key == nil do
      message = "you must specify either the entity ID or key"
      {Script.raise(script, ValueError, message), :none}
    else
      entity =
        (namespace.id || namespace.key)
        |> Pythelix.Record.get_entity()
        |> then(fn
          nil -> :none
          valid -> valid
        end)

      {script, entity}
    end
  end

  deffun dict(script, namespace), [
    {:iterable, index: 0, type: :dict, default: nil},
    {:kwargs, kwargs: true}
  ] do
    iterable = Store.get_value(namespace.iterable)
    kwargs = namespace.kwargs

    dict =
      case iterable do
        nil ->
          kwargs

        iterable ->
          iterable
          |> Dict.new()
          |> Dict.update(kwargs)
      end

    {script, dict}
  end

  deffun set(script, namespace), [
    {:iterable, index: 0, type: :list, default: nil}
  ] do
    iterable = Store.get_value(namespace.iterable, recursive: false)

    set =
      case iterable do
        nil ->
          MapSet.new()

        iterable ->
          MapSet.new(iterable)
      end

    {script, set}
  end

  deffun tuple(script, namespace), [
    {:iterable, index: 0, type: :list, default: nil}
  ] do
    iterable = Store.get_value(namespace.iterable, recursive: false)

    tuple =
      case iterable do
        nil -> %Tuple{elements: []}
        list when is_list(list) -> %Tuple{elements: list}
      end

    {script, tuple}
  end

  deffun stackable(script, namespace), [
    {:entity, index: 0, type: :entity},
    {:quantity, index: 1, type: :int}
  ] do
    entity = Store.get_value(namespace.entity)
    quantity = namespace.quantity

    if Pythelix.Record.get_attribute(entity, "stackable") != true do
      id_or_key = entity.key || entity.id
      {Script.raise(script, TypeError, "entity '#{id_or_key}' is not stackable"), :none}
    else
      stackable = %Stackable{entity: entity, quantity: quantity, location: nil}
      {script, stackable}
    end
  end

  deffun len(script, namespace), [
    {:object, index: 0, type: :any}
  ] do
    try do
      case Callable.call!(script, namespace.object, "__len__", []) do
        {:traceback, _} ->
          {Script.raise(script, TypeError, "object has no len()"), :none}

        value ->
          {script, value}
      end
    rescue
      UndefinedFunctionError ->
        {Script.raise(script, TypeError, "object has no len()"), :none}
    end
  end

  deffun bool(script, namespace), [
    {:object, index: 0, type: :any}
  ] do
    {script, Display.to_bool(script, namespace.object)}
  end

  deffun repr(script, namespace), [
    {:object, index: 0, type: :any}
  ] do
    {script, Display.repr(script, namespace.object)}
  end

  deffun str(script, namespace), [
    {:object, index: 0, type: :any}
  ] do
    {script, Display.str(script, namespace.object)}
  end

  deffun getattr(script, namespace), [
    {:object, index: 0, type: :any},
    {:name, index: 1, type: :str},
    {:default, index: 2, type: :any, default: :no_default}
  ] do
    object = Store.get_value(namespace.object)
    name = Format.String.format(Store.get_value(namespace.name))
    ns = Namespace.locate(object)

    case ns.getattr(script, namespace.object, name) do
      %Script{} = script ->
        if namespace.default != :no_default do
          {%{script | error: nil}, namespace.default}
        else
          {script, :none}
        end

      :none ->
        if namespace.default != :no_default do
          {script, namespace.default}
        else
          {script, :none}
        end

      value ->
        {script, value}
    end
  end

  deffun setattr(script, namespace), [
    {:object, index: 0, type: :any},
    {:name, index: 1, type: :str},
    {:value, index: 2, type: :any}
  ] do
    object = Store.get_value(namespace.object)
    name = Format.String.format(Store.get_value(namespace.name))
    ns = Namespace.locate(object)

    {script, _} = ns.setattr(script, namespace.object, name, namespace.value)
    {script, :none}
  end

  deffun hasattr(script, namespace), [
    {:object, index: 0, type: :any},
    {:name, index: 1, type: :str}
  ] do
    object = Store.get_value(namespace.object)
    name = Format.String.format(Store.get_value(namespace.name))
    ns = Namespace.locate(object)

    case ns.getattr(script, namespace.object, name) do
      %Script{} ->
        {script, false}

      :none ->
        {script, false}

      _ ->
        {script, true}
    end
  end

  deffun delattr(script, namespace), [
    {:object, index: 0, type: :any},
    {:name, index: 1, type: :str}
  ] do
    object = Store.get_value(namespace.object)
    name = Format.String.format(Store.get_value(namespace.name))
    ns = Namespace.locate(object)

    {script, _} = ns.delattr(script, namespace.object, name)
    {script, :none}
  end

  deffun ask(script, namespace), [
    {:entity, index: 0, type: :entity},
    {:prompt, index: 1, keyword: "prompt", type: :str, default: nil},
    {:timeout, keyword: "timeout", type: :any, default: nil}
  ] do
    entity = Store.get_value(namespace.entity)
    prompt = namespace.prompt && Format.String.format(namespace.prompt)
    timeout = namespace.timeout

    case resolve_client(entity) do
      nil ->
        {script, :none}

      {client_id, pid, entity_id_or_key} ->
        if prompt do
          Pythelix.Game.Hub.mark_client_with_message(client_id, prompt, pid)
        end

        input_state = %InputState{
          client_id: client_id,
          client_pid: pid,
          entity_id_or_key: entity_id_or_key,
          prompt: prompt,
          timeout: timeout
        }

        {%{script | pause: :input, input: input_state}, :none}
    end
  end

  deffun choice(script, namespace), [
    {:entity, index: 0, type: :entity},
    {:error_msg, index: 1, type: :str},
    {:choices, index: 2, args: true}
  ] do
    entity = Store.get_value(namespace.entity)
    error_msg = Format.String.format(namespace.error_msg)
    choices = Enum.map(namespace.choices, &Format.String.format/1)

    case resolve_client(entity) do
      nil ->
        {script, :none}

      {client_id, pid, entity_id_or_key} ->
        input_state = %InputState{
          client_id: client_id,
          client_pid: pid,
          entity_id_or_key: entity_id_or_key,
          prompt: nil,
          timeout: nil,
          choices: choices,
          error_msg: error_msg
        }

        {%{script | pause: :input, input: input_state}, :none}
    end
  end

  # Returns {client_id, pid, entity_id_or_key} or nil.
  # entity_id_or_key is nil when the entity itself is a client (login-time asks),
  # since clients are ephemeral and cannot be reconnected to by identity.
  defp resolve_client(%Entity{} = entity) do
    case Record.get_attribute(entity, "client_id") do
      nil ->
        # Controlled entity (character etc.) — find who controls it
        try do
          case Clients.controlling(Entity.get_id_or_key(entity)) do
            [client | _] ->
              client_id = Record.get_attribute(client, "client_id")
              pid = Record.get_attribute(client, "pid")
              {client_id, pid, Entity.get_id_or_key(entity)}

            [] ->
              nil
          end
        rescue
          _ -> nil
        end

      client_id ->
        # The entity is itself a client (login menus, no owner yet)
        pid = Record.get_attribute(entity, "pid")
        {client_id, pid, nil}
    end
  end
end
