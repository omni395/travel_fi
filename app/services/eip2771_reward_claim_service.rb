# frozen_string_literal: true

class Eip2771RewardClaimService
  class RequestExpired < StandardError; end

  FORWARDER_DOMAIN_NAME = "TravelFiTokenForwarder"
  REWARDS_DOMAIN_NAME = "TravelFiRewards"
  EIP712_DOMAIN_TYPE = "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
  FORWARD_REQUEST_TYPE = "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)"
  REWARD_CLAIM_TYPE = "RewardClaim(address user,uint256 amount,uint256 nonce,uint256 deadline)"
  FORWARD_GAS_LIMIT = 350_000
  CASHIER_GAS_LIMITS = {
    "buyWithUSDT(uint256,uint256)" => 300_000,
    "sellWithUSDT(uint256,uint256,uint256,uint8,bytes32,bytes32)" => 400_000,
    "sellWithETH(uint256,uint256,uint256,uint8,bytes32,bytes32)" => 400_000
  }.freeze
  REQUEST_TTL = 10.minutes

  def self.prepare!(user:, transactions:)
    new(user:, transactions:).prepare!
  end

  #
  # Prepares a claim request for all currently available transactions of a user.
  #
  # @param user [User] reward recipient
  # @return [Hash] EIP-712 payload and session state
  #
  def self.prepare_for_user!(user:)
    transactions = user.token_transactions.unclaimed.available
      .where(status: %w[pending failed])
      .order(:id)
      .to_a
    raise ArgumentError, "No available rewards" if transactions.empty?

    prepare!(user:, transactions:)
  end

  #
  # Verifies and enqueues a signed claim request.
  #
  # @param user [User] authenticated claimant
  # @param state [Hash] session state created by prepare_for_user!
  # @param signature [String] wallet signature
  # @return [void]
  #
  def self.enqueue_claim!(user:, state:, signature:)
    raise RequestExpired unless valid_request_state?(user:, state:)
    request = state.fetch("request")

    verify_signature!(
      request:,
      signature:,
      token_address: request.fetch("forwarder"),
      chain_id: request.fetch("chain_id").to_i
    )
    Eip2771RewardClaimJob.perform_later(
      user.id,
      state.fetch("transaction_ids"),
      request,
      signature
    )
  end

  #
  # Verifies and enqueues a signed cashier request.
  #
  # @param user [User] authenticated wallet owner
  # @param state [Hash] session state created by prepare_cashier_request!
  # @param signature [String] wallet signature
  # @return [void]
  #
  def self.enqueue_cashier!(user:, state:, signature:)
    raise RequestExpired unless valid_request_state?(user:, state:)
    request = state.fetch("request")

    verify_signature!(
      request:,
      signature:,
      token_address: request.fetch("forwarder"),
      chain_id: request.fetch("chain_id").to_i
    )
    Eip2771CashierJob.perform_later(user.id, request, signature)
  end

  def self.simulate_forwarded_call!(target:, forwarder:, sender:, data:)
    forwarded_data = "#{data}#{sender.delete_prefix('0x').downcase}"
    TokenTransactionService.rpc_call(
      "eth_call",
      [ { from: forwarder, to: target, data: forwarded_data }, "latest" ]
    )
  rescue RuntimeError => e
    raise ArgumentError, "Forwarded call simulation failed: #{e.message}"
  end

  def self.ensure_forwarder_target!(forwarder:, target:)
    target_call = "0x#{Crypto::Ethereum.function_selector('isTrustedForwarder(address)')}#{Crypto::Ethereum.encode_address(forwarder)}"
    trusted = TokenTransactionService.rpc_call("eth_call", [ { to: target, data: target_call }, "latest" ])
    raise ArgumentError, "Target does not trust the configured ERC-2771 forwarder" unless Integer(trusted, 16) == 1
  rescue RuntimeError => e
    raise ArgumentError, "Could not verify target ERC-2771 support: #{e.message}"
  end

  def self.prepare_cashier_request!(user:, data:, gas_limit:)
    service = new(user:, transactions: [])
    wallet = user.wallets.external.find_by(chain_id: service.send(:chain_id).to_s)
    raise ArgumentError, "A connected external wallet on the configured chain is required" unless wallet
    raise ArgumentError, "Invalid cashier call data" unless data.is_a?(String) && data.match?(/\A0x[0-9a-fA-F]+\z/) && data.length >= 10

    selector = data.to_s[2, 8].to_s.downcase
    allowed_gas = CASHIER_GAS_LIMITS.find do |signature, _limit|
      Crypto::Ethereum.function_selector(signature) == selector
    end&.last
    raise ArgumentError, "Unsupported cashier call" unless allowed_gas
    raise ArgumentError, "Invalid cashier gas limit" unless gas_limit.to_i == allowed_gas

    forwarder_address = service.send(:forwarder_address)
    cashier_address = service.send(:cashier_address)
    ensure_forwarder_target!(forwarder: forwarder_address, target: cashier_address)
    simulate_forwarded_call!(
      target: cashier_address,
      forwarder: forwarder_address,
      sender: wallet.address,
      data: data
    )

    nonce = service.send(:read_nonce, forwarder_address, "nonces(address)", wallet.address)
    deadline = Time.current.to_i + REQUEST_TTL.to_i
    request = {
      "from" => wallet.address,
      "to" => cashier_address,
      "value" => "0",
      "gas" => gas_limit.to_i.to_s,
      "nonce" => nonce.to_s,
      "deadline" => deadline.to_s,
      "data" => data,
      "forwarder" => forwarder_address,
      "chain_id" => service.send(:chain_id).to_s
    }
    {
      typed_data: build_forward_request_typed_data(
        request:,
        chain_id: service.send(:chain_id),
        token_address: forwarder_address
      ),
      state: { "request" => request }
    }
  end

  def self.verify_signature!(request:, signature:, token_address:, chain_id:)
    digest = forward_request_digest(request:, token_address:, chain_id:)
    signer = Crypto::Ethereum.recover_digest_signer(digest_hex: digest, signature:)
    raise ArgumentError, "Forward request signer does not match" unless signer.casecmp?(request.fetch("from"))

    true
  end

  def self.build_forward_request_typed_data(request:, chain_id:, token_address:)
    {
      domain: {
        name: FORWARDER_DOMAIN_NAME,
        version: "1",
        chainId: chain_id,
        verifyingContract: token_address
      },
      types: {
        EIP712Domain: [
          { name: "name", type: "string" },
          { name: "version", type: "string" },
          { name: "chainId", type: "uint256" },
          { name: "verifyingContract", type: "address" }
        ],
        ForwardRequest: [
          { name: "from", type: "address" },
          { name: "to", type: "address" },
          { name: "value", type: "uint256" },
          { name: "gas", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint48" },
          { name: "data", type: "bytes" }
        ]
      },
      primaryType: "ForwardRequest",
      message: request.slice("from", "to", "value", "gas", "nonce", "deadline", "data")
    }
  end

  def self.relay!(user_id:, transaction_ids:, request:, signature:)
    user = User.find(user_id)
    wallet = user.wallets.external.find_by(address: request.fetch("from"), chain_id: request.fetch("chain_id"))
    raise ArgumentError, "External reward wallet changed" unless wallet
    raise ArgumentError, "Forward request expired" if request.fetch("deadline").to_i < Time.current.to_i
    raise ArgumentError, "Unsupported rewards target" unless request.fetch("to").casecmp?(ENV["REWARDS_CONTRACT_ADDRESS"].to_s)
    raise ArgumentError, "Unsupported forwarder" unless request.fetch("forwarder").casecmp?(ENV["FORWARDER_CONTRACT_ADDRESS"].to_s)
    ensure_forwarder_target!(forwarder: request.fetch("forwarder"), target: request.fetch("to"))

    verify_signature!(
      request: request,
      signature: signature,
      token_address: request.fetch("forwarder"),
      chain_id: request.fetch("chain_id").to_i
    )

    transactions = user.token_transactions
      .where(id: transaction_ids, claimed: false, status: %w[pending failed])
      .available
      .order(:id)
      .to_a
    raise ArgumentError, "Reward claim is no longer available" if transactions.empty?

    amount_wei = TokenTransactionService.to_wei(transactions.sum(&:amount), 18)
    raise ArgumentError, "Reward claim amount changed" unless amount_wei == request.fetch("amount_wei")

    tx_hash = TokenTransactionService.submit_forwarder_transaction!(
      request: request,
      signature: signature,
      forwarder_address: request.fetch("forwarder"),
      chain_id: request.fetch("chain_id").to_i
    )

    transactions.each do |transaction|
      transaction.update!(
        wallet: wallet,
        tx_hash: tx_hash,
        status: :confirmed,
        claimed: true
      )
    end

    tx_hash
  end

  def self.relay_cashier!(user_id:, request:, signature:)
    user = User.find(user_id)
    wallet = user.wallets.external.find_by(address: request.fetch("from"), chain_id: request.fetch("chain_id"))
    raise ArgumentError, "External wallet changed" unless wallet
    raise ArgumentError, "Forward request expired" if request.fetch("deadline").to_i < Time.current.to_i
    raise ArgumentError, "Unsupported cashier target" unless request.fetch("to").casecmp?(ENV["CROWDSALE_CONTRACT_ADDRESS"].to_s)
    raise ArgumentError, "Unsupported forwarder" unless request.fetch("forwarder").casecmp?(ENV["FORWARDER_CONTRACT_ADDRESS"].to_s)
    raise ArgumentError, "Forwarded value is not supported" unless request.fetch("value").to_i.zero?
    raise ArgumentError, "Wrong chain" unless request.fetch("chain_id").to_i == Integer(ENV["CHAIN_ID"].presence || "0x14a34", 0)

    selector = request.fetch("data")[2, 8].downcase
    allowed_gas = CASHIER_GAS_LIMITS.find do |signature_text, _limit|
      Crypto::Ethereum.function_selector(signature_text) == selector
    end&.last
    raise ArgumentError, "Unsupported cashier call" unless allowed_gas && request.fetch("gas").to_i == allowed_gas

    verify_signature!(
      request:,
      signature:,
      token_address: request.fetch("forwarder"),
      chain_id: request.fetch("chain_id").to_i
    )
    self.ensure_forwarder_target!(forwarder: request.fetch("forwarder"), target: request.fetch("to"))
    TokenTransactionService.submit_forwarder_transaction!(
      request:,
      signature:,
      forwarder_address: request.fetch("forwarder"),
      chain_id: request.fetch("chain_id").to_i
    )
  end

  def self.forward_request_digest(request:, token_address:, chain_id:)
    domain = domain_separator(FORWARDER_DOMAIN_NAME, token_address, chain_id)
    struct_hash = Crypto::Ethereum.keccak256(
      [
        Crypto::Ethereum.keccak256(FORWARD_REQUEST_TYPE),
        send(:abi_word_address, request.fetch("from")),
        send(:abi_word_address, request.fetch("to")),
        send(:abi_word_uint, request.fetch("value")),
        send(:abi_word_uint, request.fetch("gas")),
        send(:abi_word_uint, request.fetch("nonce")),
        send(:abi_word_uint, request.fetch("deadline")),
        Crypto::Ethereum.keccak256([ request.fetch("data").delete_prefix("0x") ].pack("H*"))
      ].join.then { |encoded| [ encoded ].pack("H*") }
    )
    Crypto::Ethereum.keccak256("\x19\x01".b + [ domain + struct_hash ].pack("H*"))
  end

  private

  attr_reader :user, :transactions

  #
  # Verifies request state belongs to the user and has not expired.
  #
  # @param user [User] authenticated requester
  # @param state [Hash] stored session data
  # @return [Boolean]
  #
  def self.valid_request_state?(user:, state:)
    return false unless state.is_a?(Hash) && state["request"].is_a?(Hash)

    state["user_id"].to_s == user.id.to_s &&
      state["request"]["deadline"].to_s.to_i > Time.current.to_i
  end

  def initialize(user:, transactions:)
    @user = user
    @transactions = transactions
  end

  def prepare!
    wallet = user.wallets.external.find_by(chain_id: chain_id.to_s)
    raise ArgumentError, "A connected external wallet on the configured chain is required" unless wallet
    raise ArgumentError, "No available rewards" if transactions.empty?

    amount_wei = TokenTransactionService.to_wei(transactions.sum(&:amount), 18)
    forwarder = forwarder_address
    self.class.ensure_forwarder_target!(forwarder:, target: rewards_address)
    forwarder_nonce = read_nonce(forwarder, "nonces(address)", wallet.address)
    claim_nonce = read_nonce(rewards_address, "rewardClaimNonces(address)", wallet.address)
    deadline = Time.current.to_i + REQUEST_TTL.to_i
    operator_signature = sign_reward_claim(wallet.address, amount_wei, claim_nonce, deadline)
    data = Crypto::Ethereum.encode_reward_claim_data(amount_wei, claim_nonce, deadline, operator_signature)

    request = {
      "from" => wallet.address,
      "to" => rewards_address,
      "value" => "0",
      "gas" => FORWARD_GAS_LIMIT.to_s,
      "nonce" => forwarder_nonce.to_s,
      "deadline" => deadline.to_s,
      "data" => data,
      "forwarder" => forwarder,
      "chain_id" => chain_id.to_s,
      "amount_wei" => amount_wei
    }
    simulate_forwarded_call!(
      target: rewards_address,
      forwarder: forwarder,
      sender: wallet.address,
      data: data
    )
    {
      typed_data: forward_request_typed_data(request),
      state: {
        "request" => request,
        "transaction_ids" => transactions.map(&:id)
      }
    }
  end

  def forward_request_typed_data(request)
    self.class.build_forward_request_typed_data(request:, chain_id:, token_address:)
  end

  def sign_reward_claim(address, amount_wei, nonce, deadline)
    domain = self.class.domain_separator(REWARDS_DOMAIN_NAME, rewards_address, chain_id)
    struct_hash = Crypto::Ethereum.keccak256(
      [
        Crypto::Ethereum.keccak256(REWARD_CLAIM_TYPE),
        self.class.send(:abi_word_address, address),
        self.class.send(:abi_word_uint, amount_wei),
        self.class.send(:abi_word_uint, nonce),
        self.class.send(:abi_word_uint, deadline)
      ].join.then { |encoded| [ encoded ].pack("H*") }
    )
    digest = Crypto::Ethereum.keccak256("\x19\x01".b + [ domain + struct_hash ].pack("H*"))
    Crypto::Ethereum.sign_digest(private_key_hex: operator_private_key, digest_hex: digest)
  end

  def read_nonce(contract, signature, address)
    data = "0x#{Crypto::Ethereum.function_selector(signature)}#{Crypto::Ethereum.encode_address(address)}"
    response = TokenTransactionService.rpc_call("eth_call", [ { to: contract, data: data }, "latest" ])
    Integer(response, 16)
  end

  def token_address
    required_address!("TOKEN_CONTRACT_ADDRESS")
  end

  #
  # Returns the configured OpenZeppelin ERC2771Forwarder deployment.
  #
  # @return [String] forwarder contract address
  #
  def forwarder_address
    required_address!("FORWARDER_CONTRACT_ADDRESS")
  end

  def rewards_address
    required_address!("REWARDS_CONTRACT_ADDRESS")
  end

  def cashier_address
    required_address!("CROWDSALE_CONTRACT_ADDRESS")
  end

  def required_address!(name)
    address = ENV[name].to_s
    raise KeyError, "#{name} is required" unless address.match?(/\A0x[0-9a-fA-F]{40}\z/)

    address
  end

  def chain_id
    Integer(ENV["CHAIN_ID"].presence || "0x14a34", 0)
  end

  def operator_private_key
    key = ENV["OPERATOR_PRIVATE_KEY"].to_s.sub(/\A0x/, "")
    raise KeyError, "OPERATOR_PRIVATE_KEY is required" unless key.match?(/\A[0-9a-fA-F]{64}\z/)

    key
  end

  class << self
    def domain_separator(name, verifying_contract, chain_id)
      Crypto::Ethereum.keccak256(
        [
          Crypto::Ethereum.keccak256(EIP712_DOMAIN_TYPE),
          Crypto::Ethereum.keccak256(name),
          Crypto::Ethereum.keccak256("1"),
          abi_word_uint(chain_id),
          abi_word_address(verifying_contract)
        ].join.then { |encoded| [ encoded ].pack("H*") }
      )
    end

    private

    def abi_word_address(value)
      value.to_s.delete_prefix("0x").downcase.rjust(64, "0")
    end

    def abi_word_uint(value)
      Integer(value).to_s(16).rjust(64, "0")
    end
  end
end
