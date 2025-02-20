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

  alias Sutra.Blake2b

  alias __MODULE__.NativeScript.{
    ScriptAll,
    ScriptNOfK,
    ScriptAny,
    ScriptPubkey,
    ScriptInvalidHereafter,
    ScriptInvalidBefore
  }

  defguard is_native_script(a)
           when is_struct(a, ScriptAll) or is_struct(a, ScriptAny) or is_struct(a, ScriptNOfK) or
                  is_struct(a, ScriptPubkey) or is_struct(a, ScriptInvalidBefore) or
                  is_struct(a, ScriptInvalidHereafter)

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

  def apply_params(script_hex, params, _opts \\ []) do
    decoded_hex = Base.decode16!(script_hex, case: :mixed)
    Sutra.Uplc.apply_params_to_script(decoded_hex, params)
  end

  def new(script_hex, language) do
    %__MODULE__{data: script_hex, script_type: language}
  end
end
