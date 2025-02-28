defmodule Sutra.Utils do
  @moduledoc """
    Utils
  """

  @doc """
    Returns head of list. For empty list returns nil
    
    ## Examples

      iex> safe_head([])
      nil
        
      iex> safe_head([1,2,3])
      1
    
  """
  def safe_head([]), do: nil
  def safe_head([head | _]), do: head

  @doc """
    Returns tails from list. For empty list returns empty list

    ## Examples

        iex> safe_tail([])
        []

        iex> safe_tail([1, 2, 3])
        [2, 3]

  """
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
  def safe_base16_decode(val) when is_binary(val) do
    val
    |> Base.decode16(case: :mixed)
    |> ok_or(val)
  end

  def identity(x), do: x

  @doc """
    Apply function by fliping argument
    
    ## Example
    
      
      iex> flip(1, 2, fn x, y -> [x, y] end)
      [2, 1]
      
      iex> flip(2, 1, fn x, y -> [x, y] end)
      [1, 2]
      
  """
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
        "1,2,3"
  """

  def maybe(data, default, convertor \\ nil)

  def maybe(result, arg, _) when is_nil(result) or result == [] do
    if is_function(arg, 0), do: arg.(), else: arg
  end

  def maybe(data, _, f2) when is_function(f2, 1), do: f2.(data)
  def maybe(data, _, nil), do: data

  def ok_or({:ok, result}, _), do: result
  def ok_or(_, default) when is_function(default, 0), do: default.()
  def ok_or(result, default) when is_function(default, 1), do: default.(result)
  def ok_or(_, default), do: default

  def safe_append(list, val) when is_list(list) do
    new_val = if is_list(val), do: val, else: [val]
    list ++ new_val
  end

  def safe_append(_, val), do: if(is_list(val), do: val, else: [val])

  def merge_value_to_map(map, key, value) do
    prev_val = Map.get(map, key, [])
    new_val = if is_list(value), do: value, else: [value]
    Map.put(map, key, new_val ++ prev_val)
  end

  def with_sorted_indexed_map(map) when is_map(map) do
    map = Map.filter(map, fn {_k, v} -> not is_nil(v) end)

    for {{k, v}, i} <- Enum.with_index(map), into: %{} do
      if is_map(v) and not is_struct(v),
        do: {k, Map.put(v, :index, i)},
        else: {k, %{index: i, value: v}}
    end
  end

  def to_sorted_indexed_map(list, key_func) when is_list(list) and is_function(key_func, 1) do
    for {v, i} <- Enum.with_index(list), into: %{} do
      {key_func.(v), %{index: i, value: v}}
    end
  end

  def without_elem([], _), do: {[], nil}

  def without_elem([h | t], func) when is_function(func, 1) do
    if func.(h) do
      {t, h}
    else
      {elems, v} = without_elem(t, func)
      {[h | elems], v}
    end
  end

  def merge_list([]), do: []
  def merge_list([a | b]), do: a ++ merge_list(b)

  def fst({a, _}), do: a
  def snd({_, b}), do: b

  def instance_of?(v, l) when is_struct(v), do: v.__struct__ == l

  def instance_of?([v | rest], l),
    do: instance_of?(v, l) and (rest == [] or instance_of?(rest, l))

  def instance_of?(_, _), do: false

  def when_ok({:ok, result}, apply) when is_function(apply, 1) do
    {:ok, apply.(result)}
  end

  def when_ok(result, _), do: result

  def ok_or_error({:error, err}), do: {:error, err}
  def ok_or_error(result), do: {:ok, result}
end
