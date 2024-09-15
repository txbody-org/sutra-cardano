defmodule Sutra.Cardano.AssetTest do
  @moduledoc false

  use ExUnit.Case

  alias Sutra.Cardano.Asset
  alias Sutra.Data

  describe "Asset Plutus encoding" do
    @asset_cbor %{
      "only_lovelace" => "A140A1401A000F4240",
      "with_token" =>
        "A340A1401A000F42404B706F6C6963792D69642D31A244746B6E31186444746B6E3218C84B706F6C6963792D69642D32A144746B6E3319012C"
    }

    test "from_plutus/1 decode asset from CBOR" do
      assert {:ok, %{"lovelace" => 1_000_000}} == Asset.from_plutus(@asset_cbor["only_lovelace"])

      assert {:ok,
              %{
                "lovelace" => 1_000_000,
                "policy-id-1" => %{"tkn1" => 100, "tkn2" => 200},
                "policy-id-2" => %{"tkn3" => 300}
              }} = Asset.from_plutus(@asset_cbor["with_token"])
    end

    test "to_plutus/1 encode asset to CBOR" do
      assert @asset_cbor["only_lovelace"] ==
               Asset.to_plutus(%{"lovelace" => 1_000_000}) |> Data.encode()

      assert @asset_cbor["with_token"] ==
               Asset.to_plutus(%{
                 "lovelace" => 1_000_000,
                 "policy-id-1" => %{"tkn1" => 100, "tkn2" => 200},
                 "policy-id-2" => %{"tkn3" => 300}
               })
               |> Data.encode()
    end
  end
end
