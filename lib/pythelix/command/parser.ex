defmodule Pythelix.Command.Parser do
  @moduledoc """
  Parses commands based on a runtime pattern and structured phases.
  Keywords and fixed-size args (e.g., int) must be fully isolated by spaces.
  """

  # Public API
  def parse(pattern, string) do
    with {:ok, anchors} <- split_keywords(pattern, string, []),
         {:ok, anchors, namespace} <- parse_fixed_size(pattern, string, anchors, %{}),
         {:ok, clean_pattern, namespace} <- remove_optional(pattern, anchors, namespace),
         {:ok, clean_pattern} <- reorder_args(clean_pattern, anchors),
         {:ok, namespace} <- parse_args(clean_pattern, anchors, string, namespace) do
      {:ok, namespace}
    else
      err -> err
    end
  end

  # ----------------------------------------------------
  # STEP 1: Detect all keywords positions
  defp split_keywords([], _string, acc), do: {:ok, acc}

  defp split_keywords([{:keyword, [kw]} | rest], string, acc) do
    acc = find_keyword(string, kw, acc)
    split_keywords(rest, string, acc)
  end

  defp split_keywords([{:opt, branch} | rest], string, acc) do
    {:ok, acc} = split_keywords(branch, string, acc)
    split_keywords(rest, string, acc)
  end

  defp split_keywords([_ | rest], string, acc) do
    split_keywords(rest, string, acc)
  end

  defp find_keyword(string, kw, acc) do
    cond do
      string == kw ->
        [{0, byte_size(kw), {:keyword, kw}} | acc]

      String.starts_with?(string, kw <> " ") ->
        [{0, byte_size(kw), {:keyword, kw}} | acc]

      String.ends_with?(string, " " <> kw) ->
        start = byte_size(string) - byte_size(kw)
        [{start, byte_size(string), {:keyword, kw}} | acc]

      true ->
        case :binary.match(string, " " <> kw <> " ") do
          {start, _len} ->
            start = start + 1
            finish = start + byte_size(kw)
            [{start, finish, {:keyword, kw}} | acc]

          :nomatch ->
            acc
        end
    end
  end

  # ----------------------------------------------------
  # STEP 2: Parse fixed size (e.g., :int)
  defp parse_fixed_size([], _string, acc, namespace), do: {:ok, acc, namespace}

  defp parse_fixed_size([{:arg, [{:int, name}]} | rest], string, acc, namespace) do
    case parse_int(string, acc) do
      {:ok, int_value, start, finish} ->
        new_acc = [{start, finish, {:int, name, int_value}} | acc]
        namespace = Map.put(namespace, String.to_atom(name), int_value)

        parse_fixed_size(
          rest,
          string,
          new_acc,
          Map.put(namespace, String.to_atom(name), int_value)
        )

      :nomatch ->
        parse_fixed_size(rest, string, acc, namespace)
    end
  end

  defp parse_fixed_size([{:opt, branch} | rest], string, acc, namespace) do
    {:ok, acc, namespace} = parse_fixed_size(branch, string, acc, namespace)
    parse_fixed_size(rest, string, acc, namespace)
  end

  defp parse_fixed_size([_ | rest], string, acc, namespace) do
    parse_fixed_size(rest, string, acc, namespace)
  end

  defp parse_int(string, anchors) do
    known_ranges = Enum.map(anchors, fn {start, finish, _} -> {start, finish} end)

    # Match fully isolated numbers
    candidates = Regex.scan(~r/(?:^|\s)(\d+)(?=\s|$)/, string, return: :index)

    Enum.find_value(candidates, :nomatch, fn
      # [{block_start, _block_len}, {start, length}] ->
      [_, {start, length}] ->
        finish = start + length

        if Enum.all?(known_ranges, fn {kstart, kfinish} ->
             finish <= kstart or start >= kfinish
           end) do
          int =
            String.slice(string, start, length)
            |> String.trim()
            |> Integer.parse()

          case int do
            {int, _} ->
              {:ok, int, start, finish}

            _ ->
              false
          end
        else
          false
        end
    end)
  end

  # ----------------------------------------------------
  # STEP 3: Remove optional branches
  # defp remove_optional([], _anchors, namespace), do: {:ok, [], namespace}

  # defp remove_optional([{:opt, branch} | rest], anchors, namespace) do
  #  case remove_optional(branch, anchors, namespace) do
  #    {:ok, [], namespace} ->
  #      remove_optional(rest, anchors, namespace)

  #    {:ok, branch, namespace} ->
  #      {:ok, cleaned, namespace} = remove_optional(rest, anchors, namespace)
  #      {:ok, branch ++ cleaned, namespace}
  #  end
  # end

  # defp remove_optional([x | rest], anchors, namespace) do
  #  {:ok, cleaned, namespace} = remove_optional(rest, anchors, namespace)
  #  {:ok, [x | cleaned], namespace}
  # end

  defp remove_optional([], _anchors, namespace), do: {:ok, [], namespace}

  defp remove_optional([{:opt, branch} | rest], anchors, namespace) do
    branch_keywords = collect_branch_keywords(branch)

    if branch_keywords == [] do
      # No keywords inside branch: assume it's always required (flatten it)
      {:ok, cleaned_branch, namespace} = remove_optional(branch, anchors, namespace)
      {:ok, cleaned_rest, namespace} = remove_optional(rest, anchors, namespace)
      {:ok, cleaned_branch ++ cleaned_rest, namespace}
    else
      # Keywords exist: check if all are matched
      if Enum.all?(branch_keywords, fn kw -> keyword_matched?(kw, anchors) end) do
        {:ok, cleaned_branch, namespace} = remove_optional(branch, anchors, namespace)
        {:ok, cleaned_rest, namespace} = remove_optional(rest, anchors, namespace)

        # {:ok, cleaned_branch ++ cleaned_rest, namespace}
        {:ok, [{:branch, cleaned_branch} | cleaned_rest], namespace}
      else
        # Some keywords missing: skip the whole branch
        remove_optional(rest, anchors, namespace)
      end
    end
  end

  defp remove_optional([x | rest], anchors, namespace) do
    {:ok, cleaned_rest, namespace} = remove_optional(rest, anchors, namespace)
    {:ok, [x | cleaned_rest], namespace}
  end

  defp collect_branch_keywords(branch) do
    branch
    |> Enum.flat_map(fn
      {:keyword, [kw]} -> [kw]
      {:opt, inner} -> collect_branch_keywords(inner)
      _ -> []
    end)
  end

  # Helper: check if a keyword is matched among anchors
  defp keyword_matched?(kw, anchors) do
    Enum.any?(anchors, fn
      {_start, _end, {:keyword, matched_kw}} -> matched_kw == kw
      _ -> false
    end)
  end

  defp first_keyword_start(branch, anchors) do
    keywords = collect_branch_keywords(branch)

    anchors
    |> Enum.filter(fn
      {_start, _end, {:keyword, kw}} -> kw in keywords
      {_start, _end, _anything} -> false
      {_start, _end, _anything, _data} -> false
    end)
    |> Enum.map(fn {start, _end, _} -> start end)
    # If no keyword, push to end
    |> Enum.min(fn -> 9_999_999 end)
  end

  # Step 4: reorder arguments
  def reorder_args(pattern, anchors) do
    {branches, normal} =
      Enum.split_with(pattern, fn
        {:branch, _} -> true
        _ -> false
      end)

    sorted_branches =
      branches
      |> Enum.sort_by(fn {:branch, branch} -> first_keyword_start(branch, anchors) end)
      |> Enum.flat_map(fn {:branch, branch} -> branch end)

    {:ok, normal ++ sorted_branches}
  end

  # ----------------------------------------------------
  # STEP 5: Parse remaining arguments
  defp parse_args(pattern, anchors, string, namespace) do
    sorted_anchors = Enum.sort_by(anchors, fn {start, _end, _what} -> start end)

    gaps = find_gaps(sorted_anchors, byte_size(string))

    pattern
    |> Enum.reduce_while({gaps, namespace}, fn
      {:arg, [{:string, name}]}, {[[gstart, gend] | gaps], ns} ->
        value = String.slice(string, gstart, gend - gstart)
        {:cont, {gaps, Map.put(ns, String.to_atom(name), String.trim(value))}}

      _other, acc ->
        {:cont, acc}
    end)
    |> case do
      {[], ns} -> {:ok, ns}
      err -> {:error, :unexpected_input, err}
    end
  end

  defp find_gaps(anchors, len) do
    [{0, 0, :start} | anchors ++ [{len, len, :end}]]
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{_start1, end1, _}, {start2, _end2, _}] ->
      if end1 + 1 < start2, do: [end1, start2], else: nil
    end)
    |> Enum.reject(&is_nil/1)
  end
end
