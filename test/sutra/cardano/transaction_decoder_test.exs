defmodule Sutra.Cardano.TransactionDecoderTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Sutra.Cardano.Transaction
  alias Sutra.Test.Fixture.TransactionCertificateFixture

  describe "Certificate Related transaction" do
    test "certificate from multiple certificate related transaction" do
      cert_cbor_info = TransactionCertificateFixture.get_certificate_cbors()

      Enum.map(Map.keys(cert_cbor_info), fn k ->
        assert %Transaction{} = tx = Transaction.from_hex(cert_cbor_info[k]["cbor"])

        assert tx.tx_body ==
                 apply(TransactionCertificateFixture, String.to_atom("body_" <> k), [])

        assert tx.witnesses ==
                 apply(TransactionCertificateFixture, String.to_atom("witness_" <> k), [])

        assert tx.metadata == nil
        assert tx.is_valid
      end)
    end
  end
end
