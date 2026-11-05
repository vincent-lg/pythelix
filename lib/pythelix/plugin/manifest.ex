defmodule Pythelix.Plugin.Manifest do
  @moduledoc """
  What a plugin says about itself, read from its `plugin.txt`.

  The manifest is a worldlet declaring one entity:

      !plugin/rooms!
      parent = "generic/plugin"
      name = "Rooms"
      version = "1.2.0"
      pythelix = ">=0.9"
      depends = {"exits": ">=1.0"}
      description = "Rooms with titles, descriptions and exits."

  It has to be understood before any world exists, to know what to load and in
  which order, and by commands that never start the game. So it is read
  statically: values are parsed, never run, and must be literals.
  """

  alias Pythelix.Plugin.Requirement
  alias Pythelix.Scripting.Parser
  alias Pythelix.World.File, as: WorldletFile

  @file_name "plugin.txt"
  @parent "generic/plugin"
  @key_format ~r/^[a-z0-9][a-z0-9_-]*$/

  defstruct [:key, :name, :version, :pythelix, :description, :directory, depends: %{}]

  @type t :: %__MODULE__{
          key: binary(),
          name: binary(),
          version: binary(),
          pythelix: binary() | nil,
          description: binary() | nil,
          directory: binary(),
          depends: %{binary() => binary()}
        }

  @doc """
  The name of a manifest file.
  """
  @spec file_name() :: binary()
  def file_name, do: @file_name

  @doc """
  Whether a string can be a plugin's key.
  """
  @spec valid_key?(term()) :: boolean()
  def valid_key?(key), do: is_binary(key) and key =~ @key_format

  @doc """
  Whether a directory holds a plugin.
  """
  @spec present?(binary()) :: boolean()
  def present?(directory), do: File.regular?(Path.join(directory, @file_name))

  @doc """
  Read the manifest of the plugin in a directory.

  The key has to match the directory's name, unless `key: false` is given (for
  an archive just extracted in a temporary directory).
  """
  @spec read(binary(), keyword()) :: {:ok, t()} | {:error, binary()}
  def read(directory, opts \\ []) do
    path = Path.join(directory, @file_name)
    expected = Keyword.get(opts, :key, Path.basename(directory))

    with :ok <- exists(path),
         {:ok, entities, _notices} <- WorldletFile.parse_file(path),
         {:ok, entity} <- single_entity(entities, path),
         {:ok, key} <- key(entity.key, expected, path),
         {:ok, fields} <- literals(entity.attributes, path),
         {:ok, manifest} <- build(key, fields, directory, path) do
      {:ok, manifest}
    end
  end

  defp exists(path) do
    if File.regular?(path), do: :ok, else: {:error, "#{path}: this plugin has no manifest."}
  end

  defp single_entity([entity], _path), do: {:ok, entity}

  defp single_entity(entities, path) do
    {:error,
     "#{path}: a manifest declares exactly one entity, and this one has #{length(entities)}."}
  end

  defp key("plugin/" <> key, expected, path) do
    cond do
      not valid_key?(key) ->
        {:error,
         "#{path}: #{inspect(key)} is not a valid plugin key " <>
           "(lowercase letters, digits, - and _)."}

      expected != false and key != expected ->
        {:error,
         "#{path}: the key should be !plugin/#{expected}!, " <>
           "matching the directory, and is !plugin/#{key}!."}

      true ->
        {:ok, key}
    end
  end

  defp key(other, _expected, path) do
    {:error, "#{path}: the key should be !plugin/<directory name>!, and is !#{other}!."}
  end

  defp literals(attributes, path) do
    Enum.reduce_while(attributes, {:ok, %{}}, fn {name, code}, {:ok, fields} ->
      case literal(code) do
        {:ok, value} ->
          {:cont, {:ok, Map.put(fields, name, value)}}

        :error ->
          {:halt,
           {:error,
            "#{path}: #{name} should be a literal value, since no world exists yet " <>
              "when a manifest is read, and is: #{code}"}}
      end
    end)
  end

  defp literal(code) when is_binary(code) do
    case Parser.exec(code) do
      {:ok, {:stmt_list, [{:raw, value, _position}]}} -> value(value)
      _other -> :error
    end
  end

  defp literal(_multiline), do: :error

  defp value(value) when is_binary(value) or is_number(value) or is_boolean(value) do
    {:ok, value}
  end

  defp value(:none), do: {:ok, nil}

  defp value({:dict, elements}) do
    pairs = Enum.map(elements, fn {:element, [key, value]} -> {value(key), value(value)} end)

    if Enum.all?(pairs, &match?({{:ok, _}, {:ok, _}}, &1)) do
      {:ok, Map.new(pairs, fn {{:ok, key}, {:ok, value}} -> {key, value} end)}
    else
      :error
    end
  end

  defp value(_expression), do: :error

  defp build(key, fields, directory, path) do
    manifest = %__MODULE__{
      key: key,
      name: Map.get(fields, "name", key),
      version: fields["version"],
      pythelix: fields["pythelix"],
      description: fields["description"],
      directory: directory,
      depends: Map.get(fields, "depends", %{})
    }

    cond do
      fields["parent"] != @parent ->
        {:error, "#{path}: a manifest needs parent = #{inspect(@parent)}."}

      not Requirement.valid_version?(manifest.version) ->
        {:error,
         "#{path}: version should look like \"1.2.0\", and is #{inspect(manifest.version)}."}

      manifest.pythelix != nil and not Requirement.valid?(manifest.pythelix) ->
        {:error, "#{path}: cannot read the requirement #{inspect(manifest.pythelix)}."}

      not valid_depends?(manifest.depends) ->
        {:error,
         "#{path}: depends should map plugin keys to requirements, " <>
           "like {\"exits\": \">=1.0\"}."}

      true ->
        {:ok, manifest}
    end
  end

  defp valid_depends?(depends) when is_map(depends) do
    Enum.all?(depends, fn {key, requirement} ->
      is_binary(key) and Requirement.valid?(requirement)
    end)
  end

  defp valid_depends?(_depends), do: false
end
