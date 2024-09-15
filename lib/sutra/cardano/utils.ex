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
end
