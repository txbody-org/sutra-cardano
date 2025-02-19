defmodule Sutra.Cardano.Asset do
  @moduledoc """
    Cardano Asset
  """
  @type policy_id() :: String.t()
  @type asset_name() :: String.t()
  @type ada_asset_name() :: String.t()
  @type coin() :: %{ada_asset_name() => integer()}
  @type t() :: coin() | %{policy_id() => %{ada_asset_name() => integer()}}

  alias Sutra.Data
  alias Sutra.Data.Cbor

  import Sutra.Data.Cbor, only: [extract_value: 1]

  @doc """
  decode Asset from Plutus

  ## Examples

      iex> from_plutus(%{"" => %{"" => 200}, "policy-1" => %{"asset-1" => 100}})
      {:ok, %{"lovelace" => %{"" => 200}, "policy-1" => %{"asset-1" => 100}}}

      iex> from_plutus("A140A1401A000F4240")
      {:ok, %{"lovelace" => 1_000_000}}

      iex> token_cbor = "A340A1401A000F42404B706F6C6963792D69642D31A244746B6E31186444746B6E3218C84B706F6C6963792D69642D32A144746B6E3319012C"
      iex> from_plutus(token_cbor)
      {:ok,
          %{
                "lovelace" => 1_000_000,
                "706F6C6963792D69642D31" => %{"746B6E31" => 100, "746B6E32" => 200},
                "706F6C6963792D69642D32" => %{"746B6E33" => 300}
          }
      }


  """
  def from_plutus(cbor) when is_binary(cbor) do
    case Data.decode(cbor) do
      {:ok, data} -> from_plutus(data)
      {:error, _} -> {:error, :invalid_cbor}
    end
  end

  def from_plutus(plutus_data) when is_map(plutus_data) do
    result =
      Enum.reduce(plutus_data, %{}, fn {key, val}, acc ->
        key =
          case extract_value(key) do
            {:ok, ""} -> "lovelace"
            {:ok, value} -> value
          end

        Map.put(acc, key, to_asset_class(key, val))
      end)

    {:ok, result}
  end

  defp to_asset_class("lovelace", %{%CBOR.Tag{tag: :bytes, value: ""} => lovelace}),
    do: lovelace

  defp to_asset_class(_, value) when is_map(value) do
    Enum.reduce(value, %{}, fn {key, val}, acc ->
      {:ok, key} = extract_value(key)
      Map.put(acc, key, val)
    end)
  end

  @doc """
  Converts Asset to Plutus

  ## Examples

        iex> to_plutus(%{"lovelace" => 300})
        %{%CBOR.Tag{tag: :bytes, value: ""} => %{%CBOR.Tag{tag: :bytes, value: ""} => 300}}

        iex> to_plutus(%{"lovelace" => 200, "policy-1" => %{"asset-1" => 300}})
        %{
            %CBOR.Tag{tag: :bytes, value: ""} => %{
                %CBOR.Tag{tag: :bytes, value: ""} => 200
            },
            %CBOR.Tag{tag: :bytes, value: "policy-1"} => %{
                %CBOR.Tag{tag: :bytes, value: "asset-1"} => 300
            }
        }

        iex> to_plutus(%{"lovelace" => 1_000_000}) |> Cbor.encode_hex()
        "A140A1401A000F4240"

        iex(1)>  to_plutus(%{
        ...(1)>     "lovelace" => 1_000_000,
        ...(1)>     "706F6C6963792D69642D31" => %{"746B6E31" => 100, "746B6E32" => 200},
        ...(1)>     "706F6C6963792D69642D32" => %{"746B6E33" => 300}
        ...(1)>   })
        %{
          %CBOR.Tag{tag: :bytes, value: ""} =>
            %{%CBOR.Tag{tag: :bytes, value: ""} => 1000000},
          %CBOR.Tag{tag: :bytes, value: "policy-id-1"} => %{
            %CBOR.Tag{tag: :bytes, value: "tkn1"} => 100,
            %CBOR.Tag{tag: :bytes, value: "tkn2"} => 200
          },
          %CBOR.Tag{tag: :bytes, value: "policy-id-2"} => %{
            %CBOR.Tag{tag: :bytes, value: "tkn3"} => 300
          }
        }

  """

  def to_plutus(data) when is_map(data) do
    Enum.reduce(data, %{}, fn {key, val}, acc ->
      key_val =
        case key do
          "lovelace" -> ""
          _ -> key
        end

      acc
      |> Map.put(Cbor.as_byte(key_val), from_asset_class(val))
    end)
  end

  def to_plutus(_val), do: {:error, :invalid_data}

  defp from_asset_class(lovelace_value) when is_integer(lovelace_value),
    do: %{%CBOR.Tag{tag: :bytes, value: ""} => lovelace_value}

  defp from_asset_class(asset_map) when is_map(asset_map) do
    Enum.reduce(asset_map, %{}, fn {key, val}, acc ->
      Map.put(acc, Cbor.as_byte(key), val)
    end)
  end

  @doc """

  """
  def from_lovelace(value) when is_number(value), do: %{"lovelace" => value}
  def from_lovelace(_), do: nil

  @doc """
    Returns lovelace amount from asset. returns 0 if no lovelace is found in asset

      ## Examples

            iex> lovelace_of(%{"policy" => %{"asset" => 1}})
            0

            iex> lovelace_of(from_lovelace(134_000))
            134_000

  """
  def lovelace_of(asset) when is_map(asset), do: Map.get(asset, "lovelace", 0)
  def lovelace_of(_), do: 0

  @doc """
    Merge two asset values into one,


        ## Examples

              iex> asset1 = %{"lovelace" => 123}
              iex> asset2 = %{"policy-1" => %{"asset1" => 600}}
              iex> merge(asset1, asset2)
              %{"lovelace" => 123, "policy-1" => %{"asset1" => 600}}

        Adds Qty of token for similar policies

              iex> asset1 = %{"lovelace" => 100, "policy-1" => %{"asset1" => 600}}
              iex> asset2 = %{"policy-1" => %{"asset1" => 400}}
              iex> merge(asset1, asset2)
              %{"lovelace" => 100, "policy-1" => %{"asset1" => 1000}}

  """
  def merge(asset1, asset2) when is_map(asset1) and is_map(asset2) do
    Map.merge(asset1, asset2, fn _k, v1, v2 ->
      if is_number(v1), do: v1 + v2, else: merge(v1, v2)
    end)
  end

  @doc """
    Subtract value of asset

        ## Examples


            iex> asset1 = from_lovelace(500)
            iex> asset2 = from_lovelace(600)
            iex> diff(asset1, asset2)
            %{"lovelace" => 100}

            iex> asset1 = %{"policy-1" => %{"asset1" => 200}}
            iex> asset2 = %{"policy-1" => %{"asset1" => 50, "asset2" => 200 }}
            iex> diff(asset1, asset2)
            %{"policy-1" => %{"asset1" => -150, "asset2" => 200 }}

  """
  def diff(asset1, asset2) when is_map(asset1) and is_map(asset2) do
    Enum.map(asset2, fn {k, v} ->
      if is_map(v),
        do: {k, Map.get(asset1, k, %{}) |> diff(v)},
        else: {k, v - Map.get(asset1, k, 0)}
    end)
    |> Enum.into(%{})
  end

  @doc """
  checks if assets has positive amount

        ## Examples

              iex> is_positive_asset(%{"lovelace" => 100})
              true

              iex> is_positive_asset(%{"lovelace" => 50, "policy" => %{"asset" => -100}})
              true

              iex> is_positive_asset(%{"lovelace" => 0, "policy" => %{"asset" => -100}})
              false

              iex> is_positive_asset(%{"lovelace" => -10, "policy" => %{"asset" => -100}})
              false

  """
  def is_positive_asset(asset) when is_map(asset) do
    Enum.any?(asset, fn {_k, v} ->
      if is_number(v), do: v > 0, else: is_positive_asset(v)
    end)
  end

  @doc """
    Returns only Positive Assets

        ## Examples


              iex> only_positive(%{"lovelace" => 200, "policy" => %{"asset" => -10}})
              %{"lovelace" => 200}

              iex> only_positive(%{"lovelace" => 0, "policy" => %{"asset" => -10}})
              %{}

              iex> only_positive(%{"lovelace" => 0, "policy" => %{"asset" => 10}})
              %{"policy" => %{"asset" => 10}}


  """
  def only_positive(asset) when is_map(asset) do
    filter_by_value(asset, &(&1 > 0))
  end

  @doc """
  Filter Asset by applying functions against Asset value

        ## Examples

              iex> asset = %{"lovelace" => 100, "policy" => %{"asset1" => -10, "asset2" => 10}}
              iex> filter_by_value(asset, fn v -> v > 0 end)
              %{"lovelace" => 100, "policy" => %{"asset2" => 10}}


              iex> asset = %{"lovelace" => 10, "policy" => %{"asset1" => -10, "asset2" => 10}}
              iex> filter_by_value(asset, &(&1 == 10))
              %{"lovelace" => 10,"policy" => %{"asset2" => 10}}

              iex> asset = %{"lovelace" => 10, "policy" => %{"asset1" => -10, "asset2" => 10}}
              iex> filter_by_value(asset, &(&1 < 0))
              %{"policy" => %{"asset1" => -10}}

  """

  def filter_by_value(asset, func) when is_function(func, 1) and is_map(asset) do
    Enum.reduce(asset, %{}, fn {k, v}, acc ->
      if is_map(v) do
        result = filter_by_value(v, func)
        if map_size(result) > 0, do: Map.put(acc, k, result), else: acc
      else
        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        if func.(v), do: Map.put(acc, k, v), else: acc
      end
    end)
  end

  @doc """
    Returns Asset with Absolute value

        ## Examples

              iex> abs_value(%{"lovelace" => -100})
              %{"lovelace" => 100 }

              iex> abs_value(%{"lovelace" => 100})
              %{"lovelace" => 100 }

  """
  def abs_value(asset) when is_map(asset) do
    Enum.map(asset, fn {k, v} ->
      if is_map(v), do: {k, abs_value(v)}, else: {k, abs(v)}
    end)
    |> Enum.into(%{})
  end

  @doc """
    Add quantity of single token to Assets

    ## Examples

      iex> add(from_lovelace(100), "lovelace", 200)
      %{"lovelace" => 300}

      iex> add(from_lovelace(100), "policy", "asset", 10)
      %{"lovelace" => 100, "policy" => %{"asset" => 10}}

  """
  def add(asset, "lovelace", amount) when is_map(asset) and is_number(amount),
    do: Map.put(asset, "lovelace", lovelace_of(asset) + amount)

  def add(asset, policy_id, asset_name, qty)
      when is_map(asset) and is_binary(policy_id) and is_binary(asset_name) and is_number(qty) do
    merge(asset, Map.put(%{}, policy_id, Map.new([{asset_name, qty}])))
  end

  @doc """
    Empty asset
  """
  def zero, do: %{}

  @doc """
    Negates quantities of all Asset

    ## Examples

        iex> negate(from_lovelace(100))
        %{"lovelace" => -100}

        iex> negate(%{"lovelace" => 10, "policy" => %{"asset" => 70}})
        %{"lovelace" => -10, "policy" => %{"asset" => -70}}

  """
  def negate(assets) do
    Enum.map(assets, fn {k, v} ->
      if is_map(v), do: {k, negate(v)}, else: {k, -v}
    end)
    |> Enum.into(%{})
  end

  @doc """
    Returns Asset without Ada

    ## Examples

        iex> without_lovelace(%{"lovelace" => 10}) == zero()
        true

        iex> without_lovelace(%{"lovelace" => 10, "policy" => %{"asset" => 1}})
        %{"policy" => %{"asset" => 1}}

  """
  def without_lovelace(assets), do: Map.delete(assets, "lovelace")

  @doc """
    Returns all policies of asset

    ## Examples

        iex> policies(%{"lovelace" => 100})
        []

        iex> policies(%{"policy1" => %{"asset1" => 1}, "policy2" => %{"asset1" => 2}})
        ["policy1", "policy2"]
  """
  def policies(assets) when is_map(assets) do
    assets
    |> without_lovelace()
    |> Map.keys()
  end

  @doc """
    Get a subset of the assets restricted to the given policies.

    ## Examples

          iex> restricted_to(%{"lovelace" => 100, "policy1" => %{"asset1" => 10}}, ["lovelace"])
          %{"lovelace" => 100}

          iex(1)> restricted_to(%{
          ...(1)>    "lovelace" => 100,
          ...(1)>    "policy1" => %{"asset" => 10},
          ...(1)>    "policy2" => %{"asset" => 50},
          ...(1)>    "policy3" => %{"asset" => 30},
          ...(1)> }, ["policy1", "policy2"])

          %{"policy1" => %{"asset" => 10}, "policy2" => %{"asset" => 50}}

  """
  def restricted_to(assets, policy_ids) when is_map(assets) and is_list(policy_ids) do
    Enum.reduce(policy_ids, %{}, fn policy_id, acc ->
      policy_value = Map.get(assets, policy_id)
      if policy_value, do: Map.put(acc, policy_id, policy_value), else: acc
    end)
  end

  @doc """
    Checks if both asset has similar tokens

    ## Examples

        iex> asset1 = %{"lovelace" => 1000, "policy1" => %{"asset" => 1}}
        iex> contains_token?(from_lovelace(100), asset1)
        iex> true

        iex> asset1 = %{"policy1" => %{"asset" => 1}, "policy2" => %{"asset" => 1}}
        iex> asset2 = %{"policy3" => %{"asset" => 1}}
        iex> contains_token?(asset2, asset1)
        iex> false
  """
  def contains_token?(asset1, asset2) do
    asset2
    |> policies()
    |> Enum.any?(&Map.has_key?(asset1, &1))
  end

  @doc """
    Convert Asset to Cbor

        ## Examples

            iex> to_cbor(%{"lovelace" => 100})
            100

            iex> to_cbor(%{"lovelace" => 100, "policy" => %{"asset" => 100}})
            [ 100,
              %{%CBOR.Tag{tag: :bytes, value: "policy"} =>
                    %{%CBOR.Tag{tag: :bytes, value: "asset"} => 100}
              }
            ]

  """
  def to_cbor(%{"lovelace" => lovelace} = asset) when map_size(asset) == 1, do: lovelace

  def to_cbor(assets) do
    [Map.get(assets, "lovelace", 0), Map.delete(assets, "lovelace") |> to_plutus()]
  end

  @doc """
    Convert Cbor to Asset

    ## Examples

      iex(1)> cbor = [
      ...(1)>   100,
      ...(1)>   %{
      ...(1)>     %CBOR.Tag{tag: :bytes, value: "policy"} =>
      ...(1)>       %{
      ...(1)>           %CBOR.Tag{tag: :bytes, value: "asset"} => 1
      ...(1)>       }
      ...(1)>   }
      ...(1)> ]
      iex(1)> from_cbor(cbor)
      %{"lovelace" => 100, "706F6C696379" => %{"6173736574" => 1}}

      iex> from_cbor(10)
      %{"lovelace" => 10}
  """
  def from_cbor(lovelace) when is_integer(lovelace), do: from_lovelace(lovelace)

  def from_cbor([lovelace, other_assets]) do
    with {:ok, assets} <- from_plutus(other_assets) do
      Map.put(assets, "lovelace", lovelace)
    end
  end
end
