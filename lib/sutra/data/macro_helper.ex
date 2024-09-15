defmodule Sutra.Data.MacroHelper do
  @moduledoc """
    Helper function to define Data Macros
  """
  alias Sutra.Data.Option
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

  def with_encoder_decoder(type, opts) do
    cond do
      is_function(opts[:encode_with], 1) and is_function(opts[:decode_with], 1) ->
        opts

      Enum.member?(@common_types, type) ->
        Keyword.merge(opts, @encode_decode_mapping[type])

      nullable?(type) ->
        with_encoder_decoder(type.option, opts)

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
