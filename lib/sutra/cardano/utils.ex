defmodule Sutra.Utils do
  @moduledoc """
    Utils
  """

  def safe_head([]), do: nil
  def safe_head([head | _]), do: head

  def safe_tail([]), do: []
  def safe_tail([_ | tail]), do: tail

  def safe_base16_decode(val) when is_binary(val) do
    val
    |> Base.decode16(case: :mixed)
    |> ok_or(val)
  end

  def identity(x), do: x

  def flip(a, b, f), do: f.(b, a)

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
end
