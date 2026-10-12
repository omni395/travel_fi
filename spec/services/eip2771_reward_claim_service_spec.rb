# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eip2771RewardClaimService do
  describe ".forward_request_digest" do
    it "matches EIP-712 signing and recovery for a typed forward request" do
      private_key = "0000000000000000000000000000000000000000000000000000000000000001"
      address = Crypto::Ethereum.address_from_private_key(private_key)
      request = {
        "from" => address,
        "to" => "0x0000000000000000000000000000000000000002",
        "value" => "0",
        "gas" => "350000",
        "nonce" => "3",
        "deadline" => "1900000000",
        "data" => "0x12345678"
      }

      digest = described_class.forward_request_digest(
        request:,
        token_address: "0x0000000000000000000000000000000000000003",
        chain_id: 1
      )
      signature = Crypto::Ethereum.sign_digest(private_key_hex: private_key, digest_hex: digest)

      expect(
        Crypto::Ethereum.recover_digest_signer(digest_hex: digest, signature:)
      ).to eq(address)
    end
  end

  describe ".build_forward_request_typed_data" do
    it "contains exactly the values covered by the forward-request signature" do
      request = {
        "from" => "0x0000000000000000000000000000000000000001",
        "to" => "0x0000000000000000000000000000000000000002",
        "value" => "0",
        "gas" => "350000",
        "nonce" => "3",
        "deadline" => "1900000000",
        "data" => "0x12345678",
        "chain_id" => "1",
        "forwarder" => "0x0000000000000000000000000000000000000003"
      }

      typed_data = described_class.build_forward_request_typed_data(
        request:,
        chain_id: 1,
        token_address: request.fetch("forwarder")
      )

      expect(typed_data.fetch(:primaryType)).to eq("ForwardRequest")
      expect(typed_data.dig(:types, :ForwardRequest).find { |field| field[:name] == "deadline" }[:type]).to eq("uint48")
      expect(typed_data.fetch(:message)).to eq(request.slice("from", "to", "value", "gas", "nonce", "deadline", "data"))
    end
  end

  describe ".encode_forwarder_execute_data" do
    it "encodes the OpenZeppelin v5 execute tuple and forwarder request shape" do
      request = {
        "from" => "0x0000000000000000000000000000000000000001",
        "to" => "0x0000000000000000000000000000000000000002",
        "value" => "0",
        "gas" => "350000",
        "nonce" => "3",
        "deadline" => "1900000000",
        "data" => "0x12345678"
      }

      data = Crypto::Ethereum.encode_forwarder_execute_data(
        request:,
        signature: "0x#{'ab' * 65}"
      )

      expect(data[0, 10]).to eq(
        "0x#{Crypto::Ethereum.function_selector('execute((address,address,uint256,uint256,uint48,bytes,bytes))')}"
      )

      encoded = data.delete_prefix("0x")[8..]
      expect(encoded[0, 64].to_i(16)).to eq(32)
      tuple = encoded[64..]
      head = tuple.scan(/.{64}/).first(7)
      expect(head).to eq([
        Crypto::Ethereum.encode_address(request.fetch("from")),
        Crypto::Ethereum.encode_address(request.fetch("to")),
        Crypto::Ethereum.encode_uint256(request.fetch("value")),
        Crypto::Ethereum.encode_uint256(request.fetch("gas")),
        Crypto::Ethereum.encode_uint256(request.fetch("deadline")),
        Crypto::Ethereum.encode_uint256(224),
        Crypto::Ethereum.encode_uint256(288)
      ])

      request_tail = tuple[224 * 2..]
      expect(request_tail[0, 64].to_i(16)).to eq(4)
      expect(request_tail[64, 64]).to eq("12345678".ljust(64, "0"))

      signature_tail = tuple[288 * 2..]
      expect(signature_tail[0, 64].to_i(16)).to eq(65)
      expect(signature_tail[64, 130]).to eq("ab" * 65)
      expect(signature_tail[194, 62]).to eq("0" * 62)
    end
  end

  describe ".valid_request_state?" do
    it "rejects missing or malformed request state" do
      user = double(id: 1)

      expect(described_class.valid_request_state?(user:, state: nil)).to be(false)
      expect(described_class.valid_request_state?(user:, state: { "user_id" => "1", "request" => nil })).to be(false)
    end
  end

  describe ".simulate_forwarded_call!" do
    it "simulates the call from the trusted forwarder with the original sender appended" do
      expect(TokenTransactionService).to receive(:rpc_call).with(
        "eth_call",
        [
          {
            from: "0x0000000000000000000000000000000000000003",
            to: "0x0000000000000000000000000000000000000002",
            data: "0x123456780000000000000000000000000000000000000001"
          },
          "latest"
        ]
      ).and_return("0x")

      described_class.simulate_forwarded_call!(
        target: "0x0000000000000000000000000000000000000002",
        forwarder: "0x0000000000000000000000000000000000000003",
        sender: "0x0000000000000000000000000000000000000001",
        data: "0x12345678"
      )
    end

    it "reports RPC reverts as invalid forwarded requests" do
      allow(TokenTransactionService).to receive(:rpc_call).and_raise(RuntimeError, "execution reverted")

      expect do
        described_class.simulate_forwarded_call!(
          target: "0x0000000000000000000000000000000000000002",
          forwarder: "0x0000000000000000000000000000000000000003",
          sender: "0x0000000000000000000000000000000000000001",
          data: "0x12345678"
        )
      end.to raise_error(ArgumentError, "Forwarded call simulation failed: execution reverted")
    end
  end

  describe ".relay!" do
    it "revalidates the configured rewards target before submitting" do
      from = "0x0000000000000000000000000000000000000001"
      rewards = "0x0000000000000000000000000000000000000002"
      forwarder = "0x0000000000000000000000000000000000000003"
      request = {
        "from" => from,
        "to" => rewards,
        "forwarder" => forwarder,
        "chain_id" => "1",
        "deadline" => (Time.current + 60).to_i.to_s,
        "amount_wei" => "1000000000000000000"
      }
      user = double(id: 7)
      wallet = double
      wallet_scope = double
      wallets = double
      relation = double
      transaction = double(amount: BigDecimal("1"))

      allow(User).to receive(:find).with(7).and_return(user)
      allow(user).to receive(:wallets).and_return(wallets)
      allow(wallets).to receive(:external).and_return(wallet_scope)
      allow(wallet_scope).to receive(:find_by).with(address: from, chain_id: "1").and_return(wallet)
      allow(user).to receive(:token_transactions).and_return(relation)
      allow(relation).to receive(:where).with(id: [ 9 ], claimed: false, status: %w[pending failed]).and_return(relation)
      allow(relation).to receive(:available).and_return(relation)
      allow(relation).to receive(:order).with(:id).and_return([ transaction ])
      allow(transaction).to receive(:update!)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("REWARDS_CONTRACT_ADDRESS").and_return(rewards)
      allow(ENV).to receive(:[]).with("FORWARDER_CONTRACT_ADDRESS").and_return(forwarder)
      allow(described_class).to receive(:verify_signature!)
      allow(TokenTransactionService).to receive(:submit_forwarder_transaction!).and_return("0xtx")
      expect(described_class).to receive(:ensure_forwarder_target!).with(forwarder:, target: rewards)
      expect(transaction).to receive(:update!).with(
        wallet: wallet,
        tx_hash: "0xtx",
        status: :confirmed,
        claimed: true
      )

      expect(
        described_class.relay!(
          user_id: 7,
          transaction_ids: [ 9 ],
          request: request,
          signature: "0xsignature"
        )
      ).to eq("0xtx")
    end
  end
end
