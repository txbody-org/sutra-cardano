defmodule Sutra.UtilsTest do
  use ExUnit.Case
  alias Sutra.Utils

  describe "safe_head/1" do
    test "returns nil for empty list" do
      assert Utils.safe_head([]) == nil
    end

    test "returns first element of non-empty list" do
      assert Utils.safe_head([1, 2, 3]) == 1
      assert Utils.safe_head(["a", "b"]) == "a"
      assert Utils.safe_head([%{key: "value"}]) == %{key: "value"}
    end
  end

  describe "safe_tail/1" do
    test "returns empty list for empty list" do
      assert Utils.safe_tail([]) == []
    end

    test "returns tail of non-empty list" do
      assert Utils.safe_tail([1, 2, 3]) == [2, 3]
      assert Utils.safe_tail([1]) == []
      assert Utils.safe_tail(["a", "b", "c"]) == ["b", "c"]
    end
  end

  describe "safe_base16_decode/1" do
    test "decodes valid base16 strings" do
      assert Utils.safe_base16_decode("616263") == "abc"
      assert Utils.safe_base16_decode("48656c6c6f") == "Hello"
    end

    test "returns original string for invalid base16" do
      assert Utils.safe_base16_decode("invalid-str") == "invalid-str"
      assert Utils.safe_base16_decode("xyz") == "xyz"
    end

    test "handles non-binary inputs safely" do
      assert Utils.safe_base16_decode(123) == "123"
      assert Utils.safe_base16_decode(:atom) == "atom"
      assert Utils.safe_base16_decode(nil) == ""
    end
  end

  describe "identity/1" do
    test "returns the same value passed to it" do
      assert Utils.identity(42) == 42
      assert Utils.identity("hello") == "hello"
      assert Utils.identity([1, 2, 3]) == [1, 2, 3]
      assert Utils.identity(%{a: 1}) == %{a: 1}
    end
  end

  describe "flip/3" do
    test "applies function with flipped arguments" do
      subtract = fn x, y -> x - y end
      # 2 - 1
      assert Utils.flip(1, 2, subtract) == 1
      # 3 - 5
      assert Utils.flip(5, 3, subtract) == -2
    end

    test "works with list creation function" do
      list_fn = fn x, y -> [x, y] end
      assert Utils.flip(1, 2, list_fn) == [2, 1]
      assert Utils.flip("a", "b", list_fn) == ["b", "a"]
    end
  end

  describe "safe_append/2" do
    test "appends to existing list" do
      assert Utils.safe_append([1, 2], 3) == [1, 2, 3]
      assert Utils.safe_append([1, 2], [3, 4]) == [1, 2, 3, 4]
    end

    test "creates list when first argument is not a list" do
      assert Utils.safe_append(nil, 3) == [3]
      assert Utils.safe_append("not_list", [1, 2]) == [1, 2]
    end
  end

  describe "fst/1 and snd/1" do
    test "fst returns first element of tuple" do
      assert Utils.fst({1, 2}) == 1
      assert Utils.fst({"a", "b"}) == "a"
    end

    test "snd returns second element of tuple" do
      assert Utils.snd({1, 2}) == 2
      assert Utils.snd({"a", "b"}) == "b"
    end
  end

  describe "merge_list/1" do
    test "flattens nested lists" do
      assert Utils.merge_list([]) == []
      assert Utils.merge_list([[1, 2], [3, 4]]) == [1, 2, 3, 4]
      assert Utils.merge_list([["a"], ["b", "c"], ["d"]]) == ["a", "b", "c", "d"]
    end

    test "handles large lists efficiently" do
      large_nested = for i <- 1..1000, do: [i, i + 1000]

      {time_microseconds, result} = :timer.tc(fn -> Utils.merge_list(large_nested) end)

      assert length(result) == 2000
      assert hd(result) == 1
      assert List.last(result) == 2000

      assert time_microseconds < 100_000,
             "merge_list took #{time_microseconds}μs, expected < 100ms"
    end
  end

  describe "ok_or/2" do
    test "returns value from ok tuple" do
      assert Utils.ok_or({:ok, "success"}, "default") == "success"
    end

    test "returns default for non-ok values" do
      assert Utils.ok_or({:error, "failed"}, "default") == "default"
      assert Utils.ok_or(nil, "default") == "default"
    end

    test "calls function for default when provided" do
      default_fn = fn -> "from function" end
      assert Utils.ok_or({:error, "failed"}, default_fn) == "from function"
    end
  end

  describe "ok_or_error/1" do
    test "passes through error tuples" do
      assert Utils.ok_or_error({:error, "failed"}) == {:error, "failed"}
    end

    test "wraps non-error values in ok tuple" do
      assert Utils.ok_or_error("success") == {:ok, "success"}
      assert Utils.ok_or_error(42) == {:ok, 42}
    end
  end

  describe "maybe/3" do
    test "returns default for nil or empty list" do
      assert Utils.maybe(nil, [1, 2, 3], nil) == [1, 2, 3]
      assert Utils.maybe([], [1, 2, 3], nil) == [1, 2, 3]
    end

    test "calls function for default when nil" do
      default_fn = fn -> [1, 2, 3] end
      assert Utils.maybe(nil, default_fn, nil) == [1, 2, 3]
    end

    test "returns original data when not nil or empty" do
      assert Utils.maybe(["a"], [1, 2, 3], nil) == ["a"]
      assert Utils.maybe("value", "default", nil) == "value"
    end

    test "applies converter function when provided" do
      assert Utils.maybe([1, 2, 3], nil, &Enum.join/1) == "123"
      assert Utils.maybe([1, 2, 3], "default", &length/1) == 3
    end
  end

  describe "merge_value_to_map/3" do
    test "merges value to new key" do
      map = %{}
      result = Utils.merge_value_to_map(map, :key, "value")
      assert result == %{key: ["value"]}
    end

    test "appends to existing key" do
      map = %{key: ["old"]}
      result = Utils.merge_value_to_map(map, :key, "new")
      assert result == %{key: ["new", "old"]}
    end

    test "handles list values" do
      map = %{key: ["old"]}
      result = Utils.merge_value_to_map(map, :key, ["new1", "new2"])
      assert result == %{key: ["new1", "new2", "old"]}
    end
  end

  describe "instance_of?/2" do
    defmodule TestStruct do
      defstruct [:field]
    end

    test "returns true for matching struct" do
      struct = %TestStruct{field: "value"}
      assert Utils.instance_of?(struct, TestStruct) == true
    end

    test "returns false for non-matching struct" do
      struct = %TestStruct{field: "value"}
      assert Utils.instance_of?(struct, String) == false
    end

    test "returns false for non-struct values" do
      assert Utils.instance_of?("string", TestStruct) == false
      assert Utils.instance_of?(42, TestStruct) == false
    end

    test "works with lists of structs" do
      structs = [%TestStruct{}, %TestStruct{}]
      assert Utils.instance_of?(structs, TestStruct) == true
    end
  end

  describe "when_ok/2" do
    test "applies function to ok tuple value" do
      double = fn x -> x * 2 end
      assert Utils.when_ok({:ok, 5}, double) == 10
    end

    test "returns original value for non-ok tuples" do
      double = fn x -> x * 2 end
      assert Utils.when_ok({:error, "failed"}, double) == {:error, "failed"}
      assert Utils.when_ok("not tuple", double) == "not tuple"
    end
  end

  describe "without_elem/2" do
    test "removes first matching element" do
      {remaining, removed} = Utils.without_elem([1, 2, 3, 2], fn x -> x == 2 end)
      assert remaining == [1, 3, 2]
      assert removed == 2
    end

    test "returns original list if no match" do
      {remaining, removed} = Utils.without_elem([1, 2, 3], fn x -> x == 5 end)
      assert remaining == [1, 2, 3]
      assert removed == nil
    end

    test "handles empty list" do
      {remaining, removed} = Utils.without_elem([], fn x -> x == 1 end)
      assert remaining == []
      assert removed == nil
    end
  end

  describe "with_sorted_indexed_map/1" do
    test "filters nil values and adds indexes" do
      input = %{a: "value1", b: nil, c: "value2"}
      result = Utils.with_sorted_indexed_map(input)

      # Should filter out nil values and add indexes
      assert map_size(result) == 2
      assert result[:a][:index] in [0, 1]
      assert result[:c][:index] in [0, 1]
      assert result[:a][:value] == "value1"
      assert result[:c][:value] == "value2"
    end

    test "handles map values by adding index directly" do
      input = %{a: %{data: "test"}, b: "simple"}
      result = Utils.with_sorted_indexed_map(input)

      # Map values get index added directly
      assert is_map(result[:a]) and result[:a][:index] != nil
      # Non-map values get wrapped
      assert result[:b][:value] == "simple"
      assert is_integer(result[:b][:index])
    end
  end

  describe "to_sorted_indexed_map/2" do
    test "converts list to indexed map using key function" do
      list = ["apple", "banana", "cherry"]
      key_func = fn str -> String.first(str) end

      result = Utils.to_sorted_indexed_map(list, key_func)

      assert result["a"] == %{index: 0, value: "apple"}
      assert result["b"] == %{index: 1, value: "banana"}
      assert result["c"] == %{index: 2, value: "cherry"}
    end

    test "handles duplicate keys by overwriting" do
      list = ["apple", "avocado"]
      key_func = fn str -> String.first(str) end

      result = Utils.to_sorted_indexed_map(list, key_func)

      # Last item should win
      assert result["a"] == %{index: 1, value: "avocado"}
    end
  end

  describe "safe_last/1" do
    test "returns nil for empty list" do
      assert Utils.safe_last([]) == nil
    end

    test "returns last element of non-empty list" do
      assert Utils.safe_last([1, 2, 3]) == 3
      assert Utils.safe_last(["a"]) == "a"
      assert Utils.safe_last(["first", "last"]) == "last"
    end
  end
end
