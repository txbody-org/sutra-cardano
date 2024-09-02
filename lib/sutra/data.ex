defmodule Sutra.Data do
  @moduledoc """
    Data Manager for Plutus
  """

  @common_types_default_encodings %{
    integer: :default,
    string: :default,
    enum: :default,
    pairs: :default
  }

  alias Sutra.Data.Plutus.Constr
  alias Sutra.Utils
  alias Sutra.Data.Option
  alias Sutra.Data
  alias Sutra.Data.MacroHelper.EnumMacro

  import Sutra.Data.Cbor, only: [extract_value: 1]

  defmacro __using__(_) do
    quote do
      import Sutra.Data, only: [defdata: 2, defdata: 1, defenum: 1, data: 3, data: 2]
      import Sutra.Data.Option
    end
  end

  defmacro defdata(opts \\ [], do: block) do
    ast = __setup__(block, opts)

    case opts[:name] do
      nil ->
        quote do
          unquote(ast)
        end

      module ->
        quote do
          defmodule unquote(module) do
            unquote(ast)
          end
        end
    end
  end

  def __setup__(block, _opts) do
    quote do
      Module.register_attribute(__MODULE__, :__fields, accumulate: true)
      Module.register_attribute(__MODULE__, :__required, accumulate: true)

      alias Sutra.Data

      unquote(block)
      defstruct @__fields

      def from_plutus(%Constr{index: indx, fields: constr_fields} = tag) do
        parsed =
          __MODULE__.__fields__()
          |> Enum.reverse()
          |> Data.__handle_data_decoder__(tag)

        struct(__MODULE__, parsed)
      end

      def to_plutus(%__MODULE__{} = _mod) do
        IO.inspect("to_plutus")
      end

      def __fields__ do
        @__fields
      end

      def __plutus_data_info__ do
      end
    end
  end

  def __handle_data_decoder__(fields, %Constr{fields: constr_fields} = tag) do
    {_, result} =
      Enum.reduce(fields, {constr_fields, %{}}, fn {name, {data_type, opts}}, {c_fields, acc} ->
        {value, c_fields} = __do_decode(data_type, opts, tag, c_fields)
        {c_fields, Map.put(acc, name, value)}
      end)

    result
  end

  def __do_decode(%Option{option: inner}, opts, tag, fields) do
    case tag do
      %Constr{index: 0, fields: [v | _]} -> __do_decode(inner, opts, v, fields)
      _ -> {nil, fields}
    end
  end

  def __do_decode(:enum, opts, tag, fields) do
    value =
      if is_function(opts[:decode_with]) do
        opts[:decode_with].(tag)
      else
        Enum.at(opts[:fields], tag.index)
      end

    {value, fields}
  end

  def __do_decode(_value, opts, _tag, fields) do
    current_value = Utils.safe_head(fields)

    if is_function(opts[:decode_with]) do
      {opts[:decode_with].(current_value), Utils.safe_tail(fields)}
    else
      {extract_value(current_value), Utils.safe_tail(fields)}
    end
  end

  defmacro data(name, type, opts \\ []) do
    quote bind_quoted: [name: name, type: type, opts: opts] do
      Sutra.Data.__handle_data__(__ENV__, name, type, opts)
    end
  end

  defmacro defenum(opts), do: EnumMacro.__define__(opts)

  def __handle_data__(%Macro.Env{module: mod}, name, type, opts) do
    fields = Module.get_attribute(mod, :__fields) || []

    if Enum.find(fields, fn {n, _} -> n == name end) do
      raise ArgumentError, "the field #{name} is already defined"
    end

    if Enum.find(fields, fn {_, {t, _}} -> t == :enum end) do
      raise ArgumentError,
            "There must be only one data with enum type" <> "\n Found multiple data declarations"
    end

    {encode_with, decode_with} = set_encoder_decoder(type, opts)

    Module.put_attribute(
      mod,
      :__fields,
      {name, {type, Keyword.merge(opts, encode_with: encode_with, decode_with: decode_with)}}
    )
  end

  defp set_encoder_decoder(%Option{option: inner_type}, opts) do
    set_encoder_decoder(inner_type, opts)
  end

  defp set_encoder_decoder(type, opts) do
    cond do
      is_function(Keyword.get(opts, :encode_with)) and
          is_function(Keyword.get(opts, :decode_with)) ->
        {opts[:encode_with], opts[:decode_with]}

      Map.has_key?(@common_types_default_encodings, type) ->
        {opts[:encode_with], opts[:decode_with]}

      function_exported?(type, :from_plutus, 1) &&
          function_exported?(type, :to_plutus, 1) ->
        {&type.from_plutus/1, &type.to_plutus/1}

      runtime_module?(type) ->
        {&type.from_plutus/1, &type.to_plutus/1}

      true ->
        raise ArgumentError, """
          Invalid Type #{type}

          Pass `encode_with: &some_function/1, decode_with: &some_function/1` to create custom type
        """
    end
  end

  defp runtime_module?(type) do
    case Atom.to_string(type) do
      ":" <> _ -> false
      _ -> true
    end
  end

  defdelegate encode(data), to: Sutra.Data.Plutus
  defdelegate decode(hex), to: Sutra.Data.Plutus
  defdelegate decode!(hex), to: Sutra.Data.Plutus
end
