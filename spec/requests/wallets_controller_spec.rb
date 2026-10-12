# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletsController, type: :request do
  let(:user) { create(:user) }
  let(:address) { "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf" }

  before { sign_in user }

  describe "POST /wallet/challenge" do
    it "returns a short-lived message bound to the address and configured chain" do
      post wallet_challenge_path, params: { address: address }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["message"]).to include("Chain ID:")
      expect(response.parsed_body["message"]).to include("Nonce:")
      expect(response.parsed_body["chain_id"]).to be_present
    end

    it "rejects malformed wallet addresses" do
      post wallet_challenge_path, params: { address: "not-an-address" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /wallet/connect" do
    it "saves an external wallet only after its challenge signature verifies" do
      post wallet_challenge_path, params: { address: address }, as: :json
      allow(Crypto::Ethereum).to receive(:recover_personal_signer).and_return(address)

      post wallet_connect_path, params: { address: address, signature: "0xsignature" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(user.wallets.external.pluck(:address)).to eq([ address ])
      expect(user.wallet).to be_nil
    end

    it "rejects a signature recovered to a different address" do
      post wallet_challenge_path, params: { address: address }, as: :json
      allow(Crypto::Ethereum).to receive(:recover_personal_signer).and_return("0x0000000000000000000000000000000000000001")

      post wallet_connect_path, params: { address: address, signature: "0xsignature" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.wallets.external).to be_empty
    end

    it "rejects a replay after consuming the challenge" do
      post wallet_challenge_path, params: { address: address }, as: :json
      allow(Crypto::Ethereum).to receive(:recover_personal_signer).and_return(address)

      2.times do
        post wallet_connect_path, params: { address: address, signature: "0xsignature" }, as: :json
      end

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /wallet/disconnect" do
    it "removes only the external wallet and preserves the custodial wallet" do
      custodial = WalletService.create_hidden_wallet(user: user)
      user.wallets.create!(
        address: "0x0000000000000000000000000000000000000001",
        chain_id: custodial.chain_id,
        kind: :external
      )

      delete wallet_disconnect_path, as: :json

      expect(response).to have_http_status(:ok)
      expect(user.wallets.custodial).to contain_exactly(custodial)
      expect(user.wallets.external).to be_empty
    end
  end
end
