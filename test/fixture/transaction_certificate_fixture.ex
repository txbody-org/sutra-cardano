defmodule Sutra.Test.Fixture.TransactionCertificateFixture do
  @moduledoc """
    This modules procides helper function and setup transactions for testing
  """

  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.Certificate
  alias Sutra.Cardano.Transaction.TxBody
  alias Sutra.Cardano.Transaction.Witness

  def get_certificate_cbors,
    do: File.read!("test/fixture/transaction_certificate_cbor.json") |> :elixir_json.decode()

  # for TxId: 302da83fb39d6e900f31ecc6b53b2e02e87ea990836fd9dcd5186c93ac42d221  (preprod)
  def body_302dd221 do
    %TxBody{
      auxiliary_data_hash: nil,
      certificates: [
        %Certificate.PoolRegistration{
          cost: %{"lovelace" => 170_000_000},
          margin: 0.05,
          margin_ratio: {1, 20},
          metadata: %{
            hash: "7DE1A14FD91A5C307C9816FDBC970BDD724C62C7EA1EB2BA97AC89EE0FB9FB7A",
            url: "https://upstream.org.uk/assets/preprod/metadata.json"
          },
          owners: ["EC65E4249708B5DAFD1E91D23F2D2D38C460E4D206F78FA18760EFC7"],
          pledge: %{"lovelace" => 5_000_000_000},
          pool_key_hash: "202D6DF929B8A626BC39DE9E96EF5BFC8122A70265BFC85469CE31DA",
          relays: [
            %Sutra.Cardano.Common.PoolRelay.SingleHostName{
              dns_name: "8.tcp.eu.ngrok.io",
              port: 28_965
            }
          ],
          reward_account: "E0EC65E4249708B5DAFD1E91D23F2D2D38C460E4D206F78FA18760EFC7",
          vrf_key_hash: "33C789BD8A61318481C9869EC4D45D2BFB649D0BC8D175F66A6587CF3EDC27DC"
        },
        %Certificate.StakeDelegation{
          pool_keyhash: "202D6DF929B8A626BC39DE9E96EF5BFC8122A70265BFC85469CE31DA",
          stake_credential: %Sutra.Cardano.Address.Credential{
            credential_type: :vkey,
            hash: "EC65E4249708B5DAFD1E91D23F2D2D38C460E4D206F78FA18760EFC7"
          }
        }
      ],
      fee: %{"lovelace" => 189_173},
      inputs: [
        %Transaction.OutputReference{
          output_index: 0,
          transaction_id: "55E2606FD2FAA05415C721A846767FA1B37FCB477800851F5C2AFCA234604470"
        }
      ],
      mint: nil,
      outputs: [
        %Transaction.Output{
          address: %Sutra.Cardano.Address{
            address_type: :shelley,
            network: :testnet,
            payment_credential: %Sutra.Cardano.Address.Credential{
              credential_type: :vkey,
              hash: "963dcde8e7ef8cee6beb0115f416da97afccb0c698563e0733a1998f"
            },
            stake_credential: %Sutra.Cardano.Address.Credential{
              credential_type: :vkey,
              hash: "ec65e4249708b5dafd1e91d23f2d2d38c460e4d206f78fa18760efc7"
            }
          },
          datum: %Transaction.Datum{kind: :no_datum, value: nil},
          reference_script: nil,
          value: %{"lovelace" => 9_497_638_770}
        }
      ],
      ttl: 75_103_845
    }
  end

  def witness_302dd221 do
    %Witness{
      vkey_witness: [
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "97FB7923ADD275ED49918FBFE1CA0AF09C1A24C5E03BEF52AFE6E913A4C9A8C04ED9D1C86FD76CBF4584E1C8264A078679F3922DB473F8F3AB04328B69F9B109"
            ),
          vkey: Base.decode16!("3C6446C438CF23330B04E634823AEF0272C4D1DC03FE20B6A3F12E52793A923B")
        },
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "4DA23FA90AFA4BC5982D678FB21AFA21D2B720C6C16C02A15F6E688F6B4FCD86CD852D520A57A0C6BF20B73A0062A45E9453F6DB78C2E56DCD628F144B4A8107"
            ),
          vkey: Base.decode16!("B449D53FAF0CFAE07D09C70F039B5210E33F28241FFD7578814FE172D062436F")
        },
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "202D3FAD06B7E28CBF5F3F9EA715E1573B5DFC40F6EED1E33C82628427B78AC04948557B26E303C6BDBE532B765F1FBE0E110088F2311E2EB37F89FB2C89F708"
            ),
          vkey: Base.decode16!("3AD18C8F50DB6C2E7C507D56843B3264F13AFD2BFF320835A37FC3A14D5B862A")
        }
      ],
      script_witness: [],
      redeemer: [],
      plutus_data: []
    }
  end

  # For TxId: 1e381d8513d1ca7bd54cc30d61a4ad92e2293cad9818a982454318adbf56fd07 (preprod)

  def body_1e38fd07 do
    %TxBody{
      auxiliary_data_hash: nil,
      certificates: [
        %Certificate.PoolRetirement{
          epoch_no: 177,
          pool_keyhash:
            <<28, 12, 117, 132, 179, 88, 88, 32, 120, 101, 50, 246, 45, 179, 193, 139, 50, 75,
              133, 14, 82, 223, 173, 142, 226, 255, 254, 234>>
        }
      ],
      collateral_return: nil,
      current_treasury_value: nil,
      fee: %{"lovelace" => 171_837},
      inputs: [
        %Transaction.OutputReference{
          output_index: 0,
          transaction_id: "0AC7C67527386E1E4E939497C92D442F6B0D9A46BB18C545F8FD1601AA625A24"
        }
      ],
      mint: nil,
      outputs: [
        %Transaction.Output{
          reference_script: nil,
          datum: %Transaction.Datum{kind: :no_datum, value: nil},
          value: %{"lovelace" => 6_995_916_884},
          address: %Sutra.Cardano.Address{
            stake_credential: %Sutra.Cardano.Address.Credential{
              hash: "1aabc2a4375103d4bc744c34d7139e33298ffdfaa9866badc6f668e1",
              credential_type: :vkey
            },
            payment_credential: %Sutra.Cardano.Address.Credential{
              hash: "0e1eb0eca9e4cc903e52296ae9ca9c27fd1d0519ed12ce4e44533dd3",
              credential_type: :vkey
            },
            address_type: :shelley,
            network: :testnet
          }
        }
      ],
      ttl: 74_828_452
    }
  end

  def witness_1e38fd07 do
    %Witness{
      vkey_witness: [
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "6D4AC1D9849F3B9313573848CC5A2202B25BF6EE6F1007F80F8180D8B30A2361A1422CC8A165DAE6E49C95E7140F2137D4CF5C64CA0DD1271AF1386CA5E9F200"
            ),
          vkey: Base.decode16!("B9100AD0EDE783B907503DF21B8BBCD12705923918BE23F978872081DEAA76B6")
        },
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "CB7A0C3BB4D5DD13A14CBD05360649B1384C034CECC9D642C8680FE9634371EAEA297380CDF8383BA4FFDF647058357BEC2F0E0FEA426A3BC4D176FD8302B402"
            ),
          vkey: Base.decode16!("E821DCD93CBCF42DC1742AAEDBE0678ED35F58AA7DCF6CF81D6F51AD0369C6F2")
        }
      ],
      script_witness: [],
      redeemer: [],
      plutus_data: []
    }
  end

  # For TxId: b67026a02bb1235e466fe56d64c0cd7155abccc2b0f3c646e8cc6bd4a0cf3275 (preprod)
  def body_b6703275 do
    %Transaction.TxBody{
      certificates: [
        %Certificate.StakeRegistration{
          stake_credential: %Sutra.Cardano.Address.Credential{
            hash: "6DE8BE2814A24B0F2BD8918FAF3D07685078B94E14303D5333FF4CB1",
            credential_type: :vkey
          }
        },
        %Certificate.StakeDelegation{
          pool_keyhash: "9ED23A4A839826D08D7D10F277A91F0E2373EA90251FB33664D52C94",
          stake_credential: %Sutra.Cardano.Address.Credential{
            hash: "6DE8BE2814A24B0F2BD8918FAF3D07685078B94E14303D5333FF4CB1",
            credential_type: :vkey
          }
        }
      ],
      ttl: 75_697_799,
      fee: %{"lovelace" => 174_477},
      outputs: [
        %Transaction.Output{
          reference_script: nil,
          datum: %Transaction.Datum{kind: :no_datum, value: nil},
          value: %{"lovelace" => 8_876_150_847},
          address: %Sutra.Cardano.Address{
            stake_credential: %Sutra.Cardano.Address.Credential{
              hash: "6de8be2814a24b0f2bd8918faf3d07685078b94e14303d5333ff4cb1",
              credential_type: :vkey
            },
            payment_credential: %Sutra.Cardano.Address.Credential{
              hash: "7eb505be585918dea709480a7b3ff664c72b77f28e8337e7c92d71e1",
              credential_type: :vkey
            },
            address_type: :shelley,
            network: :testnet
          }
        }
      ],
      inputs: [
        %Transaction.OutputReference{
          output_index: 1,
          transaction_id: "B929989211AF8CA57E2EFB4C178EA50978D25B2A15E35BA2EF30D69022C1924E"
        }
      ]
    }
  end

  def witness_b6703275 do
    %Witness{
      vkey_witness: [
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "164A8E2AA8F364BB17FBC7E4825FF9C9AE351E448BEC479820ABC085A29DBA06D5ACF958C8005E3FC19DC7A916256F8809E613798457EEF5F3BE53194829DA04"
            ),
          vkey: Base.decode16!("FF05F056CC742EFFF9C1E7A8E243BBED8B31B34693DC29BE6D65BD84DBB826AA")
        },
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "9D4B72D9C6F19696EA73279D7A2E444317B1DA3290604A9CF58FD09E5131AFC747A920F54D5B25CBEC148AE776B23C8306607187EB2034605DD68882F1515605"
            ),
          vkey: Base.decode16!("9D978D3748642E3A3FDA302C8A075BA008374E527E37CD029B50E1E131A6CC76")
        }
      ],
      script_witness: [],
      redeemer: [],
      plutus_data: []
    }
  end

  # for TxId: 531f441ddaa4d6753ec1011eff5c0b060b53c2b2c51d4b2cefaad05c0ed04c12  (preprod)
  def body_531f4c12 do
    %TxBody{
      certificates: [
        %Certificate.StakeDeRegistration{
          stake_credential: %Sutra.Cardano.Address.Credential{
            hash: "BEF0E133D1C6F1E1C5401162F355E334909B022480A2C2EBC9225E58",
            credential_type: :vkey
          }
        }
      ],
      fee: %{"lovelace" => 171_661},
      inputs: [
        %Transaction.OutputReference{
          output_index: 5,
          transaction_id: "7F946BFB9BBE8135C68D1096B7A52A0F47E715916D501440E7B6DAE59D243CB8"
        }
      ],
      outputs: [
        %Transaction.Output{
          reference_script: nil,
          datum: %Transaction.Datum{kind: :no_datum, value: nil},
          value: %{"lovelace" => 13_919_017_408},
          address: %Sutra.Cardano.Address{
            stake_credential: %Sutra.Cardano.Address.Credential{
              hash: "bef0e133d1c6f1e1c5401162f355e334909b022480a2c2ebc9225e58",
              credential_type: :vkey
            },
            payment_credential: %Sutra.Cardano.Address.Credential{
              hash: "ea68ee897733ba2aa41af1a8f1b9b1838d70dfcc61763a74328e6cef",
              credential_type: :vkey
            },
            address_type: :shelley,
            network: :testnet
          }
        }
      ],
      ttl: 77_298_745
    }
  end

  def witness_531f4c12 do
    %Witness{
      vkey_witness: [
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "F9E714489D41B2391AAE15C6F8D29B2F3CC61D9E7E1297689EEE8175BFF671A0ABAA7B8C853AA20051BD9C52A6EB2A025B800E670D23F86DB0DD3229912B0609"
            ),
          vkey: Base.decode16!("953F53ADDB42A8666AFB3EF87D13F600C32B7423BBF221803766758F963E48C4")
        },
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "1D1CAD1998274A6B9778319D83E2A0C89E74F5EEF928768487FBD50FEE8615D390C0A605BE91DF9385EE502FC8161E60B8513A14C97A282295067ADB947ED20C"
            ),
          vkey: Base.decode16!("1BE03609789C47CF4A3126513D4A412908393EF7DEC51CA348DD610058D4F1C6")
        }
      ],
      script_witness: [],
      redeemer: [],
      plutus_data: []
    }
  end

  # for txId: c87744872b89df20ef5b2363aaa04eab037c144a64388408b990da06d9d86215 (preprod)

  def body_c8776215 do
    %TxBody{
      certificates: [
        %Certificate.StakeRegDelegCert{
          deposit: %{"lovelace" => 2_000_000},
          pool_keyhash: "9ED23A4A839826D08D7D10F277A91F0E2373EA90251FB33664D52C94",
          stake_credential: %Sutra.Cardano.Address.Credential{
            hash: "5064B671634D14CB8D543E71DD8EB437A47EFB47B0B22882866C420D",
            credential_type: :vkey
          }
        }
      ],
      fee: %{"lovelace" => 198_677},
      outputs: [
        %Transaction.Output{
          reference_script: nil,
          datum: %Transaction.Datum{kind: :no_datum, value: nil},
          value: %{
            "0D26F1DECEE50C24498585CB9CBA2B6AA629C83023B327BB10FB67B9" => %{
              "4D696E745769746864726177" => 43
            },
            "1C05CAED08DDD5C9F233F4CB497EEB6E5F685E8E7B842B08897D1DFE" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "22691D3D969ECF5802226290C2FB98E2BC08522D5B726C1F5F400105" => %{"54657374" => 21},
            "4613DAC79011EBFA5D5837E32B8A8DB70B57CBD7FFD89BA108AF81AB" => %{
              "4346544F4B454E" => 276
            },
            "501B8B9DCE8D7C1247A14BB69D416C621267DAA72EBD6C8194293192" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "61D96F9000BF5D325DA17258EE0693E19D441CECEE64825289EE6B7D" => %{
              "4D696E745769746864726177" => 33
            },
            "665D4DBEA856001B880D5749E94384CC486D8C4EE99540D2F65D1570" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "CAC67DD80F706E084B2AAC605288B2FF793475EA43B2313E1ED384AB" => %{
              "4275726E61626C65546F6B656E506C75747573" => 1,
              "54657374" => 42,
              "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
            },
            "EB8B660CF939281C277264389C4086E7C79BAF78E08D0C48668420AB" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "EF6ED47A6917A3CBBEB46561E8853DA969343794D66128598A34AF2C" => %{
              "4275726E61626C65546F6B656E" => 144,
              "4275726E61626C65546F6B656E32" => 414,
              "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
            },
            "F654F6A31F6C4CC2C39A169F2C022404AA9F19D43137B0448B219A3E" => %{"54657374" => 101},
            "lovelace" => 7_111_913_314
          },
          address: %Sutra.Cardano.Address{
            stake_credential: %Sutra.Cardano.Address.Credential{
              hash: "5064b671634d14cb8d543e71dd8eb437a47efb47b0b22882866c420d",
              credential_type: :vkey
            },
            payment_credential: %Sutra.Cardano.Address.Credential{
              hash: "9fc430ea1f3adc20eebb813b2649e85c934ea5bc13d7b7fbe2b24e50",
              credential_type: :vkey
            },
            address_type: :shelley,
            network: :testnet
          }
        }
      ],
      inputs: [
        %Transaction.OutputReference{
          output_index: 0,
          transaction_id: "A4B94F6A211DD03DFE43E66A798EF4268285EC707A65E645C447FD96980E0601"
        }
      ]
    }
  end

  def witness_c8776215 do
    %Witness{
      vkey_witness: [
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "F922F0603D732424D048323443B22EA1705D3E768E430F6393CFDD38424CC33F28D9C8CB9557CE047129C19B01068FF15D11A84F9855D31C98FCB902F2DA1908"
            ),
          vkey: Base.decode16!("0DD2349193F4D73BFF8ED9FEA7965E3C44BDC098F1D91D0A2C9AF8AA525DB71B")
        },
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "9D8CF0D2FF5CF81778C7A6A1994A79FFEADF8080A9DC3C4D7DFB9BA6CCF98D26BB46959E422B798FA6D70547E6E7B807C85BF1FC7C720AA58526A6E25250B704"
            ),
          vkey: Base.decode16!("0ABB7B89E091DCD3201AEA501854A4CB05290862D88B6EB30AFA6DFD23F54467")
        }
      ],
      script_witness: [],
      redeemer: [],
      plutus_data: []
    }
  end

  # for TxId: 6ed61d474544baa4c9bbee01a0b706756581319e3569445fec08a3456213cedc (Preprod)

  def body_6ed6cedc do
    %TxBody{
      certificates: [
        %Certificate.StakeVoteRegDelegCert{
          deposit: %{"lovelace" => 2_000_000},
          drep: %Certificate.Drep{drep_value: nil, drep_type: 2},
          pool_keyhash: "9ED23A4A839826D08D7D10F277A91F0E2373EA90251FB33664D52C94",
          stake_credential: %Sutra.Cardano.Address.Credential{
            hash: "5064B671634D14CB8D543E71DD8EB437A47EFB47B0B22882866C420D",
            credential_type: :vkey
          }
        }
      ],
      fee: %{"lovelace" => 198_765},
      outputs: [
        %Transaction.Output{
          reference_script: nil,
          datum: %Transaction.Datum{kind: :no_datum, value: nil},
          value: %{
            "0D26F1DECEE50C24498585CB9CBA2B6AA629C83023B327BB10FB67B9" => %{
              "4D696E745769746864726177" => 43
            },
            "1C05CAED08DDD5C9F233F4CB497EEB6E5F685E8E7B842B08897D1DFE" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "22691D3D969ECF5802226290C2FB98E2BC08522D5B726C1F5F400105" => %{"54657374" => 21},
            "4613DAC79011EBFA5D5837E32B8A8DB70B57CBD7FFD89BA108AF81AB" => %{
              "4346544F4B454E" => 276
            },
            "501B8B9DCE8D7C1247A14BB69D416C621267DAA72EBD6C8194293192" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "61D96F9000BF5D325DA17258EE0693E19D441CECEE64825289EE6B7D" => %{
              "4D696E745769746864726177" => 33
            },
            "665D4DBEA856001B880D5749E94384CC486D8C4EE99540D2F65D1570" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "CAC67DD80F706E084B2AAC605288B2FF793475EA43B2313E1ED384AB" => %{
              "4275726E61626C65546F6B656E506C75747573" => 1,
              "54657374" => 42,
              "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
            },
            "EB8B660CF939281C277264389C4086E7C79BAF78E08D0C48668420AB" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "EF6ED47A6917A3CBBEB46561E8853DA969343794D66128598A34AF2C" => %{
              "4275726E61626C65546F6B656E" => 144,
              "4275726E61626C65546F6B656E32" => 414,
              "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
            },
            "F654F6A31F6C4CC2C39A169F2C022404AA9F19D43137B0448B219A3E" => %{"54657374" => 101},
            "lovelace" => 7_110_331_950
          },
          address: %Sutra.Cardano.Address{
            stake_credential: %Sutra.Cardano.Address.Credential{
              hash: "5064b671634d14cb8d543e71dd8eb437a47efb47b0b22882866c420d",
              credential_type: :vkey
            },
            payment_credential: %Sutra.Cardano.Address.Credential{
              hash: "9fc430ea1f3adc20eebb813b2649e85c934ea5bc13d7b7fbe2b24e50",
              credential_type: :vkey
            },
            address_type: :shelley,
            network: :testnet
          }
        }
      ],
      inputs: [
        %Transaction.OutputReference{
          output_index: 0,
          transaction_id: "7604E9B3B02F1C67955CACC6049FD70F69547A09AD347C85052AEC5D7FD07195"
        }
      ]
    }
  end

  def witness_6ed6cedc do
    %Witness{
      vkey_witness: [
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "696C0E11745821034F23A6E34D7B8F80D6BC3283E2F9AD5CD71DB0DE93527B40EB1C1212A53BF288FAB8C9CFD24911BB80F4B7BEDFA4FF0985DFF3CBCED50B0A"
            ),
          vkey: Base.decode16!("0DD2349193F4D73BFF8ED9FEA7965E3C44BDC098F1D91D0A2C9AF8AA525DB71B")
        },
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "ED6A1C0018F747A0D00A383766D0AA8D0F5668A9841FFA9D6B25F2FFC7682CD0D01A7DE0EF85B87929ABF501AF4313B077A45E75D3AF6BC98E9E79989A44F40A"
            ),
          vkey: Base.decode16!("0ABB7B89E091DCD3201AEA501854A4CB05290862D88B6EB30AFA6DFD23F54467")
        }
      ],
      script_witness: [],
      redeemer: [],
      plutus_data: []
    }
  end

  # for TxId: 16bdb2bad71be8b43df33ed41d6c785fbc4722f87600fd10311956898ec94ae9 (Preprod)
  def body_16bd4ae9 do
    %Transaction.TxBody{
      certificates: [
        %Certificate.StakeVoteDelegCert{
          drep: %Certificate.Drep{drep_value: nil, drep_type: 2},
          pool_keyhash: "9ED23A4A839826D08D7D10F277A91F0E2373EA90251FB33664D52C94",
          stake_credential: %Sutra.Cardano.Address.Credential{
            hash: "5064B671634D14CB8D543E71DD8EB437A47EFB47B0B22882866C420D",
            credential_type: :vkey
          }
        }
      ],
      fee: %{"lovelace" => 198_545},
      outputs: [
        %Transaction.Output{
          reference_script: nil,
          datum: %Transaction.Datum{kind: :no_datum, value: nil},
          value: %{
            "0D26F1DECEE50C24498585CB9CBA2B6AA629C83023B327BB10FB67B9" => %{
              "4D696E745769746864726177" => 43
            },
            "1C05CAED08DDD5C9F233F4CB497EEB6E5F685E8E7B842B08897D1DFE" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "22691D3D969ECF5802226290C2FB98E2BC08522D5B726C1F5F400105" => %{"54657374" => 21},
            "4613DAC79011EBFA5D5837E32B8A8DB70B57CBD7FFD89BA108AF81AB" => %{
              "4346544F4B454E" => 276
            },
            "501B8B9DCE8D7C1247A14BB69D416C621267DAA72EBD6C8194293192" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "61D96F9000BF5D325DA17258EE0693E19D441CECEE64825289EE6B7D" => %{
              "4D696E745769746864726177" => 33
            },
            "665D4DBEA856001B880D5749E94384CC486D8C4EE99540D2F65D1570" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "CAC67DD80F706E084B2AAC605288B2FF793475EA43B2313E1ED384AB" => %{
              "4275726E61626C65546F6B656E506C75747573" => 1,
              "54657374" => 42,
              "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
            },
            "EB8B660CF939281C277264389C4086E7C79BAF78E08D0C48668420AB" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "EF6ED47A6917A3CBBEB46561E8853DA969343794D66128598A34AF2C" => %{
              "4275726E61626C65546F6B656E" => 144,
              "4275726E61626C65546F6B656E32" => 414,
              "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
            },
            "F654F6A31F6C4CC2C39A169F2C022404AA9F19D43137B0448B219A3E" => %{"54657374" => 101},
            "lovelace" => 7_112_901_903
          },
          address: %Sutra.Cardano.Address{
            stake_credential: %Sutra.Cardano.Address.Credential{
              hash: "5064b671634d14cb8d543e71dd8eb437a47efb47b0b22882866c420d",
              credential_type: :vkey
            },
            payment_credential: %Sutra.Cardano.Address.Credential{
              hash: "9fc430ea1f3adc20eebb813b2649e85c934ea5bc13d7b7fbe2b24e50",
              credential_type: :vkey
            },
            address_type: :shelley,
            network: :testnet
          }
        }
      ],
      inputs: [
        %Transaction.OutputReference{
          output_index: 0,
          transaction_id: "37E9AA9B258DEB306431E09A862F86CF3D59085EA025BF27A3064E06D0858A77"
        }
      ]
    }
  end

  def witness_16bd4ae9 do
    %Witness{
      vkey_witness: [
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "5E0D1631B7BD4E89CD658779DA8EEFAFB41FBCE6747982EE4967ACF640F4EB1407ADE34156C66577339A6B0ACB311B0B721BEE35EFF2D5D1E205264E6B341409"
            ),
          vkey: Base.decode16!("0ABB7B89E091DCD3201AEA501854A4CB05290862D88B6EB30AFA6DFD23F54467")
        },
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "63C1F5A383C99CEE6E9C175FEBD8764944633AB7C64CDE348D7BE40D2A85F7473AB24176715CFB2961BBC98C3CE954FFAAD86BB86CFA64443798712DAB9B2206"
            ),
          vkey: Base.decode16!("0DD2349193F4D73BFF8ED9FEA7965E3C44BDC098F1D91D0A2C9AF8AA525DB71B")
        }
      ],
      script_witness: [],
      redeemer: [],
      plutus_data: []
    }
  end

  # For TxId: a48080fccb70399e145c7aa556b4e8abbed9fa588ec0cde0a29f471317ac9f97 (Preprod)

  def body_a4809f97 do
    %TxBody{
      certificates: [
        %Certificate.VoteRegDelegCert{
          deposit: %{"lovelace" => 2_000_000},
          drep: %Certificate.Drep{drep_value: nil, drep_type: 2},
          stake_credential: %Sutra.Cardano.Address.Credential{
            hash: "5064B671634D14CB8D543E71DD8EB437A47EFB47B0B22882866C420D",
            credential_type: :vkey
          }
        }
      ],
      fee: %{"lovelace" => 197_445},
      outputs: [
        %Transaction.Output{
          reference_script: nil,
          datum: %Transaction.Datum{kind: :no_datum, value: nil},
          value: %{
            "0D26F1DECEE50C24498585CB9CBA2B6AA629C83023B327BB10FB67B9" => %{
              "4D696E745769746864726177" => 43
            },
            "1C05CAED08DDD5C9F233F4CB497EEB6E5F685E8E7B842B08897D1DFE" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "22691D3D969ECF5802226290C2FB98E2BC08522D5B726C1F5F400105" => %{"54657374" => 21},
            "4613DAC79011EBFA5D5837E32B8A8DB70B57CBD7FFD89BA108AF81AB" => %{
              "4346544F4B454E" => 276
            },
            "501B8B9DCE8D7C1247A14BB69D416C621267DAA72EBD6C8194293192" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "61D96F9000BF5D325DA17258EE0693E19D441CECEE64825289EE6B7D" => %{
              "4D696E745769746864726177" => 33
            },
            "665D4DBEA856001B880D5749E94384CC486D8C4EE99540D2F65D1570" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "CAC67DD80F706E084B2AAC605288B2FF793475EA43B2313E1ED384AB" => %{
              "4275726E61626C65546F6B656E506C75747573" => 1,
              "54657374" => 42,
              "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
            },
            "EB8B660CF939281C277264389C4086E7C79BAF78E08D0C48668420AB" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "EF6ED47A6917A3CBBEB46561E8853DA969343794D66128598A34AF2C" => %{
              "4275726E61626C65546F6B656E" => 144,
              "4275726E61626C65546F6B656E32" => 414,
              "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
            },
            "F654F6A31F6C4CC2C39A169F2C022404AA9F19D43137B0448B219A3E" => %{"54657374" => 101},
            "lovelace" => 7_110_728_072
          },
          address: %Sutra.Cardano.Address{
            stake_credential: %Sutra.Cardano.Address.Credential{
              hash: "5064b671634d14cb8d543e71dd8eb437a47efb47b0b22882866c420d",
              credential_type: :vkey
            },
            payment_credential: %Sutra.Cardano.Address.Credential{
              hash: "9fc430ea1f3adc20eebb813b2649e85c934ea5bc13d7b7fbe2b24e50",
              credential_type: :vkey
            },
            address_type: :shelley,
            network: :testnet
          }
        }
      ],
      inputs: [
        %Transaction.OutputReference{
          output_index: 0,
          transaction_id: "130663F385984456F5D3F9B1C7EDA359F942F325A30218CADEB23413DDAAF6B8"
        }
      ]
    }
  end

  def witness_a4809f97 do
    %Witness{
      vkey_witness: [
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "26446AAEB605A8188637F29E8AEEEC1A391570A603E3CFAAD3BFEF1C12A0CF7D16D7C0E6B3451B0EA53B4A9F920149818CBC1276BFACB8AC0D8D3FF80EE28E0F"
            ),
          vkey: Base.decode16!("0DD2349193F4D73BFF8ED9FEA7965E3C44BDC098F1D91D0A2C9AF8AA525DB71B")
        },
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "F5230DA13CD0A6DC14E1C4A43B55A78C14FE4B2EDD4FB1179A835F91242A0760AE4EB3E9A780BC7A8600CDB1EC8CA22F5D6DA6E69FE3E6742807B06AD76BE40B"
            ),
          vkey: Base.decode16!("0ABB7B89E091DCD3201AEA501854A4CB05290862D88B6EB30AFA6DFD23F54467")
        }
      ],
      script_witness: [],
      redeemer: [],
      plutus_data: []
    }
  end

  # For TxId: 9271711c197696af2f16070071927e2e20a6354f1240b2aa39ccd2f22d8b4dd1 (Preprod)

  def body_92714dd1 do
    %TxBody{
      certificates: [
        %Certificate.VoteDelegCert{
          drep: %Certificate.Drep{drep_value: nil, drep_type: 3},
          stake_credential: %Sutra.Cardano.Address.Credential{
            hash: "1C66AFB2B2FFF29FE041F9A870EA617D926D1F6C558DA5941819FBDD",
            credential_type: :vkey
          }
        }
      ],
      ttl: nil,
      fee: %{"lovelace" => 174_169},
      outputs: [
        %Transaction.Output{
          reference_script: nil,
          datum: %Transaction.Datum{kind: :no_datum, value: nil},
          value: %{"lovelace" => 1_000_000},
          address: %Sutra.Cardano.Address{
            stake_credential: %Sutra.Cardano.Address.Credential{
              hash: "1c66afb2b2fff29fe041f9a870ea617d926d1f6c558da5941819fbdd",
              credential_type: :vkey
            },
            payment_credential: %Sutra.Cardano.Address.Credential{
              hash: "c7ae56052edfd929202f5146f0fa2d3583a79edb1485f05ff623cbe2",
              credential_type: :vkey
            },
            address_type: :shelley,
            network: :testnet
          }
        },
        %Transaction.Output{
          reference_script: nil,
          datum: %Transaction.Datum{kind: :no_datum, value: nil},
          value: %{"lovelace" => 8_657_514},
          address: %Sutra.Cardano.Address{
            stake_credential: %Sutra.Cardano.Address.Credential{
              hash: "1c66afb2b2fff29fe041f9a870ea617d926d1f6c558da5941819fbdd",
              credential_type: :vkey
            },
            payment_credential: %Sutra.Cardano.Address.Credential{
              hash: "998d4e8fe3a8b3193ce56407f0803fe0801c7e5765117548a629f660",
              credential_type: :vkey
            },
            address_type: :shelley,
            network: :testnet
          }
        }
      ],
      inputs: [
        %Transaction.OutputReference{
          output_index: 1,
          transaction_id: "FC3CB52653C3F2E0B983EBC10B7634A88816AA1EA01D68AACC40C4B08A669A84"
        }
      ]
    }
  end

  def witness_92714dd1 do
    %Witness{
      vkey_witness: [
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "941BA5FA0D71FE52E3661D02683EDC36970DFB4A06AFE46F64C4AB6F6F1EB1B718F4A897CDD945F010CE1F4A6B4EFC2F47C864AFCAE5938FC497A60A782AE002"
            ),
          vkey: Base.decode16!("1DDBC3129D9281587DC17694958D0926D8E155F51E4D9F6D3DE72A90D318B9EA")
        },
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "A32FD3828C56DFE462B94B673F07B3E2CC255C8E1C807E7980EF08EDE33FE4E5F7FDD5E3E929F372DF6C64AB6EDFE6D712E113AD9BE028AD31E9C3B07A054D00"
            ),
          vkey: Base.decode16!("3C791E6F172AC17967BA2125D05E76691684568238D703D0A2B394A7C22F155F")
        }
      ],
      script_witness: [],
      redeemer: [],
      plutus_data: []
    }
  end

  # For TxId: 0891a7e18016b08bfe1bed306c0c12bd68a2e4cc933181659ace22b331e476f3 (Preprod)
  def body_089176f3 do
    %TxBody{
      certificates: [
        %Certificate.RegDrepCert{
          anchor: nil,
          deposit: %{"lovelace" => 500_000_000},
          drep_credential: %Sutra.Cardano.Address.Credential{
            hash: "EC47423FF6F9114A36FFFCFADA2EA1956028EF9FF287CA30F4A860C7",
            credential_type: :vkey
          }
        }
      ],
      ttl: 75_684_623,
      fee: %{"lovelace" => 172_101},
      outputs: [
        %Transaction.Output{
          reference_script: nil,
          datum: %Transaction.Datum{kind: :no_datum, value: nil},
          value: %{"lovelace" => 1_428_996_056_030},
          address: %Sutra.Cardano.Address{
            stake_credential: %Sutra.Cardano.Address.Credential{
              hash: "ef0cbd5199d0e460725b3e79d371deb42110d40b778d3bf162777d4c",
              credential_type: :vkey
            },
            payment_credential: %Sutra.Cardano.Address.Credential{
              hash: "5746c1b032f826b5e5256357a713a7ca63988fe2ff862e0396993b97",
              credential_type: :vkey
            },
            address_type: :shelley,
            network: :testnet
          }
        }
      ],
      inputs: [
        %Transaction.OutputReference{
          output_index: 0,
          transaction_id: "9E8EF69967AE9FB1234D4210453DE1C8A5882952EE7FC0B90877AF1368239327"
        }
      ]
    }
  end

  def witness_089176f3 do
    %Witness{
      vkey_witness: [
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "49E521E9EC731B32EFF84FF3BC6714A3F27A485FF4EAAEF6C28F1A5949CD210E645C4BEB385362EFA45D7CFE4B8B6174A9D16AF24A7D4EE75FB464183DB6040D"
            ),
          vkey: Base.decode16!("A4DD1464F31CC3BC36F036AB554D44C0995B6D62764052370190C3A23F331A02")
        },
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "48757DB45889440F92A9EE5022B959A656783D420719D8F58D65F8065FA96FF95F79E39E24B0DEEE2AE41664CC1647F0353556F93B85297FD250F4F29C89F60A"
            ),
          vkey: Base.decode16!("9D1597E1F216A140AD40C62A1F67A25B4A9EBEF1B136D8FC2073EDCAA801D258")
        }
      ],
      script_witness: [],
      redeemer: [],
      plutus_data: []
    }
  end

  # For TxId: 4ab1cfa507e15828a4eb4ccd004635042c932b29ac97aec72ff409c50fd8f4ed  (preprod)

  def body_4ab1f4ed do
    %Transaction.TxBody{
      total_collateral: %{"lovelace" => 5_000_000},
      collateral_return: %Transaction.Output{
        reference_script: nil,
        datum: %Transaction.Datum{kind: :no_datum, value: nil},
        value: %{
          "0D26F1DECEE50C24498585CB9CBA2B6AA629C83023B327BB10FB67B9" => %{
            "4D696E745769746864726177" => 43
          },
          "1C05CAED08DDD5C9F233F4CB497EEB6E5F685E8E7B842B08897D1DFE" => %{
            "4D794D696E746564546F6B656E" => 1
          },
          "22691D3D969ECF5802226290C2FB98E2BC08522D5B726C1F5F400105" => %{"54657374" => 21},
          "4613DAC79011EBFA5D5837E32B8A8DB70B57CBD7FFD89BA108AF81AB" => %{
            "4346544F4B454E" => 276
          },
          "501B8B9DCE8D7C1247A14BB69D416C621267DAA72EBD6C8194293192" => %{
            "4D794D696E746564546F6B656E" => 1
          },
          "61D96F9000BF5D325DA17258EE0693E19D441CECEE64825289EE6B7D" => %{
            "4D696E745769746864726177" => 33
          },
          "665D4DBEA856001B880D5749E94384CC486D8C4EE99540D2F65D1570" => %{
            "4D794D696E746564546F6B656E" => 1
          },
          "CAC67DD80F706E084B2AAC605288B2FF793475EA43B2313E1ED384AB" => %{
            "4275726E61626C65546F6B656E506C75747573" => 1,
            "54657374" => 42,
            "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
          },
          "EB8B660CF939281C277264389C4086E7C79BAF78E08D0C48668420AB" => %{
            "4D794D696E746564546F6B656E" => 1
          },
          "EF6ED47A6917A3CBBEB46561E8853DA969343794D66128598A34AF2C" => %{
            "4275726E61626C65546F6B656E" => 145,
            "4275726E61626C65546F6B656E32" => 417,
            "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
          },
          "F654F6A31F6C4CC2C39A169F2C022404AA9F19D43137B0448B219A3E" => %{"54657374" => 102},
          "lovelace" => 6_664_066_838
        },
        address: %Sutra.Cardano.Address{
          stake_credential: %Sutra.Cardano.Address.Credential{
            hash: "5064b671634d14cb8d543e71dd8eb437a47efb47b0b22882866c420d",
            credential_type: :vkey
          },
          payment_credential: %Sutra.Cardano.Address.Credential{
            hash: "9fc430ea1f3adc20eebb813b2649e85c934ea5bc13d7b7fbe2b24e50",
            credential_type: :vkey
          },
          address_type: :shelley,
          network: :testnet
        }
      },
      collateral: [
        %Transaction.OutputReference{
          output_index: 0,
          transaction_id: "4EDEDD73B30FC7C7140BB79ECC072CE800617356809850968E4E5EB2699A465E"
        }
      ],
      script_data_hash: "25757B59C698464BACCF51976CDC4BCC3E53116CEF264082EC8DF08E3ED1994A",
      certificates: [
        %Certificate.UnRegDrepCert{
          deposit: %{"lovelace" => 500_000_000},
          drep_credential: %Sutra.Cardano.Address.Credential{
            hash: "99E21871B90D685CB26C4171169A54E5ED4F26F39DFC161B35FB8112",
            credential_type: :script
          }
        }
      ],
      ttl: nil,
      fee: %{"lovelace" => 230_512},
      outputs: [
        %Transaction.Output{
          reference_script: nil,
          datum: %Transaction.Datum{kind: :no_datum, value: nil},
          value: %{
            "0D26F1DECEE50C24498585CB9CBA2B6AA629C83023B327BB10FB67B9" => %{
              "4D696E745769746864726177" => 43
            },
            "1C05CAED08DDD5C9F233F4CB497EEB6E5F685E8E7B842B08897D1DFE" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "22691D3D969ECF5802226290C2FB98E2BC08522D5B726C1F5F400105" => %{"54657374" => 21},
            "4613DAC79011EBFA5D5837E32B8A8DB70B57CBD7FFD89BA108AF81AB" => %{
              "4346544F4B454E" => 276
            },
            "501B8B9DCE8D7C1247A14BB69D416C621267DAA72EBD6C8194293192" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "61D96F9000BF5D325DA17258EE0693E19D441CECEE64825289EE6B7D" => %{
              "4D696E745769746864726177" => 33
            },
            "665D4DBEA856001B880D5749E94384CC486D8C4EE99540D2F65D1570" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "CAC67DD80F706E084B2AAC605288B2FF793475EA43B2313E1ED384AB" => %{
              "4275726E61626C65546F6B656E506C75747573" => 1,
              "54657374" => 42,
              "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
            },
            "EB8B660CF939281C277264389C4086E7C79BAF78E08D0C48668420AB" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "EF6ED47A6917A3CBBEB46561E8853DA969343794D66128598A34AF2C" => %{
              "4275726E61626C65546F6B656E" => 145,
              "4275726E61626C65546F6B656E32" => 417,
              "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
            },
            "F654F6A31F6C4CC2C39A169F2C022404AA9F19D43137B0448B219A3E" => %{"54657374" => 102},
            "lovelace" => 7_168_836_326
          },
          address: %Sutra.Cardano.Address{
            stake_credential: %Sutra.Cardano.Address.Credential{
              hash: "5064b671634d14cb8d543e71dd8eb437a47efb47b0b22882866c420d",
              credential_type: :vkey
            },
            payment_credential: %Sutra.Cardano.Address.Credential{
              hash: "9fc430ea1f3adc20eebb813b2649e85c934ea5bc13d7b7fbe2b24e50",
              credential_type: :vkey
            },
            address_type: :shelley,
            network: :testnet
          }
        }
      ],
      inputs: [
        %Transaction.OutputReference{
          output_index: 0,
          transaction_id: "4EDEDD73B30FC7C7140BB79ECC072CE800617356809850968E4E5EB2699A465E"
        }
      ]
    }
  end

  def witness_4ab1f4ed do
    %Witness{
      vkey_witness: [
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "61C43126C495E653CF6CCF69EBD24487E4DDC092F7E75AD0DD187671512B0B6B632C531F83679D8EE0D5613D8305ED2FB7843A4E2BD2DC8BE0AD5745ABB6C300"
            ),
          vkey: Base.decode16!("0ABB7B89E091DCD3201AEA501854A4CB05290862D88B6EB30AFA6DFD23F54467")
        }
      ],
      script_witness: [
        %Script{
          data: [
            "584F010100323232323225333002323232323253330073370E900418041BAA0011324A2601460126EA80045289804980500118040009804001180300098021BAA00114984D9595CD2AB9D5573CAE855D11"
          ],
          script_type: :plutus_v3
        }
      ],
      redeemer: [
        %Witness.Redeemer{
          exunits: {8291, 2_214_370},
          data: %Sutra.Data.Plutus.Constr{fields: [], index: 0},
          index: 0,
          tag: :cert
        }
      ],
      plutus_data: []
    }
  end

  # For TxId: d77f6b57c2fc7b39771ad322808bf5a697ef9edac11d09062e439c6a296e127d (Preprod)

  def body_d77f127d do
    %TxBody{
      certificates: [
        %Certificate.UpdateDrepCert{
          anchor: nil,
          drep_credential: %Sutra.Cardano.Address.Credential{
            hash: "5064B671634D14CB8D543E71DD8EB437A47EFB47B0B22882866C420D",
            credential_type: :vkey
          }
        }
      ],
      fee: %{"lovelace" => 197_181},
      outputs: [
        %Transaction.Output{
          reference_script: nil,
          datum: %Transaction.Datum{kind: :no_datum, value: nil},
          value: %{
            "0D26F1DECEE50C24498585CB9CBA2B6AA629C83023B327BB10FB67B9" => %{
              "4D696E745769746864726177" => 43
            },
            "1C05CAED08DDD5C9F233F4CB497EEB6E5F685E8E7B842B08897D1DFE" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "22691D3D969ECF5802226290C2FB98E2BC08522D5B726C1F5F400105" => %{"54657374" => 21},
            "4613DAC79011EBFA5D5837E32B8A8DB70B57CBD7FFD89BA108AF81AB" => %{
              "4346544F4B454E" => 276
            },
            "501B8B9DCE8D7C1247A14BB69D416C621267DAA72EBD6C8194293192" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "61D96F9000BF5D325DA17258EE0693E19D441CECEE64825289EE6B7D" => %{
              "4D696E745769746864726177" => 33
            },
            "665D4DBEA856001B880D5749E94384CC486D8C4EE99540D2F65D1570" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "CAC67DD80F706E084B2AAC605288B2FF793475EA43B2313E1ED384AB" => %{
              "4275726E61626C65546F6B656E506C75747573" => 1,
              "54657374" => 42,
              "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
            },
            "EB8B660CF939281C277264389C4086E7C79BAF78E08D0C48668420AB" => %{
              "4D794D696E746564546F6B656E" => 1
            },
            "EF6ED47A6917A3CBBEB46561E8853DA969343794D66128598A34AF2C" => %{
              "4275726E61626C65546F6B656E" => 145,
              "4275726E61626C65546F6B656E32" => 417,
              "ACCBFB633F637E3BB1ABEE40C9539D1EFFD742CD2716B3B1DB9DE3AAF3F37794" => 1
            },
            "F654F6A31F6C4CC2C39A169F2C022404AA9F19D43137B0448B219A3E" => %{"54657374" => 102},
            "lovelace" => 6_669_494_751
          },
          address: %Sutra.Cardano.Address{
            stake_credential: %Sutra.Cardano.Address.Credential{
              hash: "5064b671634d14cb8d543e71dd8eb437a47efb47b0b22882866c420d",
              credential_type: :vkey
            },
            payment_credential: %Sutra.Cardano.Address.Credential{
              hash: "9fc430ea1f3adc20eebb813b2649e85c934ea5bc13d7b7fbe2b24e50",
              credential_type: :vkey
            },
            address_type: :shelley,
            network: :testnet
          }
        }
      ],
      inputs: [
        %Transaction.OutputReference{
          output_index: 0,
          transaction_id: "8267A54D323ED85E5271546AA85E888AE4D120D24B49A1A5DEC70F3536ACFEE7"
        }
      ]
    }
  end

  def witness_d77f127d do
    %Witness{
      vkey_witness: [
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "568B50E470F10673D76F72DCAD997EC2AC87C57A272EDC8FD3B7B0B84DD9EF8CD837A96F614B57386A77C1F9D7A1C5C03C7DB259D1C92BD2EE3F24AE48888404"
            ),
          vkey: Base.decode16!("0DD2349193F4D73BFF8ED9FEA7965E3C44BDC098F1D91D0A2C9AF8AA525DB71B")
        },
        %Witness.VkeyWitness{
          signature:
            Base.decode16!(
              "9FC9380A43C1CE583A286FF007206C9E7149D77D7C9C829AE7A0AA23A631D4B5D5566B5C9804091CD8F8293B5494769AD7EDF206C3BCF6EDA4B410BB77221602"
            ),
          vkey: Base.decode16!("0ABB7B89E091DCD3201AEA501854A4CB05290862D88B6EB30AFA6DFD23F54467")
        }
      ],
      script_witness: [],
      redeemer: [],
      plutus_data: []
    }
  end
end
