defmodule Sutra.Utils do
  @moduledoc """
    Utils
  """

  def safe_head([]), do: nil
  def safe_head([head | _]), do: head

  def safe_tail([]), do: []
  def safe_tail([_ | tail]), do: tail

  def identity(x), do: x

  def flip(a, b, f), do: f.(b, a)

  def maybe(nil, f1, _), do: f1
  def maybe(data, _, f2), do: f2.(data)

  def ok_or({:ok, result}, _), do: result
  def ok_or(_, default) when is_function(default, 0), do: default.()
  def ok_or(result, default) when is_function(default, 1), do: default.(result)
  def ok_or(_, default), do: default

  def safe_append(list, val) when is_list(list) do
    new_val = if is_list(val), do: val, else: [val]
    list ++ new_val
  end

  def safe_append(_, val), do: if(is_list(val), do: val, else: [val])
end
