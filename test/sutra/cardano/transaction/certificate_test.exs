defmodule Sutra.Cardano.Transaction.CertificateTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Transaction.Certificate
  alias Sutra.Cardano.Transaction.Certificate.ResignCommitteeColdCert

  @cold_cred %Credential{
    credential_type: :vkey,
    hash: "5064b671634d14cb8d543e71dd8eb437a47efb47b0b22882866c420d"
  }

  @anchor %{
    url: "https://example.com/metadata.json",
    hash: "7de1a14fd91a5c307c9816fdbc970bdd724c62c7ea1eb2ba97ac89ee0fb9fb7a"
  }

  # Regression: cert 15 (committee_resignation_cert) had no decode/1 or
  # to_cbor/1 clause, so it could neither be parsed nor encoded.
  describe "ResignCommitteeColdCert (cert 15)" do
    test "encodes with tag 15" do
      cert = %ResignCommitteeColdCert{committee_cold_credential: @cold_cred, anchor: nil}
      assert [15 | _] = Certificate.to_cbor(cert)
    end

    test "round trips with nil anchor" do
      cert = %ResignCommitteeColdCert{committee_cold_credential: @cold_cred, anchor: nil}
      assert cert == cert |> Certificate.to_cbor() |> Certificate.decode()
    end

    test "round trips with an anchor" do
      cert = %ResignCommitteeColdCert{committee_cold_credential: @cold_cred, anchor: @anchor}
      assert cert == cert |> Certificate.to_cbor() |> Certificate.decode()
    end
  end
end
