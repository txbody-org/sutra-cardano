defmodule Sutra.Cardano.Script do
  @moduledoc """
    Cardano script
  """
  @type script_type() :: :plutus_v1 | :plutus_v2 | :plutus_v3
  @type script_data() :: binary()
  @type t() :: %__MODULE__{
          script_type: script_type(),
          data: script_data()
        }

  defstruct [:script_type, :data]

  alias __MODULE__.NativeScript

  alias __MODULE__.NativeScript.{
    ScriptAll,
    ScriptAny,
    ScriptInvalidBefore,
    ScriptInvalidHereafter,
    ScriptNOfK,
    ScriptPubkey
  }

  alias Sutra.Blake2b
  alias Sutra.Data.Cbor
  alias Sutra.Utils

  defguard is_native_script(a)
           when is_struct(a, ScriptAll) or is_struct(a, ScriptAny) or is_struct(a, ScriptNOfK) or
                  is_struct(a, ScriptPubkey) or is_struct(a, ScriptInvalidBefore) or
                  is_struct(a, ScriptInvalidHereafter)

  defguard is_script(s)
           when is_native_script(s) or is_struct(s, __MODULE__)

  def script?(s) when is_script(s), do: true
  def script?(_), do: false

  def decode_script_type!(1), do: :native
  def decode_script_type!(3), do: :plutus_v1
  def decode_script_type!(6), do: :plutus_v2
  def decode_script_type!(7), do: :plutus_v3

  def encode_script_type(script_type) do
    case script_type do
      :native -> 1
      :plutus_v1 -> 3
      :plutus_v2 -> 6
      :plutus_v3 -> 7
    end
  end

  @doc """
    returns script hash
  """
  def hash_script(script = %__MODULE__{})
      when is_binary(script.data) and script.data != "" do
    prefix =
      case script.script_type do
        :native -> "\x00"
        :plutus_v1 -> "\x01"
        :plutus_v2 -> "\x02"
        :plutus_v3 -> "\x03"
      end

    (prefix <> Sutra.Utils.safe_base16_decode(script.data))
    |> Blake2b.blake2b_224()
  end

  def hash_script(native_script) when is_native_script(native_script) do
    NativeScript.to_script(native_script)
    |> hash_script()
  end

  def apply_params(script_hex, params, _opts \\ []) do
    decoded_hex = Base.decode16!(script_hex, case: :mixed)
    Sutra.Uplc.apply_params_to_script(decoded_hex, params)
  end

  def to_script_ref(%__MODULE__{script_type: script_type} = script) do
    cbor_data = Base.decode16!(script.data, case: :mixed) |> Cbor.as_byte()

    script_index =
      case script_type do
        :plutus_v1 -> 1
        :plutus_v2 -> 2
        :plutus_v3 -> 3
      end

    script_value = [script_index, cbor_data] |> CBOR.encode() |> Base.encode16() |> Cbor.as_byte()

    %CBOR.Tag{tag: 24, value: script_value}
  end

  def to_script_ref(script) when is_native_script(script) do
    script_value =
      [0, NativeScript.to_witness_set(script)]
      |> CBOR.encode()
      |> Base.encode16()
      |> Cbor.as_byte()

    %CBOR.Tag{tag: 24, value: script_value}
  end

  def from_script_ref(cbor_hex) do
    {:ok, cbor_val, _} =
      cbor_hex
      |> Cbor.extract_value!()
      |> Cbor.extract_value!()
      |> then(fn v -> Utils.ok_or(Base.decode16(v, case: :mixed), v) end)
      |> CBOR.decode()

    case cbor_val do
      [0, val] -> NativeScript.from_witness_set(Cbor.extract_value!(val))
      [1, val] -> %__MODULE__{data: Cbor.extract_value!(val), script_type: :plutus_v1}
      [2, val] -> %__MODULE__{data: Cbor.extract_value!(val), script_type: :plutus_v2}
      [3, val] -> %__MODULE__{data: Cbor.extract_value!(val), script_type: :plutus_v3}
    end
  end

  def new(script_hex, language) do
    %__MODULE__{data: script_hex, script_type: language}
  end
end
