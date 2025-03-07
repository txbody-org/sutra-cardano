defmodule SutraTest do
  use ExUnit.Case
  doctest Sutra
  import Sutra.Utils

  doctest Sutra.Utils

  test "greets the world" do
    assert Sutra.hello() == :world
  end
end
