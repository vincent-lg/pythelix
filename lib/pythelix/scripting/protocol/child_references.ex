defprotocol Pythelix.Scripting.Protocol.ChildReferences do
  @fallback_to_any true

  def children(data)
end

defimpl Pythelix.Scripting.Protocol.ChildReferences, for: List do
  def children(list) do
    list
    |> Enum.filter(fn
      %Pythelix.Scripting.Object.Reference{} -> true
      _ -> false
    end)
  end
end

defimpl Pythelix.Scripting.Protocol.ChildReferences, for: MapSet do
  def children(map_set) do
    map_set
    |> Enum.filter(fn
      %Pythelix.Scripting.Object.Reference{} -> true
      _ -> false
    end)
  end
end

defimpl Pythelix.Scripting.Protocol.ChildReferences, for: Any do
  def children(_), do: []
end
