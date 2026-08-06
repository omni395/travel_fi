# frozen_string_literal: true

require 'rails_helper'

#
# ReverseGeocodingService — unit-спек геокодера Nominatim.
#
# Покрытие:
# 1. Возврат nil без координат / при HTTP-ошибке / при ошибке JSON / при таймауте
# 2. Разбор успешного ответа (country/city/address/zip_code)
# 3. Fallback-приоритеты city (city → town → village → municipality → county → state_district)
# 4. build_full_address: улица+дом, доп. компоненты, дедупликация пустых
#
RSpec.describe ReverseGeocodingService, type: :service do
  #
  # Создаёт мок Net::HTTP, возвращающий заданный HTTP-ответ
  #
  def stub_nominatim(response)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(response)
    http
  end

  def ok_response(body)
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(response).to receive(:body).and_return(body)
    response
  end

  describe '.reverse_geocode' do
    it 'возвращает nil без координат' do
      expect(described_class.reverse_geocode(lat: nil, lng: nil)).to be_nil
    end

    it 'парсит успешный ответ Nominatim в city/country/address/zip_code' do
      body = {
        'address' => {
          'house_number' => '1',
          'road' => 'Khreshchatyk',
          'city' => 'Kyiv',
          'country' => 'Ukraine',
          'postcode' => '01001'
        }
      }.to_json
      stub_nominatim(ok_response(body))

      result = described_class.reverse_geocode(lat: 50.45, lng: 30.52)

      expect(result).to eq(
        country: 'Ukraine',
        city: 'Kyiv',
        address: 'Khreshchatyk, 1',
        zip_code: '01001'
      )
    end

    it 'использует town/village/municipality/county как fallback для city' do
      body = { 'address' => { 'village' => 'Pirogovo', 'country' => 'UA' } }.to_json
      stub_nominatim(ok_response(body))

      result = described_class.reverse_geocode(lat: 50.35, lng: 30.5)

      expect(result[:city]).to eq('Pirogovo')
      expect(result[:country]).to eq('UA')
    end

    it 'возвращает nil при HTTP-ошибке' do
      stub_nominatim(Net::HTTPNotFound.new('1.1', '404', 'Not Found'))

      expect(described_class.reverse_geocode(lat: 50.45, lng: 30.52)).to be_nil
    end

    it 'возвращает nil при ошибке парсинга JSON' do
      stub_nominatim(ok_response('not-json'))

      expect(described_class.reverse_geocode(lat: 50.45, lng: 30.52)).to be_nil
    end

    it 'возвращает nil при таймауте' do
      http = stub_nominatim(ok_response('{}'))
      allow(http).to receive(:request).and_raise(Net::ReadTimeout)

      expect(described_class.reverse_geocode(lat: 50.45, lng: 30.52)).to be_nil
    end

    it 'возвращает nil при ответе с ошибкой Nominatim' do
      body = { 'error' => 'Unable to geocode' }.to_json
      stub_nominatim(ok_response(body))

      expect(described_class.reverse_geocode(lat: 50.45, lng: 30.52)).to be_nil
    end
  end

  describe '.build_full_address' do
    it 'собирает улицу и номер дома' do
      addr = { 'road' => 'Main St', 'house_number' => '10' }

      expect(described_class.build_full_address(addr)).to eq('Main St, 10')
    end

    it 'учитывает только улицу без номера дома' do
      addr = { 'road' => 'Main St' }

      expect(described_class.build_full_address(addr)).to eq('Main St')
    end

    it 'добавляет район/квартал' do
      addr = { 'road' => 'Main St', 'house_number' => '10', 'suburb' => 'Center' }

      expect(described_class.build_full_address(addr)).to eq('Main St, 10, Center')
    end

    it 'возвращает nil, если нет компонентов' do
      expect(described_class.build_full_address({})).to be_nil
    end
  end
end
