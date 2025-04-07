defmodule Sutra.Data.MacroHelper do
  @moduledoc """
    Helper function to define Data Macros
  """
  alias Sutra.Data.Option
  alias Sutra.Data.Plutus.Constr
  alias Sutra.Data.Plutus.PList
  alias Sutra.Utils
  import Sutra.Data.Cbor, only: [extract_value: 1]

  # Add more common support types
  @common_types [
    :string,
    :integer,
    :null,
    :address
  ]

  @encode_decode_mapping %{
    string: [
      decode_with: &extract_value/1,
      encode_with: &Sutra.Utils.identity/1
    ],
    integer: [
      decode_with: &extract_value/1,
      encode_with: &Sutra.Utils.identity/1
    ],
    null: [
      decode_with: &extract_value/1,
      encode_with: &Sutra.Utils.identity/1
    ],
    address: [
      decode_with: &Sutra.Cardano.Address.from_plutus/1,
      encode_with: &Sutra.Cardano.Address.to_plutus/1
    ]
  }

  defp encode_tuple(field_kind, value) do
    Tuple.to_list(value)
    |> Enum.with_index()
    |> Enum.map(fn {fld, indx} ->
      case elem(field_kind, indx) do
        v when is_tuple(v) ->
          encode_tuple(v, fld)

        [field_kind: v] ->
          encode_tuple(v, fld)

        v ->
          v[:encode_with].(fld)
      end
    end)
  end

  def handle_to_plutus(field_info, value) do
    case {field_info[:field_kind], value} do
      {%Option{}, nil} ->
        %Constr{index: 1, fields: []}

      {%Option{option: v}, _} when is_tuple(v) ->
        %Constr{index: 0, fields: [encode_tuple(v, value)]}

      {%Option{}, _} ->
        %Constr{index: 0, fields: [field_info[:encode_with].(value)]}

      {field_kind, _} when is_tuple(field_kind) ->
        encode_tuple(field_kind, value)

      _ ->
        field_info[:encode_with].(value)
    end
  end

  defp decode_tuple(field_kind, fields) when is_list(fields) do
    Enum.with_index(fields)
    |> Enum.map(fn {fld, indx} ->
      case elem(field_kind, indx) do
        v when is_tuple(v) ->
          decode_tuple(v, fld)

        [field_kind: v] ->
          decode_tuple(v, fld)

        v ->
          v[:decode_with].(fld)
          |> Utils.ok_or(nil)
      end
    end)
    |> List.to_tuple()
  end

  defp decode_tuple(field_kind, %PList{value: val}), do: decode_tuple(field_kind, val)

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def handle_from_plutus(field_info, name, plutus_field) do
    case {field_info[:field_kind], plutus_field} do
      {%Option{}, %Constr{index: 1}} ->
        {:ok, nil}

      {%Option{option: v}, %Constr{index: 0, fields: [fields]}}
      when is_tuple(v) ->
        {:ok, decode_tuple(v, fields)}

      {%Option{}, %Constr{index: 0, fields: [option_field]}} ->
        field_info[:decode_with].(option_field)

      {%Option{}, %Constr{index: 0, fields: option_fields}} ->
        field_info[:decode_with].(option_fields)

      {%Option{}, _} ->
        {:error,
         %{
           reason: :invalid_data_for_option_type,
           message: """
            Could not parse data for field: #{name}.
            Expected Constr with index 0 or 1 but got: #{inspect(plutus_field)} 
           """,
           field: name,
           from: __MODULE__
         }}

      {field_kind, %PList{value: fields}} when is_tuple(field_kind) and is_list(fields) ->
        {:ok, decode_tuple(field_kind, fields)}

      {field_kind, fields} when is_tuple(field_kind) and is_list(fields) ->
        {:ok, decode_tuple(field_kind, fields)}

      {field_kind, fields} when is_tuple(field_kind) ->
        {:error,
         %{
           reason: :invalid_data_for_tuple_type,
           message: """
            Could not parse to tuple for field: #{name}.
            Expected value to be list but got: #{inspect(fields)}
           """,
           field: name,
           from: __MODULE__
         }}

      _ ->
        field_info[:decode_with].(plutus_field)
    end
  end

  defp tuple_encoders_decoders(tuple, opts \\ []) do
    Tuple.to_list(tuple)
    |> Enum.map(&with_encoder_decoder(&1, opts))
    |> List.to_tuple()
  end

  def with_encoder_decoder(%Option{option: value}, opts) when is_tuple(value) do
    Keyword.put(opts, :field_kind, %Option{option: tuple_encoders_decoders(value)})
  end

  def with_encoder_decoder(%Option{option: value}, opts), do: with_encoder_decoder(value, opts)

  def with_encoder_decoder(type, opts) do
    cond do
      is_function(opts[:encode_with], 1) and is_function(opts[:decode_with], 1) ->
        opts

      Enum.member?(@common_types, type) ->
        Keyword.merge(opts, @encode_decode_mapping[type])

      is_tuple(type) ->
        Keyword.put(opts, :field_kind, tuple_encoders_decoders(type))

      runtime_module?(type) ->
        opts
        |> Keyword.merge(encode_with: &type.to_plutus/1, decode_with: &type.from_plutus/1)

      true ->
        raise ArgumentError, "Unsupported type: #{inspect(type)}"
    end
  end

  defp runtime_module?(type) do
    case Atom.to_string(type) do
      "Elixir." <> _ -> true
      _ -> false
    end
  end

  def nullable?(%Option{}), do: true
  def nullable?(_), do: false
end
