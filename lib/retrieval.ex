defmodule Retrieval do

  alias Retrieval.Trie
  alias Retrieval.CountTrie
  alias Retrieval.IdTrie
  alias Retrieval.PatternParser
  require Logger
  @moduledoc """
  Provides an interface for creating and collecting data from the trie data structure.
  """

  @doc """
  Returns a new trie. Providing no arguments creates an empty trie. Optionally a binary or
  list of binaries can be passed to `new/1`.

  ## Examples

        Retrieval.new
        %Retrieval.Trie{...}

        Retrieval.new("apple")
        %Retrieval.Trie{...}

        Retrieval.new(~w/apple apply ape ample/)
        %Retrieval.Trie{...}

  """

  def new(), do: %Trie{}

  def new(binaries) when is_list(binaries) do
    cond do
      binaries[:with_counter] == true -> %CountTrie{}
      binaries[:with_id] == true -> %IdTrie{}
      binaries[:with_counter] == false -> %Trie{}
      true -> insert(%Trie{}, binaries)
    end
  end

  def new(binary) when is_binary(binary) do
    insert(%Trie{}, binary)
  end

  # with options
  def new(binaries, options) when is_list(binaries) and is_list(options)  do
    cond do
      options[:with_counter] == true -> insert_with_count(%CountTrie{}, binaries)
      options[:with_id] == true -> insert_with_count(%IdTrie{}, binaries)
      options[:with_counter] == false -> insert(%Trie{}, binaries)
      true -> insert(%Trie{}, binaries)
    end
  end

  def new(binary, options) when is_binary(binary) and is_list(options)  do
    cond do
      options[:with_counter] == true -> insert_with_count(%CountTrie{}, binary)
      options[:with_id] == true -> insert_with_count(%IdTrie{}, binary)
      options[:with_counter] == false -> insert(%Trie{}, binary)
      true -> insert(%Trie{}, binary)
    end
  end



  @doc """
  Inserts a binary or list of binaries into an existing trie.

  ## Examples

        Retrieval.new |> Retrieval.insert("apple")
        %Retrieval.Trie{...}

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.insert(~w/zebra corgi/)
        %Retrieval.Trie{...}

  """

  def insert(%Trie{trie: trie}, binaries) when is_list(binaries) do
    %Trie{trie: Enum.reduce(binaries, trie, &_insert(&2, &1))}
  end

  def insert(%Trie{trie: trie}, binary) when is_binary(binary) do
    %Trie{trie: _insert(trie, binary)}
  end

  def insert(%IdTrie{trie: trie}, binaries, id) when is_list(binaries) do
    %IdTrie{trie: Enum.reduce(binaries, trie, &_insert_id(&2, &1, id))}
  end

  def insert(%IdTrie{trie: trie}, binary, id) when is_binary(binary) do
    %IdTrie{trie: _insert_id(trie, binary, id)}
  end


  def insert_with_count(%CountTrie{trie: trie}, binaries) when is_list(binaries) do
    %CountTrie{trie: Enum.reduce(binaries, trie, &_insert_with_count(&2, &1))}
  end

  def insert_with_count(%CountTrie{trie: trie}, binary) when is_binary(binary) do
    %CountTrie{trie: _insert_with_count(trie, binary)}
  end

  defp _insert(trie, <<next :: utf8, rest :: binary>>) do
    case Map.has_key?(trie, next) do
      true  -> Map.put(trie, next, _insert(trie[next], rest))
      false -> Map.put(trie, next, _insert(%{}, rest))
    end
  end

  defp _insert(trie, <<>>) do
    Map.put(trie, :mark, :mark)
  end

  defp _insert_id(trie, <<next :: utf8, rest :: binary>>, id) do
    case Map.has_key?(trie, next) do
      true  -> Map.put(trie, next, _insert_id(trie[next], rest, id))
      false -> Map.put(trie, next, _insert_id(%{}, rest, id))
    end
  end

  defp _insert_id(trie, <<>>, id) do
    Map.put(trie, :mark, id)
  end


  defp _insert_with_count(trie, <<next :: utf8, rest :: binary>>) do
    case Map.has_key?(trie, next) do
      true  ->
        Map.put(trie, next, _insert_with_count(trie[next], rest))
        |> Map.update(:count, 1, &(&1 + 1))
      false ->
        Map.put(trie, next, _insert_with_count(%{}, rest))
        |> Map.update(:count, 1, &(&1 + 1))
    end
  end

  defp _insert_with_count(trie, <<>>) do
    Map.put(trie, :mark, :mark)
    |> Map.update(:count, 1, &(&1 + 1))
  end

  @doc """
  Returns whether or not a trie contains a given binary key.

  ## Examples

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.contains?("apple")
        true

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.contains?("zebra")
        false

  """

  def contains?(%Trie{trie: trie}, binary) when is_binary(binary) do
    _contains?(trie, binary)
  end
  def contains?(%CountTrie{trie: trie}, binary) when is_binary(binary) do
    _contains?(trie, binary)
  end
  def contains?(%IdTrie{trie: trie}, binary) when is_binary(binary) do
    _contains_id?(trie, binary)
  end

  defp _contains?(trie, <<next :: utf8, rest :: binary>>) do
    case Map.has_key?(trie, next) do
      true  -> _contains?(trie[next], rest)
      false -> false
    end
  end

  defp _contains?(%{mark: :mark}, <<>>) do
    true
  end

  defp _contains?(_trie, <<>>) do
    false
  end

  defp _contains_id?(trie, <<next :: utf8, rest :: binary>>) do
    case Map.has_key?(trie, next) do
      true  -> _contains_id?(trie[next], rest)
      false -> false
    end
  end

  defp _contains_id?(%{mark: id}, <<>>) do
    id
  end

  defp _contains_id?(_trie, <<>>) do
    false
  end

  @doc """
  Returns flat array of thee.

  ## Examples

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.flat()
        ["apple", "apply", "ape", "ample"]

  """
  def flat(%Trie{trie: trie}) do
    _flat(trie, <<>>)
    |> List.flatten()
  end
  def flat(%CountTrie{trie: trie}) do
    _flat_with_count(trie, <<>>)
    |> List.flatten()
  end

  defp _flat(trie, path) do
    trie
    |> Map.keys()
    |> Enum.map(fn(key) ->
      case key do
        :mark -> path
        key -> _flat(trie[key], path <> << key :: utf8 >>)
      end
    end)
  end

  defp _flat_with_count(trie, path) do
    trie
    |> Map.keys()
    |> Enum.map(fn(key) ->
      case key do
        :mark -> path
        :count -> []
        key -> _flat_with_count(trie[key], path <> << key :: utf8 >>)
      end
    end)
  end


  @doc """
  Collects all binaries that begin with a given prefix.

  ## Examples

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.prefix("ap")
        ["apple", "apply", "ape"]

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.prefix("z")
        []

  """

  def prefix(%Trie{trie: trie}, binary) when is_binary(binary) do
    _prefix(trie, binary, binary)
  end
  def prefix(%CountTrie{trie: trie}, binary) when is_binary(binary) do
    _prefix_with_count(trie, binary, binary)
  end

  defp _prefix(trie, <<next :: utf8, rest :: binary>>, acc) do
    case Map.has_key?(trie, next) do
      true  -> _prefix(trie[next], rest, acc)
      false -> []
    end
  end

  # An interesting discovery I made here is that treating the accumulator as a binary is actually quicker
  # than converting the prefix to a char list, prepending to it, reversing when a word is found, and converting
  # to a binary.
  defp _prefix(trie, <<>>, acc) do
    Enum.flat_map(trie, fn
      {:mark, :mark} -> [acc]
      {ch, sub_trie} -> _prefix(sub_trie, <<>>, acc <> <<ch :: utf8>>)
    end)
  end

  defp _prefix_with_count(trie, <<next :: utf8, rest :: binary>>, acc) do
    case Map.has_key?(trie, next) do
      true  -> _prefix_with_count(trie[next], rest, acc)
      false -> []
    end
  end

  defp _prefix_with_count(trie, <<>>, acc) do
    Enum.flat_map(trie, fn
      {:mark, :mark} -> [acc]
      {:count, _} -> []
      {ch, sub_trie} -> _prefix_with_count(sub_trie, <<>>, acc <> <<ch :: utf8>>)
    end)
  end

  @doc """
  Returns the number of words in the tree with this prefix.
  INFO! Work only with CountTrie.

  ## Examples

        Retrieval.new(~w/apple apply ape ample/, with_counter: true)
        |> Retrieval.prefix_count("ap")
        3

        Retrieval.new(~w/apple apply ape ample/, with_counter: true)
        |> Retrieval.prefix_count("am")
        1

        Retrieval.new(~w/apple apply ape ample/, with_counter: true)
        |> Retrieval.prefix_count("")
        4

        Retrieval.new(~w/apple apply ape ample/, with_counter: true)
        |> Retrieval.prefix_count("xxx")
        0

  """


  def prefix_count(%CountTrie{trie: trie}, binary) when is_binary(binary) do
    _prefix_count(trie, binary, binary)
  end

  defp _prefix_count(trie, <<next :: utf8, rest :: binary>>, acc) do
    case Map.has_key?(trie, next) do
      true  -> _prefix_count(trie[next], rest, acc)
      false -> 0
    end
  end

  defp _prefix_count(trie, <<>>, _acc) do
    trie.count
  end



  @doc """
  Collects all binaries match a given pattern. Returns either a list of matches
  or an error in the form `{:error, reason}`.

  ## Patterns

       `*`      - Wildcard, matches any character.

       `[...]`  - Inclusion group, matches any character between brackets.

       `[^...]` - Exclusion group, matches any character not between brackets.

       `{...}`  - Capture group, must be named and can be combined with an
                  inclusion or exclusion group, otherwise treated as a wildcard.
                  All future instances of same name captures are swapped with
                  the value of the initial capture.

  ## Examples

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.pattern("a{1}{1}**")
        ["apple", "apply"]

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.pattern("*{1[^p]}{1}**")
        []

        Retrieval.new(~w/apple apply zebra house/) |> Retrieval.pattern("[hz]****")
        ["house", "zebra"]

        Retrieval.new(~w/apple apply zebra house/) |> Retrieval.pattern("[hz]***[^ea]")
        []

        Retrieval.new(~w/apple apply zebra house/) |> Retrieval.pattern("[hz]***[^ea")
        {:error, "Dangling group (exclusion) starting at column 8, expecting ]"}

  """

  def pattern(%Trie{trie: trie}, pattern) when is_binary(pattern) do
    _pattern(trie, %{}, pattern, <<>>, :parse)
  end
  def pattern(%CountTrie{trie: trie}, pattern) when is_binary(pattern) do
    _pattern(trie, %{}, pattern, <<>>, :parse)
  end

  defp _pattern(trie, capture_map, pattern, acc, :parse) do
    case PatternParser.parse(pattern) do
      {:error, message} -> {:error, message}
      parsed_pattern    -> _pattern(trie, capture_map, parsed_pattern, acc)
    end
  end

  defp _pattern(trie, capture_map, [{:character, ch}|rest], acc) do
    case Map.has_key?(trie, ch) do
      true  -> _pattern(trie[ch], capture_map, rest, acc <> <<ch :: utf8>>)
      false -> []
    end
  end

  defp _pattern(trie, capture_map, [:wildcard|rest], acc) do
    Enum.flat_map(trie, fn
      {:mark, :mark} -> []
      {:count, _} -> []    # for CountTree
      {ch, sub_trie} -> _pattern(sub_trie, capture_map, rest, acc <> <<ch :: utf8>>)
    end)
  end

  defp _pattern(trie, capture_map, [{:exclusion, exclusions}|rest], acc) do
    pruned_trie = Enum.filter(trie, fn({k, _v}) -> !(Map.has_key?(exclusions, k)) end)
    Enum.flat_map(pruned_trie, fn
      {:mark, :mark} -> []
      {:count, _} -> []    # for CountTree
      {ch, sub_trie} -> _pattern(sub_trie, capture_map, rest, acc <> <<ch :: utf8>>)
    end)
  end

  defp _pattern(trie, capture_map, [{:inclusion, inclusions}|rest], acc) do
    pruned_trie = Enum.filter(trie, fn({k, _v}) -> Map.has_key?(inclusions, k) end)
    Enum.flat_map(pruned_trie, fn
      {:mark, :mark} -> []
      {:count, _} -> []    # for CountTree
      {ch, sub_trie} -> _pattern(sub_trie, capture_map, rest, acc <> <<ch :: utf8>>)
    end)
  end

  defp _pattern(trie, capture_map, [{:capture, name}|rest], acc) do
    case Map.has_key?(capture_map, name) do
      true  ->
        match = capture_map[name]
        case Map.has_key?(trie, match) do
          true  -> _pattern(trie[match], capture_map, rest, acc <> <<match :: utf8>>)
          false -> []
        end
      false ->
        Enum.flat_map(trie, fn
          {:mark, :mark} -> []
          {ch, sub_trie} ->
            capture_map = Map.put(capture_map, name, ch)
            _pattern(sub_trie, capture_map, rest, acc <> <<ch :: utf8>>)
        end)
    end
  end

  defp _pattern(trie, capture_map, [{:capture, name, :exclusion, exclusions}|rest], acc) do
    case Map.has_key?(capture_map, name) do
      true  ->
        match = capture_map[name]
        case Map.has_key?(trie, match) do
          true  -> _pattern(trie[match], capture_map, rest, acc <> <<match :: utf8>>)
          false -> []
        end
      false ->
        pruned_trie = Enum.filter(trie, fn({k, _v}) -> !(Map.has_key?(exclusions, k)) end)
        Enum.flat_map(pruned_trie, fn
          {:mark, :mark} -> []
          {:count, _} -> []    # for CountTree
          {ch, sub_trie} ->
            capture_map = Map.put(capture_map, name, ch)
            _pattern(sub_trie, capture_map, rest, acc <> <<ch :: utf8>>)
        end)
    end
  end

  defp _pattern(trie, capture_map, [{:capture, name, :inclusion, inclusions}|rest], acc) do
    case Map.has_key?(capture_map, name) do
      true  ->
        match = capture_map[name]
        case Map.has_key?(trie, match) do
          true  -> _pattern(trie[match], capture_map, rest, acc <> <<match :: utf8>>)
          false -> []
        end
      false ->
        pruned_trie = Enum.filter(trie, fn({k, _v}) -> Map.has_key?(inclusions, k) end)
        Enum.flat_map(pruned_trie, fn
          {:mark, :mark} -> []
          {:count, _} -> []    # for CountTree
          {ch, sub_trie} ->
            capture_map = Map.put(capture_map, name, ch)
            _pattern(sub_trie, capture_map, rest, acc <> <<ch :: utf8>>)
        end)
    end
  end

  defp _pattern(trie, _capture_map, [], acc) do
    case Map.has_key?(trie, :mark) do
      true  -> [acc]
      false -> []
    end
  end

end
