# frozen_string_literal: true

require 'openssl'

#
# Crypto::Ethereum — генерация Ethereum-адресов (custodial-кошельки) без внешних гемов.
#
# Стек:
#   - secp256k1 keypair — OpenSSL::PKey::EC (стандартная библиотека)
#   - keccak256 — чистая Ruby-реализация Keccak-f[1600] (Ethereum использует оригинальный
#     Keccak с доменом 0x01, НЕ SHA3-256 из OpenSSL)
#   - EIP-55 checksum — смешанный регистр по nibble-битам хэша
#
# Проверяется тест-векторами в spec/lib/crypto/ethereum_spec.rb:
#   keccak256("") = c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
#   privkey = 0x00..01 → address = 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf
#
module Crypto
  module Ethereum
    MASK64 = 0xFFFFFFFFFFFFFFFF

    # Порядок группы secp256k1 (для ECDSA-подписи EVM-транзакций).
    SECP256K1_ORDER = 115792089237316195423570985008687907852837564279074904382605163141518161494337

    # Сдвиги ρ для Keccak-f[1600], порядок индекса x + 5*y (x — первый индекс).
    ROTATION_OFFSETS = [
      0, 1, 62, 28, 27,
      36, 44, 6, 55, 20,
      3, 10, 43, 25, 39,
      41, 45, 15, 21, 8,
      18, 2, 61, 56, 14
    ].freeze

    # Раундовые константы ι (Keccak-f[1600]).
    ROUND_CONSTANTS = [
      0x0000000000000001, 0x0000000000008082, 0x800000000000808a,
      0x8000000080008000, 0x000000000000808b, 0x0000000080000001,
      0x8000000080008081, 0x8000000000008009, 0x000000000000008a,
      0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
      0x000000008000808b, 0x800000000000008b, 0x8000000000008089,
      0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
      0x000000000000800a, 0x800000008000000a, 0x8000000080008081,
      0x8000000000008080, 0x0000000080000001, 0x8000000080008008
    ].freeze

    # Скорость (rate) для Keccak-256: 1088 бит = 136 байт на блок.
    RATE = 136

    class << self
      #
      # Возвращает keccak256-хэш входных данных как hex-строку (64 символа).
      #
      # @param data [String] входные байты
      # @return [String] hex-дайджест (64 символа, нижний регистр)
      #
      def keccak256(data)
        keccak256_bytes(data).unpack1('H*')
      end

      #
      # Возвращает keccak256-хэш входных данных как сырые байты (32 байта).
      #
      # @param data [String] входные байты
      # @return [String] 32-байтовый дайджест
      #
      def keccak256_bytes(data)
        # Padding для Keccak (домен 0x01): data || 0x01 || 0x00... || 0x80
        padded = +data.b
        padded << "\x01".b
        padded << "\x00".b while (padded.bytesize % RATE) != (RATE - 1)
        padded << "\x80".b

        state = Array.new(25, 0)
        padded.bytes.each_slice(RATE) do |block|
          (0...(RATE / 8)).each do |i|
            # Little-endian: байт j → биты 8*j.
            lane = 0
            8.times { |j| lane |= (block[i * 8 + j] << (8 * j)) }
            state[i] ^= lane
          end
          keccak_f(state)
        end

        # Squeeze: первые 32 байта состояния (little-endian lanes).
        out = +''.b
        (0...(RATE / 8)).each do |i|
          out << [state[i] & MASK64].pack('Q<')
        end
        out[0, 32]
      end

      #
      # Генерирует новую пару ключей: приватный ключ (32 байта) и EIP-55 адрес.
      #
      # @return [Array(String, String)] [private_key_bytes, address_hex]
      #
      def generate_keypair
        key = OpenSSL::PKey::EC.generate('secp256k1')
        private_key = key.private_key.to_s(16).rjust(64, '0')
        public_key = key.public_key.to_octet_string(:uncompressed)

        [[private_key].pack('H*'), address_from_public_key(public_key)]
      end

      #
      # Возвращает EIP-55 адрес для приватного ключа (hex, 64 символа, без 0x).
      #
      # @param private_key_hex [String] приватный ключ в hex (64 символа)
      # @return [String] EIP-55 адрес (0x + 40 символов)
      #
      def address_from_private_key(private_key_hex)
        group = OpenSSL::PKey::EC::Group.new('secp256k1')
        # OpenSSL 3: ключи immutable — публичную точку получаем скалярным умножением генератора.
        point = group.generator.mul(OpenSSL::BN.new(private_key_hex, 16))

        address_from_public_key(point.to_octet_string(:uncompressed))
      end

      #
      # Возвращает EIP-55 адрес из публичного ключа (65 байт, uncompressed).
      #
      # @param public_key_octets [String] публичный ключ в uncompressed-представлении
      # @return [String] EIP-55 адрес (0x + 40 символов)
      #
      def address_from_public_key(public_key_octets)
        digest = keccak256_bytes(public_key_octets[1..]) # без префикса 0x04
        eip55_checksum(digest[-20, 20].unpack1('H*'))
      end

      # ===== Подпись EVM-транзакций (EIP-155) =====

      #
      # Подписывает и RLP-кодирует транзакцию EIP-155.
      # Возвращает сырую подписанную транзакцию (hex) и её tx_hash.
      #
      # @param private_key_hex [String] приватный ключ (64 hex, без 0x)
      # @param nonce [Integer] nonce отправителя
      # @param gas_price [Integer] цена газа (wei)
      # @param gas [Integer] лимит газа
      # @param to [String] адрес получателя (0x + 40 hex)
      # @param value [Integer] сумма (wei)
      # @param data [String] calldata (0x + hex)
      # @param chain_id [Integer] id сети (EIP-155)
      # @return [Hash] { raw: String, tx_hash: String }
      #
      def sign_transaction(private_key_hex:, nonce:, gas_price:, gas:, to:, value:, data:, chain_id:)
        d = private_key_hex.to_i(16)
        to_bytes = address_to_bytes(to)
        data_bytes = hex_to_bytes(data)

        unsigned = rlp_encode([ nonce, gas_price, gas, to_bytes, value, data_bytes, chain_id, 0, 0 ])
        msg_hash = keccak256(unsigned)
        r, s, parity = ecdsa_sign(msg_hash, d)

        # EIP-155: v = chain_id * 2 + 35 + parity
        v = chain_id * 2 + 35 + parity
        raw = rlp_encode([ nonce, gas_price, gas, to_bytes, value, data_bytes, v, r, s ])

        { raw: raw.unpack1('H*'), tx_hash: "0x#{keccak256(raw)}" }
      end

      #
      # Кодирует объект в RLP (рекурсивно): Integer / String(байты) / Array.
      #
      # @param obj [Integer, String, Array] объект
      # @return [String] RLP-байты
      #
      def rlp_encode(obj)
        case obj
        when Integer
          rlp_encode_integer(obj)
        when String
          rlp_encode_bytes(obj.b)
        when Array
          payload = obj.map { |o| rlp_encode(o) }.join
          rlp_length_encode(payload.b, payload.bytesize, 0xc0, 0xf7)
        else
          raise ArgumentError, "Unsupported RLP type: #{obj.class}"
        end
      end

      #
      # Возвращает 4-байтовый selector функции по сигнатуре (Solidity ABI).
      #
      # @param signature [String] сигнатура (например "mint(address,uint256)")
      # @return [String] selector (8 hex-символов)
      #
      def function_selector(signature)
        keccak256(signature)[0, 8]
      end

      #
      # Кодирует uint256 в 32-байтовое hex-поле (Solidity ABI).
      #
      # @param value [Integer, String] значение
      # @return [String] 64 hex-символа
      #
      def encode_uint256(value)
        value.to_i.to_s(16).rjust(64, '0')
      end

      #
      # Кодирует адрес в 32-байтовое hex-поле (Solidity ABI, старшие нули).
      #
      # @param address [String] адрес (0x + 40 hex)
      # @return [String] 64 hex-символа
      #
      def encode_address(address)
        address.sub(/\A0x/, '').rjust(64, '0')
      end

      #
      # Формирует calldata вызова mint(address,uint256) на ERC-20.
      #
      # @param to [String] адрес получателя
      # @param amount_wei [Integer, String] сумма в wei
      # @return [String] calldata (0x + hex)
      #
      def encode_mint_data(to, amount_wei)
        "0x#{function_selector('mint(address,uint256)')}#{encode_address(to)}#{encode_uint256(amount_wei)}"
      end

      #
      # Формирует calldata вызова transfer(address,uint256) на ERC-20
      # (начисления из reward pool: токены берутся с баланса контракта).
      #
      # @param to [String] адрес получателя
      # @param amount_wei [Integer, String] сумма в wei
      # @return [String] calldata (0x + hex)
      #
      def encode_transfer_data(to, amount_wei)
        "0x#{function_selector('transfer(address,uint256)')}#{encode_address(to)}#{encode_uint256(amount_wei)}"
      end

      #
      # Формирует calldata вызова balanceOf(address) на ERC-20 для eth_call
      # (чтение on-chain баланса контракта, напр. reward pool).
      #
      # @param address [String] адрес аккаунта/контракта
      # @return [String] calldata (0x + hex)
      #
      def encode_balance_data(address)
        "0x#{function_selector('balanceOf(address)')}#{encode_address(address)}"
      end

      #
      # Подписывает keccak256-хэш сообщения по ECDSA (secp256k1).
      # Возвращает [r, s, parity]; s нормализован к low-s (EIP-2), parity согласована.
      #
      # @param msg_hash_hex [String] хэш сообщения (64 hex)
      # @param private_key_int [Integer] приватный ключ
      # @return [Array(Integer, Integer, Integer)] [r, s, parity]
      #
      def ecdsa_sign(msg_hash_hex, private_key_int)
        n = SECP256K1_ORDER
        e = msg_hash_hex.to_i(16)
        group = OpenSSL::PKey::EC::Group.new('secp256k1')
        generator = group.generator

        loop do
          k = SecureRandom.random_number(n - 1) + 1
          point = generator.mul(OpenSSL::BN.new(k.to_s, 10))
          # OpenSSL::PKey::EC::Point в Ruby 3.4 не имеет методов #x/#y —
          # координаты извлекаем из uncompressed-сериализации (0x04 || X(32) || Y(32)).
          octet = point.to_octet_string(:uncompressed)
          x = octet.byteslice(1, 32).unpack1('H*').to_i(16)
          y = octet.byteslice(33, 32).unpack1('H*').to_i(16)
          r = x % n
          next if r.zero?

          # Модульная инверсия по малой теореме Ферма (n — простое).
          s = (k.pow(n - 2, n) * (e + (r * private_key_int))) % n
          next if s.zero?

          parity = y.odd? ? 1 : 0
          if s > n / 2
            s = n - s
            parity = 1 - parity
          end
          return [ r, s, parity ]
        end
      end

      private

      #
      # Кодирует целое число в RLP-байты (0 → пустая строка 0x80).
      #
      # @param value [Integer] значение
      # @return [String] RLP-байты
      #
      def rlp_encode_integer(value)
        return "\x80".b if value.zero?

        hex = value.to_s(16)
        hex = "0#{hex}" if hex.length.odd?
        rlp_encode_bytes([ hex ].pack('H*'))
      end

      #
      # Кодирует строку байт в RLP (правило для строк).
      #
      # @param bytes [String] байты
      # @return [String] RLP-байты
      #
      def rlp_encode_bytes(bytes)
        len = bytes.bytesize
        return bytes if len == 1 && bytes.getbyte(0) < 0x80
        return (0x80 + len).chr.b + bytes if len <= 55

        len_bytes = length_to_bytes(len)
        (0xb7 + len_bytes.bytesize).chr.b + len_bytes + bytes
      end

      #
      # Кодирует payload (строка/список) с префиксом длины (0x80/0xb7 или 0xc0/0xf7).
      #
      # @param payload [String] байты payload
      # @param len [Integer] длина payload
      # @param prefix_small [Integer] префикс для len <= 55
      # @param prefix_long [Integer] префикс для длинных payload
      # @return [String] RLP-байты
      #
      def rlp_length_encode(payload, len, prefix_small, prefix_long)
        return (prefix_small + len).chr.b + payload if len <= 55

        len_bytes = length_to_bytes(len)
        (prefix_long + len_bytes.bytesize).chr.b + len_bytes + payload
      end

      #
      # Представляет длину в виде байт (минимальное big-endian представление).
      #
      # @param len [Integer] длина
      # @return [String] байты длины
      #
      def length_to_bytes(len)
        hex = len.to_s(16)
        hex = "0#{hex}" if hex.length.odd?
        [ hex ].pack('H*')
      end

      #
      # Преобразует адрес (0x + 40 hex) в 20 байт.
      #
      # @param address [String, nil] адрес
      # @return [String] 20 байт (пустая строка для nil)
      #
      def address_to_bytes(address)
        return "".b if address.blank?

        [ address.sub(/\A0x/, '').rjust(40, '0') ].pack('H*')
      end

      #
      # Преобразует hex-строку (опц. с 0x) в байты.
      #
      # @param hex [String, nil] hex
      # @return [String] байты
      #
      def hex_to_bytes(hex)
        return "".b if hex.blank?

        clean = hex.sub(/\A0x/, '')
        clean = "0#{clean}" if clean.length.odd?
        [ clean ].pack('H*')
      end

      #
      # Применяет EIP-55 checksum к 40-символьному hex-адресу (нижний регистр).
      #
      # @param address_hex [String] адрес без 0x, нижний регистр
      # @return [String] EIP-55 адрес с 0x
      #
      def eip55_checksum(address_hex)
        lower = address_hex.downcase
        hash = keccak256(lower)
        result = lower.chars.each_with_index.map do |ch, i|
          if ch =~ /[0-9]/
            ch
          else
            hash[i].to_i(16) >= 8 ? ch.upcase : ch
          end
        end.join
        "0x#{result}"
      end

      #
      # Один раунд перестановки Keccak-f[1600] (θ, ρ+π, χ, ι).
      #
      # @param state [Array<Integer>] 25 лейн по 64 бита (мутируется)
      #
      def keccak_f(state)
        24.times do |round|
          # θ
          c = Array.new(5, 0)
          5.times { |x| c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20] }
          5.times do |x|
            d = c[(x + 4) % 5] ^ rol64(c[(x + 1) % 5], 1)
            5.times { |y| state[x + 5 * y] ^= d }
          end

          # ρ + π: B[row=y][col=(2x+3y)%5] → плоский индекс y + 5*col.
          b = Array.new(25, 0)
          5.times do |x|
            5.times do |y|
              b[y + 5 * ((2 * x + 3 * y) % 5)] = rol64(state[x + 5 * y], ROTATION_OFFSETS[x + 5 * y])
            end
          end

          # χ
          5.times do |x|
            5.times do |y|
              state[x + 5 * y] = b[x + 5 * y] ^ ((~b[(x + 1) % 5 + 5 * y]) & b[(x + 2) % 5 + 5 * y])
            end
          end

          # ι
          state[0] ^= ROUND_CONSTANTS[round]
        end
      end

      #
      # Циклический сдвиг 64-битного значения влево.
      #
      # @param value [Integer] значение
      # @param shift [Integer] сдвиг (0..63)
      # @return [Integer] сдвинутое значение (модуль 2^64)
      #
      def rol64(value, shift)
        shift %= 64
        ((value << shift) | (value >> (64 - shift))) & MASK64
      end
    end
  end
end
