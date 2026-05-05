# frozen_string_literal: true

require 'net/http'
require 'json'

# ContractService - главный сервис для работы со смарт-контрактами TravelFi
#
# Этот сервис является промежуточным слоем между Rails приложением и блокчейном.
# Все методы предполагают, что:
# 1. Транзакции подписаны с клиента (MetaMask) - вы передаёте signed_tx
# 2. Мы только отправляем уже подписанную транзакцию в сеть (eth_sendRawTransaction)
# 3. Мы НЕ подписываем никаких операций на сервере
# 4. Все операции логируются через ContractsAuditLogger в PaperTrail
#
# Структура смарт-контрактов из travel-fi.sol:
# - TravelFiToken: 6 методов (mint, burn, transferToken, pause, unpause, getContractStatus)
# - TravelFiCrowdsale: 10 методов (buyWithUSDT, buyWithETH, sellWithUSDT, sellWithETH, setUSDTRate, setETHRate, transferToken, pause, unpause, getContractStatus)
# - TravelFiRewards: 10 методов (setLockDays, sendReward, sendRewardBatch, claimReward, revokeReward, transferToken, pause, unpause, getUserRewardInfo, getContractStatus)
#
# ВСЕГО: 26 методов (NO DEPRECATED, NO DUPLICATES), все функции используют WEI
#
class ContractService
  # ===== КОНТРАКТЫ И АДРЕСА =====
  TOKEN_ADDRESS = ENV['TOKEN_CONTRACT_ADDRESS']
  CROWDSALE_ADDRESS = ENV['CROWDSALE_CONTRACT_ADDRESS']
  REWARDS_ADDRESS = ENV['REWARDS_CONTRACT_ADDRESS']
  USDT_ADDRESS = ENV['USDT_CONTRACT_ADDRESS']
  RPC_URL = ENV['RPC_URL']

  def self.to_wei(amount, decimals = 18)
    amt = amount.to_s.strip
    return '0' if amt == ''
    require 'bigdecimal'
    value = BigDecimal(amt)
    factor = BigDecimal(10) ** decimals
    (value * factor).to_i.to_s
  end

  # ===== TRAVELFITOKEN CONTRACT (6 методов) =====

  # 1. Создать новые токены (mint)
  def self.token_mint(user_id:, admin_address:, amount_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_token_mint(user_id: user_id, admin_address: admin_address, amount_wei: amount_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.token_mint: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 2. Сжечь токены (burn)
  def self.token_burn(user_id:, admin_address:, amount_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_token_burn(user_id: user_id, admin_address: admin_address, amount_wei: amount_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.token_burn: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 3. Передать любые ERC-20 токены (transferToken)
  def self.token_transfer(user_id:, admin_address:, token_address:, recipient:, amount_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_token_transfer(user_id: user_id, admin_address: admin_address, token_address: token_address, recipient: recipient, amount_wei: amount_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.token_transfer: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 3a. Передать ETH внешнему адресу или контракту (transferToken с tokenAddr=address(0))
  def self.token_transfer_eth_to(user_id:, admin_address:, target_contract:, amount_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_token_transfer_eth_to(user_id: user_id, admin_address: admin_address, target_contract: target_contract, amount: amount_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.token_transfer_eth_to: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 4. Заморозить контракт токена (pause)
  def self.token_pause(user_id:, admin_address:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_token_pause(user_id: user_id, admin_address: admin_address, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.token_pause: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 5. Разморозить контракт токена (unpause)
  def self.token_unpause(user_id:, admin_address:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_token_unpause(user_id: user_id, admin_address: admin_address, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.token_unpause: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 6. Получить статус контракта Token (read-only)
  def self.token_get_contract_status(user_id:, admin_address:)
    begin
      data = '0xd2f5a612'
      result = call_rpc('eth_call', [{ to: TOKEN_ADDRESS, data: data }, 'latest'])
      ContractsAuditLogger.log_token_get_contract_status(user_id: user_id, admin_address: admin_address)
      { success: true, data: result['result'] }
    rescue => e
      Rails.logger.error("ContractService.token_get_contract_status: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # ===== TRAVELFICROWDSALE CONTRACT (10 методов) =====

  # 7. Купить TFT за USDT (buyWithUSDT)
  def self.crowdsale_buy_with_usdt(user_id:, user_address:, usdt_amount_wei:, min_tft_out_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_crowdsale_buy_with_usdt(user_id: user_id, user_address: user_address, usdt_amount_wei: usdt_amount_wei, min_tft_out_wei: min_tft_out_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.crowdsale_buy_with_usdt: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 8. Купить TFT за ETH (buyWithETH)
  def self.crowdsale_buy_with_eth(user_id:, user_address:, eth_amount_wei:, min_tft_out_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_crowdsale_buy_with_eth(user_id: user_id, user_address: user_address, eth_amount_wei: eth_amount_wei, min_tft_out_wei: min_tft_out_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.crowdsale_buy_with_eth: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 9. Продать TFT за USDT (sellWithUSDT)
  def self.crowdsale_sell_with_usdt(user_id:, user_address:, tft_amount_wei:, min_usdt_out_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_crowdsale_sell_with_usdt(user_id: user_id, user_address: user_address, tft_amount_wei: tft_amount_wei, min_usdt_out_wei: min_usdt_out_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.crowdsale_sell_with_usdt: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 10. Продать TFT за ETH (sellWithETH)
  def self.crowdsale_sell_with_eth(user_id:, user_address:, tft_amount_wei:, min_eth_out_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_crowdsale_sell_with_eth(user_id: user_id, user_address: user_address, tft_amount_wei: tft_amount_wei, min_eth_out_wei: min_eth_out_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.crowdsale_sell_with_eth: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 11. Установить курс USDT/TFT (setUSDTRate)
  def self.crowdsale_set_usdt_rate(user_id:, admin_address:, new_rate_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_crowdsale_set_usdt_rate(user_id: user_id, admin_address: admin_address, new_rate_wei: new_rate_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.crowdsale_set_usdt_rate: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 12. Установить курс ETH/TFT (setETHRate)
  def self.crowdsale_set_eth_rate(user_id:, admin_address:, new_rate_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_crowdsale_set_eth_rate(user_id: user_id, admin_address: admin_address, new_rate_wei: new_rate_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.crowdsale_set_eth_rate: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 13. Передать любые ERC-20 из краудсейла (transferToken)
  def self.crowdsale_transfer_token(user_id:, admin_address:, token_address:, recipient:, amount_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_crowdsale_transfer_token(user_id: user_id, admin_address: admin_address, token_address: token_address, recipient: recipient, amount_wei: amount_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.crowdsale_transfer_token: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 14. Заморозить краудсейл (pause)
  def self.crowdsale_pause(user_id:, admin_address:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_crowdsale_pause(user_id: user_id, admin_address: admin_address, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.crowdsale_pause: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 15. Разморозить краудсейл (unpause)
  def self.crowdsale_unpause(user_id:, admin_address:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_crowdsale_unpause(user_id: user_id, admin_address: admin_address, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.crowdsale_unpause: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 16. Получить статус контракта Crowdsale (read-only)
  def self.crowdsale_get_contract_status(user_id:, admin_address:)
    begin
      data = '0xd2f5a612'
      result = call_rpc('eth_call', [{ to: CROWDSALE_ADDRESS, data: data }, 'latest'])
      ContractsAuditLogger.log_crowdsale_get_contract_status(user_id: user_id, admin_address: admin_address)
      { success: true, data: result['result'] }
    rescue => e
      Rails.logger.error("ContractService.crowdsale_get_contract_status: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # ===== TRAVELFIREWARDS CONTRACT (10 методов) =====

  # 17. Установить период lock для rewards (setLockDays)
  def self.rewards_set_lock_days(user_id:, admin_address:, new_lock_days:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_rewards_set_lock_days(user_id: user_id, admin_address: admin_address, new_lock_days: new_lock_days, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.rewards_set_lock_days: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 18. Выделить награду (sendReward) - БЕЗ lock_days, используется глобальный параметр
  def self.rewards_send_reward(user_id:, admin_address:, recipient_address:, amount_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_rewards_send_reward(user_id: user_id, admin_address: admin_address, recipient_address: recipient_address, amount_wei: amount_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.rewards_send_reward: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 19. Выделить награды пакетом (sendRewardBatch) - БЕЗ lock_days, используется глобальный параметр
  def self.rewards_send_reward_batch(user_id:, admin_address:, recipients:, amounts_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_rewards_send_reward_batch(user_id: user_id, admin_address: admin_address, recipients_count: recipients.length, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.rewards_send_reward_batch: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 20. Требовать свою награду (claimReward)
  def self.rewards_claim_reward(user_id:, user_address:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_rewards_claim_reward(user_id: user_id, user_address: user_address, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.rewards_claim_reward: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 21. Отозвать выделённую награду (revokeReward)
  def self.rewards_revoke_reward(user_id:, admin_address:, user_address:, amount_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_rewards_revoke_reward(user_id: user_id, admin_address: admin_address, user_address: user_address, amount_wei: amount_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.rewards_revoke_reward: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 22. Передать любые ERC-20 из наград (transferToken)
  def self.rewards_transfer_token(user_id:, admin_address:, token_address:, recipient:, amount_wei:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_rewards_transfer_token(user_id: user_id, admin_address: admin_address, token_address: token_address, recipient: recipient, amount_wei: amount_wei, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.rewards_transfer_token: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 23. Заморозить награды (pause)
  def self.rewards_pause(user_id:, admin_address:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_rewards_pause(user_id: user_id, admin_address: admin_address, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.rewards_pause: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 24. Разморозить награды (unpause)
  def self.rewards_unpause(user_id:, admin_address:, signed_tx:)
    begin
      tx_hash = send_raw_transaction(signed_tx)
      ContractsAuditLogger.log_rewards_unpause(user_id: user_id, admin_address: admin_address, tx_hash: tx_hash)
      { success: true, tx_hash: tx_hash }
    rescue => e
      Rails.logger.error("ContractService.rewards_unpause: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 25. Получить информацию о награде пользователя (read-only)
  def self.rewards_get_user_reward_info(user_id:, user_address:)
    begin
      ContractsAuditLogger.log_rewards_get_user_reward_info(user_id: user_id, user_address: user_address)
      { success: true, user_address: user_address }
    rescue => e
      Rails.logger.error("ContractService.rewards_get_user_reward_info: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # 26. Получить статус контракта Rewards (read-only)
  def self.rewards_get_contract_status(user_id:, admin_address:)
    begin
      data = '0xd2f5a612'
      result = call_rpc('eth_call', [{ to: REWARDS_ADDRESS, data: data }, 'latest'])
      ContractsAuditLogger.log_rewards_get_contract_status(user_id: user_id, admin_address: admin_address)
      { success: true, data: result['result'] }
    rescue => e
      Rails.logger.error("ContractService.rewards_get_contract_status: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # ===== PRIVATE HELPER METHODS =====

  private

  def self.send_raw_transaction(signed_tx)
    response = call_rpc('eth_sendRawTransaction', [signed_tx])
    raise response['error']['message'] if response['error']
    response['result']
  end

  def self.call_rpc(method, params)
    Rails.logger.info("========== CALL_RPC START ==========")
    Rails.logger.info("RPC_URL: #{RPC_URL}")
    Rails.logger.info("Method: #{method}")
    Rails.logger.info("Params: #{params.inspect}")
    
    uri = URI.parse(RPC_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    
    request = Net::HTTP::Post.new(uri.path.empty? ? '/' : uri.path)
    request['Content-Type'] = 'application/json'
    request.body = { jsonrpc: '2.0', method: method, params: params, id: 1 }.to_json
    
    Rails.logger.info("Request body: #{request.body}")
    
    response = http.request(request)
    
    Rails.logger.info("HTTP Status: #{response.code}")
    Rails.logger.info("Response body (raw): #{response.body.inspect}")
    Rails.logger.info("Response body (length): #{response.body.length} bytes")
    
    parsed = JSON.parse(response.body)
    Rails.logger.info("Parsed result: #{parsed.inspect}")
    Rails.logger.info("========== CALL_RPC END ==========")
    
    parsed
  rescue => e
    Rails.logger.error("========== CALL_RPC ERROR ==========")
    Rails.logger.error("Error class: #{e.class}")
    Rails.logger.error("Error message: #{e.message}")
    Rails.logger.error("Error backtrace: #{e.backtrace.first(5).join("\n")}")
    Rails.logger.error("=========== ERROR END ===========")
    { 'error' => e.message }
  end

  def self.build_approve_params(token_address:, spender_address:, amount:)
    # Build approve(spender, amount) transaction for ERC20
    # approve is a standard ERC20 function: approve(address spender, uint256 amount)
    {
      contract_address: token_address,
      function_name: 'approve',
      params: [spender_address, amount],
      value: nil
    }
  end

  def self.build_transaction_params(method_name, **params)
    contract_address = case method_name
                       when /^token_/
                         TOKEN_ADDRESS
                       when /^crowdsale_/
                         CROWDSALE_ADDRESS
                       when /^rewards_/
                         REWARDS_ADDRESS
                       end

    raise "Unknown contract method: #{method_name}" unless contract_address

    Rails.logger.info "[ContractService#build_transaction_params] method=#{method_name.inspect}, params=#{params.inspect}"

    case method_name
    # TOKEN CONTRACT (6 методов)
    when :token_mint
      { contract_address: contract_address, function_name: 'mint', params: [params[:amount_wei]] }
    when :token_burn
      { contract_address: contract_address, function_name: 'burn', params: [params[:amount_wei]] }
    when :token_transfer
      { contract_address: contract_address, function_name: 'transferToken', params: [params[:token_address], params[:recipient], params[:amount_wei]] }
    when :token_transfer_eth_to
      # ETH transfer: tokenAddr=address(0), to=target_contract, amount=amount_wei
      { contract_address: contract_address, function_name: 'transferToken', params: ['0x0000000000000000000000000000000000000000', params[:target_contract], params[:amount_wei]] }
    when :token_pause
      { contract_address: contract_address, function_name: 'pause', params: [] }
    when :token_unpause
      { contract_address: contract_address, function_name: 'unpause', params: [] }
    
    # CROWDSALE CONTRACT (10 методов)
    when :crowdsale_buy_with_usdt
      { contract_address: contract_address, function_name: 'buyWithUSDT', params: [params[:usdt_amount_wei], params[:min_tft_out_wei]], value: '0' }
    when :crowdsale_buy_with_eth
      { contract_address: contract_address, function_name: 'buyWithETH', params: [params[:min_tft_out_wei]], value: params[:eth_amount_wei].to_s }
    when :crowdsale_sell_with_usdt
      { contract_address: contract_address, function_name: 'sellWithUSDT', params: [params[:tft_amount_wei], params[:min_usdt_out_wei]], value: '0' }
    when :crowdsale_sell_with_eth
      { contract_address: contract_address, function_name: 'sellWithETH', params: [params[:tft_amount_wei], params[:min_eth_out_wei]], value: '0' }
    when :crowdsale_set_usdt_rate
      { contract_address: contract_address, function_name: 'setUSDTRate', params: [params[:new_rate_wei]] }
    when :crowdsale_set_eth_rate
      { contract_address: contract_address, function_name: 'setETHRate', params: [params[:new_rate_wei]] }
    when :crowdsale_transfer_token
      { contract_address: contract_address, function_name: 'transferToken', params: [params[:token_address], params[:recipient], params[:amount_wei]] }
    when :crowdsale_pause
      { contract_address: contract_address, function_name: 'pause', params: [] }
    when :crowdsale_unpause
      { contract_address: contract_address, function_name: 'unpause', params: [] }
    
    # REWARDS CONTRACT (10 методов)
    when :rewards_set_lock_days
      { contract_address: contract_address, function_name: 'setLockDays', params: [params[:new_lock_days]] }
    when :rewards_send_reward
      { contract_address: contract_address, function_name: 'sendReward', params: [params[:recipient_address], params[:amount_wei]] }
    when :rewards_send_reward_batch
      { contract_address: contract_address, function_name: 'sendRewardBatch', params: [params[:recipients], params[:amounts_wei]] }
    when :rewards_claim_reward
      { contract_address: contract_address, function_name: 'claimReward', params: [] }
    when :rewards_revoke_reward
      { contract_address: contract_address, function_name: 'revokeReward', params: [params[:user_address], params[:amount_wei]] }
    when :rewards_transfer_token
      { contract_address: contract_address, function_name: 'transferToken', params: [params[:token_address], params[:recipient], params[:amount_wei]] }
    when :rewards_pause
      { contract_address: contract_address, function_name: 'pause', params: [] }
    when :rewards_unpause
      { contract_address: contract_address, function_name: 'unpause', params: [] }
    else
      raise "Transaction parameter building not implemented for #{method_name}"
    end
  end

  def self.get_paused_status(contract_address)
    data = encode_function_call('paused()', [])
    response = call_rpc('eth_call', [
      {
        to: contract_address,
        data: data
      },
      'latest'
    ])
    
    Rails.logger.info("get_paused_status response: #{response.inspect}")
    
    if response['error']
      Rails.logger.error("RPC error in get_paused_status: #{response['error']}")
      return 'unknown'
    end
    
    result = response['result'].to_s.sub(/^0x/, '')
    result == '0' * 64 ? 'active' : 'inactive'
  rescue => e
    Rails.logger.error("Error getting paused status: #{e.message}\n#{e.backtrace.join("\n")}")
    'unknown'
  end

  def self.get_total_supply
    response = call_rpc('eth_call', [
      {
        to: TOKEN_ADDRESS,
        data: encode_function_call('totalSupply()', [])
      },
      'latest'
    ])
    
    result = response['result'].to_s.sub(/^0x/, '')
    wei_to_decimal(result, 18)
  rescue => e
    Rails.logger.error("Error getting total supply: #{e.message}")
    0
  end

  def self.get_token_balance(contract_address)
    response = call_rpc('eth_call', [
      {
        to: TOKEN_ADDRESS,
        data: encode_function_call('balanceOf(address)', [contract_address])
      },
      'latest'
    ])
    
    result = response['result'].to_s.sub(/^0x/, '')
    wei_to_decimal(result, 18)
  rescue => e
    Rails.logger.error("Error getting token balance: #{e.message}")
    0
  end

  def self.get_usdt_balance(contract_address)
    response = call_rpc('eth_call', [
      {
        to: USDT_ADDRESS,
        data: encode_function_call('balanceOf(address)', [contract_address])
      },
      'latest'
    ])
    
    result = response['result'].to_s.sub(/^0x/, '')
    wei_to_decimal(result, 6)
  rescue => e
    Rails.logger.error("Error getting USDT balance: #{e.message}")
    0
  end

  def self.get_eth_balance(contract_address)
    response = call_rpc('eth_getBalance', [contract_address, 'latest'])
    
    result = response['result'].to_s.sub(/^0x/, '')
    wei_to_decimal(result, 18)
  rescue => e
    Rails.logger.error("Error getting ETH balance: #{e.message}")
    0
  end

  def self.get_usdt_rate(contract_address = CROWDSALE_ADDRESS)
    Rails.logger.info("========== GET_USDT_RATE (via getContractStatus) ==========")
    Rails.logger.info("Contract address: #{contract_address}")
    
    response = call_rpc('eth_call', [
      {
        to: contract_address,
        data: encode_function_call('getContractStatus()', [])
      },
      'latest'
    ])
    
    if response['error']
      Rails.logger.error("RPC error in get_usdt_rate: #{response['error']}")
      return 0
    end
    
    result = response['result'].to_s.sub(/^0x/, '')
    return 0 if result.empty?
    
    # getContractStatus returns (tftBalance, usdtBalance, ethBalance, currentUsdtRate, currentEthRate, isPaused)
    # Each value is 32 bytes (64 hex chars)
    # currentUsdtRate is the 4th return value (index 3), at offset 3 * 64 = 192 chars
    return 0 if result.length < 256 # need at least 4 values
    
    rate_hex = result[192..255]
    rate_wei = rate_hex.to_i(16)
    
    Rails.logger.info("Raw usdt_rate_wei: #{rate_wei}, hex: #{rate_wei.to_s(16)}, converted: #{wei_to_decimal(rate_wei.to_s(16), 18)}")
    
    wei_to_decimal(rate_wei.to_s(16), 18)
  rescue => e
    Rails.logger.error("Error getting USDT rate: #{e.message}\n#{e.backtrace.join("\n")}")
    0
  end

  def self.get_eth_rate(contract_address = CROWDSALE_ADDRESS)
    Rails.logger.info("========== GET_ETH_RATE (via getContractStatus) ==========")
    Rails.logger.info("Contract address: #{contract_address}")
    
    response = call_rpc('eth_call', [
      {
        to: contract_address,
        data: encode_function_call('getContractStatus()', [])
      },
      'latest'
    ])
    
    if response['error']
      Rails.logger.error("RPC error in get_eth_rate: #{response['error']}")
      return 0
    end
    
    result = response['result'].to_s.sub(/^0x/, '')
    return 0 if result.empty?
    
    # getContractStatus returns (tftBalance, usdtBalance, ethBalance, currentUsdtRate, currentEthRate, isPaused)
    # Each value is 32 bytes (64 hex chars)
    # currentEthRate is the 5th return value (index 4), at offset 4 * 64 = 256 chars
    return 0 if result.length < 320 # need at least 5 values
    
    rate_hex = result[256..319]
    rate_wei = rate_hex.to_i(16)
    
    Rails.logger.info("Raw eth_rate_wei: #{rate_wei}, hex: #{rate_wei.to_s(16)}, converted: #{wei_to_decimal(rate_wei.to_s(16), 18)}")
    
    wei_to_decimal(rate_wei.to_s(16), 18)
  rescue => e
    Rails.logger.error("Error getting ETH rate: #{e.message}\n#{e.backtrace.join("\n")}")
    0
  end

  def self.get_token_contract_status(contract_address = TOKEN_ADDRESS)
    Rails.logger.info("========== GET_TOKEN_CONTRACT_STATUS (via getContractStatus) ==========")
    Rails.logger.info("Contract address: #{contract_address}")
    
    response = call_rpc('eth_call', [
      {
        to: contract_address,
        data: encode_function_call('getContractStatus()', [])
      },
      'latest'
    ])
    
    if response['error']
      Rails.logger.error("RPC error in get_token_contract_status: #{response['error']}")
      return {
        tft_balance: 0,
        usdt_balance: 0,
        eth_balance: 0,
        max_supply: 0,
        current_supply: 0,
        paused: false
      }
    end
    
    result = response['result'].to_s.sub(/^0x/, '')
    return {} if result.empty?
    
    # Token getContractStatus returns:
    # 0: tftBalance (18 decimals)
    # 1: usdtBalance (6 decimals)
    # 2: ethBalance (18 decimals)
    # 3: maxSupply (18 decimals)
    # 4: currentSupply (18 decimals)
    # 5: isPaused (bool)
    # Each value is 32 bytes (64 hex chars)
    
    return {} if result.length < 384 # need at least 6 values
    
    {
      tft_balance: wei_to_decimal(result[0..63], 18),
      usdt_balance: wei_to_decimal(result[64..127], 6),
      eth_balance: wei_to_decimal(result[128..191], 18),
      max_supply: wei_to_decimal(result[192..255], 18),
      current_supply: wei_to_decimal(result[256..319], 18),
      paused: result[320..383].to_i(16) != 0
    }
  rescue => e
    Rails.logger.error("Error getting token contract status: #{e.message}\n#{e.backtrace.join("\n")}")
    {}
  end

  def self.get_crowdsale_contract_status(contract_address = CROWDSALE_ADDRESS)
    Rails.logger.info("========== GET_CROWDSALE_CONTRACT_STATUS (via getContractStatus) ==========")
    Rails.logger.info("Contract address: #{contract_address}")
    
    response = call_rpc('eth_call', [
      {
        to: contract_address,
        data: encode_function_call('getContractStatus()', [])
      },
      'latest'
    ])
    
    if response['error']
      Rails.logger.error("RPC error in get_crowdsale_contract_status: #{response['error']}")
      return {
        tft_balance: 0,
        usdt_balance: 0,
        eth_balance: 0,
        usdt_rate: 0,
        eth_rate: 0,
        paused: false
      }
    end
    
    result = response['result'].to_s.sub(/^0x/, '')
    return {} if result.empty?
    
    # Crowdsale getContractStatus returns:
    # 0: tftBalance (18 decimals)
    # 1: usdtBalance (6 decimals)
    # 2: ethBalance (18 decimals)
    # 3: currentUsdtRate (18 decimals)
    # 4: currentEthRate (18 decimals)
    # 5: isPaused (bool)
    # Each value is 32 bytes (64 hex chars)
    
    return {} if result.length < 384 # need at least 6 values
    
    {
      tft_balance: wei_to_decimal(result[0..63], 18),
      usdt_balance: wei_to_decimal(result[64..127], 6),
      eth_balance: wei_to_decimal(result[128..191], 18),
      usdt_rate: wei_to_decimal(result[192..255], 18),
      eth_rate: wei_to_decimal(result[256..319], 18),
      paused: result[320..383].to_i(16) != 0
    }
  rescue => e
    Rails.logger.error("Error getting crowdsale contract status: #{e.message}\n#{e.backtrace.join("\n")}")
    {}
  end

  def self.get_rewards_contract_status(contract_address = REWARDS_ADDRESS)
    Rails.logger.info("========== GET_REWARDS_CONTRACT_STATUS (via getContractStatus) ==========")
    Rails.logger.info("Contract address: #{contract_address}")
    
    response = call_rpc('eth_call', [
      {
        to: contract_address,
        data: encode_function_call('getContractStatus()', [])
      },
      'latest'
    ])
    
    if response['error']
      Rails.logger.error("RPC error in get_rewards_contract_status: #{response['error']}")
      return {
        tft_balance: 0,
        total_allocated_rewards: 0,
        total_claimed_rewards: 0,
        eth_balance: 0,
        usdt_balance: 0,
        lock_days: 7,
        paused: false
      }
    end
    
    result = response['result'].to_s.sub(/^0x/, '')
    return {} if result.empty?
    
    # Rewards getContractStatus returns:
    # 0: tftBalance (18 decimals)
    # 1: totalAllocatedRewards (18 decimals)
    # 2: totalClaimedRewards (18 decimals)
    # 3: ethBalance (18 decimals)
    # 4: usdtBalance (6 decimals)
    # 5: currentLockDays (uint256, no decimals)
    # 6: isPaused (bool)
    # Each value is 32 bytes (64 hex chars)
    
    return {} if result.length < 448 # need at least 7 values
    
    {
      tft_balance: wei_to_decimal(result[0..63], 18),
      total_allocated_rewards: wei_to_decimal(result[64..127], 18),
      total_claimed_rewards: wei_to_decimal(result[128..191], 18),
      eth_balance: wei_to_decimal(result[192..255], 18),
      usdt_balance: wei_to_decimal(result[256..319], 6),
      lock_days: result[320..383].to_i(16),
      paused: result[384..447].to_i(16) != 0
    }
  rescue => e
    Rails.logger.error("Error getting rewards contract status: #{e.message}\n#{e.backtrace.join("\n")}")
    {}
  end

  def self.get_contract_data(contract_type)
    address = case contract_type
              when 'token' then TOKEN_ADDRESS
              when 'crowdsale' then CROWDSALE_ADDRESS
              when 'rewards' then REWARDS_ADDRESS
              else raise "Unknown contract type: #{contract_type}"
              end

    # Get all contract status data via single getContractStatus() call
    case contract_type
    when 'token'
      status = get_token_contract_status(address)
      data = {
        paused: status[:paused],
        total_supply: status[:current_supply],
        token_balance: status[:tft_balance],
        usdt_balance: status[:usdt_balance],
        eth_balance: status[:eth_balance]
      }
    when 'crowdsale'
      status = get_crowdsale_contract_status(address)
      data = {
        paused: status[:paused],
        token_balance: status[:tft_balance],
        usdt_balance: status[:usdt_balance],
        eth_balance: status[:eth_balance],
        usdt_rate: status[:usdt_rate],
        eth_rate: status[:eth_rate]
      }
    when 'rewards'
      status = get_rewards_contract_status(address)
      data = {
        paused: status[:paused],
        token_balance: status[:tft_balance],
        usdt_balance: status[:usdt_balance],
        eth_balance: status[:eth_balance],
        lock_days: status[:lock_days]
      }
    else
      data = {}
    end

    data
  end

  # Определить какие поля контракта изменились
  # Возвращает: { contract_type: 'token', changed_fields: [:paused, :total_supply], old_data: {...}, new_data: {...} }
  def self.detect_changes_for_contract(contract_type)
    new_data = get_contract_data(contract_type)
    cache_key = "contract_data:#{contract_type}:latest"
    
    # Получить старые значения из кэша
    old_data = Rails.cache.read(cache_key) || {}
    
    # Сравнить и определить изменённые поля
    changed_fields = []
    new_data.each do |key, new_value|
      old_value = old_data[key]
      # Сравниваем с небольшой точностью для float значений
      if old_value.nil? || (new_value.is_a?(Float) && old_value.is_a?(Float) ? (new_value - old_value).abs > 0.0001 : new_value != old_value)
        changed_fields << key
        Rails.logger.info("[ContractService] #{contract_type}: #{key} changed from #{old_value} to #{new_value}")
      end
    end
    
    # Сохранить новые значения в кэш на 2 часа
    Rails.cache.write(cache_key, new_data, expires_in: 2.hours)
    
    {
      contract_type: contract_type,
      changed_fields: changed_fields,
      old_data: old_data,
      new_data: new_data
    }
  end

  def self.wei_to_decimal(wei_hex, decimals)
    return 0 if wei_hex.empty?
    wei_value = wei_hex.to_i(16)
    divisor = 10 ** decimals
    (wei_value.to_f / divisor).round(decimals)
  end

  def self.get_lock_days(contract_address = REWARDS_ADDRESS)
    response = call_rpc('eth_call', [
      {
        to: contract_address,
        data: encode_function_call('getContractStatus()', [])
      },
      'latest'
    ])

    return 7 if !response['result'] || response['result'].empty?

    result_hex = response['result'].to_s.sub(/^0x/, '')
    # getContractStatus returns (tftBalance, totalAllocated, totalClaimed, ethBalance, usdtBalance, currentLockDays, isPaused)
    # Each value is 32 bytes (64 hex chars), currentLockDays is the 6th value (offset 320 chars)
    # But we only need currentLockDays at position 5 (index 5 * 64 = 320)
    # Actually, let's extract it by calculating position
    return 7 if result_hex.length < 320 # ensure enough data
    
    # Position of currentLockDays (6th return value) = offset 5 * 64 chars
    lock_days_hex = result_hex[320..383]
    lock_days_wei = lock_days_hex.to_i(16)
    lock_days_wei
  rescue => e
    Rails.logger.error("Error getting lock days: #{e.message}")
    7 # default to 7 days
  end

  def self.encode_function_call(signature, params)
    selectors = {
      'paused()' => '5c975abb',
      'totalSupply()' => '18160ddd',
      'balanceOf(address)' => '70a08231',
      'rate()' => '2c4e722e',
      'ethRate()' => 'd2d93f90',
      'getCurrentRates()' => '4f0dd1f9',
      'getContractStatus()' => 'c032846b'
    }
    
    selector = selectors[signature] || '00000000'
    
    case signature
    when 'paused()'
      "0x#{selector}"
    when 'totalSupply()'
      "0x#{selector}"
    when 'rate()'
      "0x#{selector}"
    when 'ethRate()'
      "0x#{selector}"
    when 'getCurrentRates()'
      "0x#{selector}"
    when 'getContractStatus()'
      "0x#{selector}"
    when 'balanceOf(address)'
      encoded_param = '0' * (64 - params[0].sub(/^0x/, '').length) + params[0].sub(/^0x/, '')
      "0x#{selector}#{encoded_param}"
    else
      "0x#{selector}"
    end
  end
end
