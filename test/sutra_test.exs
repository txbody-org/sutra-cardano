defmodule SutraTest do
  use ExUnit.Case
  doctest Sutra

  test "greets the world" do
    assert Sutra.hello() == :world
  end
end
