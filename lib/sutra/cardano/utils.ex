defmodule Sutra.Utils do
  @moduledoc """
  General utility functions for common operations.

  This module provides helper functions for safe operations on lists, maps, tuples,
  and result handling. All functions are designed to be safe and handle edge cases gracefully.
  """

  @doc """
    Returns head of list. For empty list returns nil
    
    ## Examples

      iex> safe_head([])
      nil
        
      iex> safe_head([1,2,3])
      1
    
  """
  @spec safe_head(list()) :: any() | nil
  def safe_head([]), do: nil
  def safe_head([head | _]), do: head

  @doc """
    Returns tail of list. For empty list returns empty list

    ## Examples

        iex> safe_tail([])
        []

        iex> safe_tail([1, 2, 3])
        [2, 3]

  """
  @spec safe_tail(list()) :: list()
  def safe_tail([]), do: []
  def safe_tail([_ | tail]), do: tail

  @doc """
    Decode Base16 encoded String. Returns original string for Invalid value
    
    ## Examples
    
        iex> safe_base16_decode("616263")
        "abc"
        
        iex> safe_base16_decode("invalid-str")
        "invalid-str"
    
  """
  @spec safe_base16_decode(any()) :: binary()
  def safe_base16_decode(val) when is_binary(val) do
    val
    |> Base.decode16(case: :mixed)
    |> ok_or(val)
  end

  def safe_base16_decode(val), do: to_string(val)

  @doc """
    Returns the input value unchanged. Useful for function composition and default transforms.
    
    ## Examples
    
        iex> identity(42)
        42
        
        iex> identity("hello")
        "hello"
        
        iex> identity([1, 2, 3])
        [1, 2, 3]
    
  """
  @spec identity(any()) :: any()
  def identity(x), do: x

  @doc """
    Apply function by flipping arguments
    
    ## Examples
    
      
      iex> flip(1, 2, fn x, y -> [x, y] end)
      [2, 1]
      
      iex> flip(2, 1, fn x, y -> [x, y] end)
      [1, 2]
      
  """
  @spec flip(any(), any(), (any(), any() -> any())) :: any()
  def flip(a, b, f), do: f.(b, a)

  @doc """
    return default value if value is nil or empty list. 

    ## Examples
        
        iex> maybe(nil, [1,2,3])
        [1, 2, 3]

        iex> maybe([], [1,2,3])
        [1, 2, 3]

        iex> maybe(nil, fn -> [1, 2, 3] end)
        [1, 2, 3] 

        iex> maybe(["a"], [1, 2, 3])
        ["a"]

    
    maybe can also be used to apply function on values
    
    ## Examples
      
        iex> maybe([1, 2, 3], nil, &Enum.join/1)
        "123"
  """

  @spec maybe(any(), any(), (any() -> any()) | nil) :: any()
  def maybe(data, default, convertor \\ nil)

  def maybe(result, arg, _) when is_nil(result) or result == [] do
    if is_function(arg, 0), do: arg.(), else: arg
  end

  def maybe(data, _, f2) when is_function(f2, 1), do: f2.(data)
  def maybe(data, _, nil), do: data

  @doc """
    Returns value from {:ok, value} tuple, otherwise returns default.
    
    ## Examples
    
        iex> ok_or({:ok, "success"}, "default")
        "success"
        
        iex> ok_or({:error, "failed"}, "default")
        "default"
        
        iex> ok_or(nil, "default")
        "default"
    
  """
  @spec ok_or({:ok, any()} | any(), any()) :: any()
  def ok_or({:ok, result}, _), do: result
  def ok_or(_, default) when is_function(default, 0), do: default.()
  def ok_or(result, default) when is_function(default, 1), do: default.(result)
  def ok_or(_, default), do: default

  @doc """
    Safely appends value to list. Creates new list if first argument is not a list.
    
    ## Examples
    
        iex> safe_append([1, 2], 3)
        [1, 2, 3]
        
        iex> safe_append([1, 2], [3, 4])
        [1, 2, 3, 4]
        
        iex> safe_append(nil, 3)
        [3]
    
  """
  @spec safe_append(any(), any()) :: list()
  def safe_append(list, val) when is_list(list) do
    new_val = if is_list(val), do: val, else: [val]
    list ++ new_val
  end

  def safe_append(_, val), do: if(is_list(val), do: val, else: [val])

  @doc """
    Merges value to map key, appending to existing list values.
    
    ## Examples
    
        iex> merge_value_to_map(%{}, :key, "value")
        %{key: ["value"]}
        
        iex> merge_value_to_map(%{key: ["old"]}, :key, "new")
        %{key: ["new", "old"]}
    
  """
  @spec merge_value_to_map(map(), any(), any()) :: map()
  def merge_value_to_map(map, key, value) do
    prev_val = Map.get(map, key, [])
    new_val = if is_list(value), do: value, else: [value]
    Map.put(map, key, new_val ++ prev_val)
  end

  @doc """
    Filters nil values from map and adds indexes. For map values, adds index directly; for other values, wraps in indexed structure.
    
    ## Examples
    
        iex> result = with_sorted_indexed_map(%{a: "value1", b: nil, c: "value2"})
        iex> map_size(result)
        2
        iex> result[:a][:value]
        "value1"
        iex> result[:c][:value]
        "value2"
        iex> is_integer(result[:a][:index])
        true

        iex> result = with_sorted_indexed_map(%{a: %{data: "test"}, b: "simple"})
        iex> result[:a][:data]
        "test"
        iex> result[:b][:value]
        "simple"
        iex> is_integer(result[:a][:index]) and is_integer(result[:b][:index])
        true
    
  """
  @spec with_sorted_indexed_map(map()) :: map()
  def with_sorted_indexed_map(map) when is_map(map) do
    map = Map.filter(map, fn {_k, v} -> not is_nil(v) end)

    for {{k, v}, i} <- Enum.with_index(map), into: %{} do
      if is_map(v) and not is_struct(v),
        do: {k, Map.put(v, :index, i)},
        else: {k, %{index: i, value: v}}
    end
  end

  @doc """
    Converts list to indexed map using key function. Each element gets wrapped with its index and value.
    
    ## Examples
    
        iex> to_sorted_indexed_map(["apple", "banana", "cherry"], fn str -> String.first(str) end)
        %{"a" => %{index: 0, value: "apple"}, "b" => %{index: 1, value: "banana"}, "c" => %{index: 2, value: "cherry"}}
        
        iex> to_sorted_indexed_map([1, 2, 3], fn x -> x * 10 end)
        %{10 => %{index: 0, value: 1}, 20 => %{index: 1, value: 2}, 30 => %{index: 2, value: 3}}
    
  """
  @spec to_sorted_indexed_map(list(), (any() -> any())) :: map()
  def to_sorted_indexed_map(list, key_func) when is_list(list) and is_function(key_func, 1) do
    for {v, i} <- Enum.with_index(list), into: %{} do
      {key_func.(v), %{index: i, value: v}}
    end
  end

  @doc """
    Removes first matching element from list and returns {remaining_list, removed_element}.
    
    ## Examples
    
        iex> without_elem([1, 2, 3, 2], fn x -> x == 2 end)
        {[1, 3, 2], 2}
        
        iex> without_elem([1, 2, 3], fn x -> x == 5 end)
        {[1, 2, 3], nil}
    
  """
  @spec without_elem(list(), (any() -> boolean())) :: {list(), any() | nil}
  def without_elem([], _), do: {[], nil}

  def without_elem([h | t], func) when is_function(func, 1) do
    if func.(h) do
      {t, h}
    else
      {elems, v} = without_elem(t, func)
      {[h | elems], v}
    end
  end

  @doc """
    Flattens nested lists into a single list.
    
    ## Examples
    
        iex> merge_list([[1, 2], [3, 4]])
        [1, 2, 3, 4]
        
        iex> merge_list([])
        []
    
  """
  @spec merge_list([list()]) :: list()
  def merge_list(list), do: List.flatten(list)

  @doc """
    Returns first element of a tuple.
    
    ## Examples
    
        iex> fst({1, 2})
        1
        
        iex> fst({"a", "b"})
        "a"
    
  """
  @spec fst({any(), any()}) :: any()
  def fst({a, _}), do: a

  @doc """
    Returns second element of a tuple.
    
    ## Examples
    
        iex> snd({1, 2})
        2
        
        iex> snd({"a", "b"})
        "b"
    
  """
  @spec snd({any(), any()}) :: any()
  def snd({_, b}), do: b

  @doc """
    Checks if value is an instance of given struct module.
    
    ## Examples
    
        iex> instance_of?(%URI{}, URI)
        true
        
        iex> instance_of?("string", URI)
        false
    
  """
  @spec instance_of?(any(), module()) :: boolean()
  def instance_of?(v, l) when is_struct(v), do: v.__struct__ == l

  def instance_of?([v | rest], l),
    do: instance_of?(v, l) and (rest == [] or instance_of?(rest, l))

  def instance_of?(_, _), do: false

  @doc """
    Applies function to value if it's an {:ok, value} tuple, otherwise returns original value.
    
    ## Examples
    
        iex> when_ok({:ok, 5}, fn x -> x * 2 end)
        10
        
        iex> when_ok({:error, "failed"}, fn x -> x * 2 end)
        {:error, "failed"}
    
  """
  @spec when_ok({:ok, any()} | any(), (any() -> any())) :: any()
  def when_ok({:ok, result}, apply) when is_function(apply, 1) do
    apply.(result)
  end

  def when_ok(result, _), do: result

  @doc """
    Wraps non-error values in {:ok, value} tuple. Passes through error tuples unchanged.
    
    ## Examples
    
        iex> ok_or_error("success")
        {:ok, "success"}
        
        iex> ok_or_error({:error, "failed"})
        {:error, "failed"}
    
  """
  @spec ok_or_error({:error, any()} | any()) :: {:ok, any()} | {:error, any()}
  def ok_or_error({:error, err}), do: {:error, err}
  def ok_or_error(result), do: {:ok, result}

  @doc """
    Returns the last element of a list. For empty list returns nil.
    
    ## Examples
    
        iex> safe_last([])
        nil
        
        iex> safe_last([1, 2, 3])
        3
        
        iex> safe_last(["a"])
        "a"
    
  """
  @spec safe_last(list()) :: any() | nil
  def safe_last([]), do: nil
  def safe_last(list), do: List.last(list)
end
