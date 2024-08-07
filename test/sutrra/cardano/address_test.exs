defmodule Sutra.Cardano.AddressTest do
  @moduledoc false
  use ExUnit.Case
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Address.Credential

  @addr_mainnet_0 "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3n0d3vllmyqwsx5wktcd8cc3sq835lu7drv2xwl2wywfgse35a3x"
  @addr_mainnet_1 "addr1z8phkx6acpnf78fuvxn0mkew3l0fd058hzquvz7w36x4gten0d3vllmyqwsx5wktcd8cc3sq835lu7drv2xwl2wywfgs9yc0hh"
  @addr_mainnet_2 "addr1yx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzerkr0vd4msrxnuwnccdxlhdjar77j6lg0wypcc9uar5d2shs2z78ve"
  @addr_mainnet_3 "addr1x8phkx6acpnf78fuvxn0mkew3l0fd058hzquvz7w36x4gt7r0vd4msrxnuwnccdxlhdjar77j6lg0wypcc9uar5d2shskhj42g"
  @addr_mainnet_4 "addr1gx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer5pnz75xxcrzqf96k"
  @addr_mainnet_5 "addr128phkx6acpnf78fuvxn0mkew3l0fd058hzquvz7w36x4gtupnz75xxcrtw79hu"
  @addr_mainnet_6 "addr1vx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzers66hrl8"
  @addr_mainnet_7 "addr1w8phkx6acpnf78fuvxn0mkew3l0fd058hzquvz7w36x4gtcyjy7wx"
  @addr_mainnet_14 "stake1uyehkck0lajq8gr28t9uxnuvgcqrc6070x3k9r8048z8y5gh6ffgw"
  @addr_mainnet_15 "stake178phkx6acpnf78fuvxn0mkew3l0fd058hzquvz7w36x4gtcccycj5"

  describe "Bech32 Decode" do
    test "mainnet type0 address" do
      assert Address.from_bech32(@addr_mainnet_0) == %Address{
               network: :mainnet,
               address_type: :shelley,
               payment_credential: %Credential{
                 credential_type: :vkey,
                 hash: "9493315cd92eb5d8c4304e67b7e16ae36d61d34502694657811a2c8e"
               },
               stake_credential: %Credential{
                 credential_type: :vkey,
                 hash: "337b62cfff6403a06a3acbc34f8c46003c69fe79a3628cefa9c47251"
               }
             }
    end

    test "mainnet type1 address" do
      assert Address.from_bech32(@addr_mainnet_1) == %Address{
               network: :mainnet,
               address_type: :shelley,
               payment_credential: %Credential{
                 credential_type: :script,
                 hash: "c37b1b5dc0669f1d3c61a6fddb2e8fde96be87b881c60bce8e8d542f"
               },
               stake_credential: %Credential{
                 credential_type: :vkey,
                 hash: "337b62cfff6403a06a3acbc34f8c46003c69fe79a3628cefa9c47251"
               }
             }
    end

    test "mainnet type2 address" do
      assert Address.from_bech32(@addr_mainnet_2) == %Address{
               network: :mainnet,
               address_type: :shelley,
               payment_credential: %Credential{
                 credential_type: :vkey,
                 hash: "9493315cd92eb5d8c4304e67b7e16ae36d61d34502694657811a2c8e"
               },
               stake_credential: %Credential{
                 credential_type: :script,
                 hash: "c37b1b5dc0669f1d3c61a6fddb2e8fde96be87b881c60bce8e8d542f"
               }
             }
    end

    test "mainnet type3 address" do
      assert Address.from_bech32(@addr_mainnet_3) == %Address{
               network: :mainnet,
               address_type: :shelley,
               payment_credential: %Credential{
                 credential_type: :script,
                 hash: "c37b1b5dc0669f1d3c61a6fddb2e8fde96be87b881c60bce8e8d542f"
               },
               stake_credential: %Credential{
                 credential_type: :script,
                 hash: "c37b1b5dc0669f1d3c61a6fddb2e8fde96be87b881c60bce8e8d542f"
               }
             }
    end

    test "mainnet type4 address" do
      assert Address.from_bech32(@addr_mainnet_4) == %Address{
               network: :mainnet,
               address_type: :shelley,
               payment_credential: %Credential{
                 credential_type: :vkey,
                 hash: "9493315cd92eb5d8c4304e67b7e16ae36d61d34502694657811a2c8e"
               },
               stake_credential: %Sutra.Cardano.Address.Pointer{
                 slot: 2_498_243,
                 tx_index: 27,
                 cert_index: 3
               }
             }
    end

    test "mainnet type5 address" do
      assert Address.from_bech32(@addr_mainnet_5) == %Address{
               network: :mainnet,
               address_type: :shelley,
               payment_credential: %Credential{
                 credential_type: :script,
                 hash: "c37b1b5dc0669f1d3c61a6fddb2e8fde96be87b881c60bce8e8d542f"
               },
               stake_credential: %Sutra.Cardano.Address.Pointer{
                 slot: 2_498_243,
                 tx_index: 27,
                 cert_index: 3
               }
             }
    end

    test "mainnet type6 address" do
      assert Address.from_bech32(@addr_mainnet_6) == %Address{
               network: :mainnet,
               address_type: :shelley,
               payment_credential: %Credential{
                 credential_type: :vkey,
                 hash: "9493315cd92eb5d8c4304e67b7e16ae36d61d34502694657811a2c8e"
               },
               stake_credential: nil
             }
    end

    test "mainnet type7 address" do
      assert Address.from_bech32(@addr_mainnet_7) == %Address{
               network: :mainnet,
               address_type: :shelley,
               payment_credential: %Credential{
                 credential_type: :script,
                 hash: "c37b1b5dc0669f1d3c61a6fddb2e8fde96be87b881c60bce8e8d542f"
               },
               stake_credential: nil
             }
    end

    test "mainnet type14 address" do
      assert Address.from_bech32(@addr_mainnet_14) == %Address{
               network: :mainnet,
               address_type: :reward,
               payment_credential: nil,
               stake_credential: %Credential{
                 hash: "337b62cfff6403a06a3acbc34f8c46003c69fe79a3628cefa9c47251",
                 credential_type: :vkey
               }
             }
    end

    test "mainnet type15 address" do
      assert Address.from_bech32(@addr_mainnet_15) == %Address{
               network: :mainnet,
               address_type: :reward,
               payment_credential: nil,
               stake_credential: %Credential{
                 hash: "c37b1b5dc0669f1d3c61a6fddb2e8fde96be87b881c60bce8e8d542f",
                 credential_type: :script
               }
             }
    end

    test "to_bech32 returns bech32 string from address" do
      assert Address.from_bech32(@addr_mainnet_0) |> Address.to_bech32() == @addr_mainnet_0
      assert Address.from_bech32(@addr_mainnet_1) |> Address.to_bech32() == @addr_mainnet_1
      assert Address.from_bech32(@addr_mainnet_2) |> Address.to_bech32() == @addr_mainnet_2
      assert Address.from_bech32(@addr_mainnet_3) |> Address.to_bech32() == @addr_mainnet_3
      assert Address.from_bech32(@addr_mainnet_4) |> Address.to_bech32() == @addr_mainnet_4
      assert Address.from_bech32(@addr_mainnet_5) |> Address.to_bech32() == @addr_mainnet_5
      assert Address.from_bech32(@addr_mainnet_6) |> Address.to_bech32() == @addr_mainnet_6
      assert Address.from_bech32(@addr_mainnet_7) |> Address.to_bech32() == @addr_mainnet_7
      assert Address.from_bech32(@addr_mainnet_14) |> Address.to_bech32() == @addr_mainnet_14
      assert Address.from_bech32(@addr_mainnet_15) |> Address.to_bech32() == @addr_mainnet_15
    end
  end

  describe "Address from plutus data" do
    @vkey_vkey "d8799fd8799f487061795f766b6579ffd8799fd8799fd8799f4a7374616b655f766b6579ffffffff"
    @vkey_pointer "d8799fd8799f487061795f766b6579ffd8799fd87a9f1a00261ec3181b03ffffff"
    @script_pointer "d8799fd87a9f4a7061795f736372697074ffd8799fd87a9f1a00261ec3181b03ffffff"
    @script_script "d8799fd87a9f4a7061795f736372697074ffd8799fd8799fd87a9f4c7374616b655f736372697074ffffffff"
    @vkey_none "d8799fd8799f44766b6579ffd87a80ff"
    @script_none "d8799fd87a9f46736372697074ffd87a80ff"

    test "from_plutus/2 decode address from plutus data" do
      assert Address.from_plutus(:mainnet, @vkey_vkey) == %Address{
               network: :mainnet,
               address_type: :shelley,
               payment_credential: %Credential{
                 credential_type: :vkey,
                 hash: "pay_vkey"
               },
               stake_credential: %Credential{
                 credential_type: :vkey,
                 hash: "stake_vkey"
               }
             }

      assert Address.from_plutus(:mainnet, @vkey_pointer) == %Address{
               network: :mainnet,
               address_type: :shelley,
               payment_credential: %Credential{
                 credential_type: :vkey,
                 hash: "pay_vkey"
               },
               stake_credential: %Sutra.Cardano.Address.Pointer{
                 slot: 2_498_243,
                 tx_index: 27,
                 cert_index: 3
               }
             }

      assert Address.from_plutus(:mainnet, @script_pointer) == %Address{
               network: :mainnet,
               address_type: :shelley,
               payment_credential: %Credential{
                 credential_type: :script,
                 hash: "pay_script"
               },
               stake_credential: %Sutra.Cardano.Address.Pointer{
                 slot: 2_498_243,
                 tx_index: 27,
                 cert_index: 3
               }
             }

      assert Address.from_plutus(:mainnet, @script_script) == %Address{
               network: :mainnet,
               address_type: :shelley,
               payment_credential: %Credential{
                 credential_type: :script,
                 hash: "pay_script"
               },
               stake_credential: %Credential{
                 credential_type: :script,
                 hash: "stake_script"
               }
             }
    end

    test "to_plutus/1 encodes address to plutus cbor" do
      assert Address.from_plutus(:mainnet, @vkey_vkey) |> Address.to_plutus() == @vkey_vkey
      assert Address.from_plutus(:mainnet, @vkey_pointer) |> Address.to_plutus() == @vkey_pointer

      assert Address.from_plutus(:mainnet, @script_pointer) |> Address.to_plutus() ==
               @script_pointer

      assert Address.from_plutus(:mainnet, @script_script) |> Address.to_plutus() ==
               @script_script

      assert Address.from_plutus(:mainnet, @vkey_none) |> Address.to_plutus() == @vkey_none
      assert Address.from_plutus(:mainnet, @script_none) |> Address.to_plutus() == @script_none
    end
  end
end
