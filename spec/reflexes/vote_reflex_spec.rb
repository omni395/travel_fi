# frozen_string_literal: true

require 'rails_helper'

#
# VoteReflex — unit-спек моста UI → Service для голосования сообщества.
#
# Покрывает регрессию: StimulusReflex 3.x передаёт объект-аргумент как
# ЕДИНЫЙ ПОЗИЦИОННЫЙ аргумент со СТРОКОВЫМИ ключами, а раньше метод
# `cast` объявлялся с keyword-аргументами (`def cast(votable_type:, ...)`),
# что давало "wrong number of arguments (given [{...}], expected [], optional [])".
# Сейчас `cast(params = {})` + `deep_symbolize_keys` + вычит ключей.
#
RSpec.describe VoteReflex, type: :reflex do
  let(:author) { create(:user) }
  let(:voter) { create(:user) }
  let(:poi) { create(:poi, user: author, status: :approved) }
  let(:photo) { create(:photo, poi: poi, user: author) }

  let(:cable_ready_mock) { build_cable_ready_mock }
  let(:sr_version) { Gem.loaded_specs['stimulus_reflex'].version.to_s }
  let(:session_mock) { {} }

  def build_cable_ready_mock
    cr = double('cable_ready')
    allow(cr).to receive(:inner_html)
    allow(cr).to receive(:remove_css_class)
    allow(cr).to receive(:add_css_class)
    allow(cr).to receive(:morph)
    allow(cr).to receive(:broadcast)
    cr
  end

  def build_reflex(user:, url: 'http://test.host/pois')
    connection = instance_double('Connection')
    allow(connection).to receive(:current_user).and_return(user)
    allow(connection).to receive(:env).and_return(
      'rack.session' => {},
      'rack.session.options' => { id: SecureRandom.hex(16) },
      'HTTP_HOST' => 'test.host',
      'rack.input' => StringIO.new('')
    )

    channel = instance_double('Channel')
    allow(channel).to receive(:connection).and_return(connection)
    allow(channel).to receive(:stream_name).and_return("user_#{user&.id}")

    element = instance_double('Element')
    allow(element).to receive(:dataset).and_return({})
    allow(element).to receive(:value).and_return('')

    reflex_data = instance_double('StimulusReflex::ReflexData')
    allow(reflex_data).to receive(:url).and_return(url)
    allow(reflex_data).to receive(:element).and_return(element)
    allow(reflex_data).to receive(:selectors).and_return([])
    allow(reflex_data).to receive(:method_name).and_return(:cast)
    allow(reflex_data).to receive(:id).and_return('reflex-vote')
    allow(reflex_data).to receive(:params).and_return({})
    allow(reflex_data).to receive(:suppress_logging).and_return(true)
    allow(reflex_data).to receive(:reflex_controller).and_return('vote')
    allow(reflex_data).to receive(:version).and_return(sr_version)
    allow(reflex_data).to receive(:npm_version).and_return(sr_version)
    allow(reflex_data).to receive(:tab_id).and_return(nil)
    allow(reflex_data).to receive(:xpath_controller).and_return(nil)
    allow(reflex_data).to receive(:xpath_element).and_return(nil)
    allow(reflex_data).to receive(:permanent_attribute_name).and_return(nil)

    reflex = described_class.new(channel, reflex_data: reflex_data)
    allow(reflex).to receive(:session).and_return(session_mock)
    allow(reflex).to receive(:cable_ready).and_return(cable_ready_mock)
    reflex
  end

  describe '#cast' do
    context 'за POI с координатами в радиусе (анти-фрод 100м)' do
      it 'делегирует в VoteService.cast! с символьными ключами и делает morph :nothing' do
        # Координаты юзера в session (в радиусе 100м от POI 50.4501,30.5234).
        session_mock[:user_lat] = 50.4501
        session_mock[:user_lng] = 30.5234

        reflex = build_reflex(user: voter)
        allow(reflex).to receive(:morph)

        expect(VoteService).to receive(:cast!).with(
          votable: poi, user: voter, value: 1, action: :create
        ).and_return([ double('vote'), :created ])

        reflex.cast({ 'votable_type' => 'Poi', 'votable_id' => poi.id, 'vote_value' => 1 })

        expect(reflex).to have_received(:morph).with(:nothing)
      end

      it 'передаёт vote_action (destroy/change) в VoteService.cast!' do
        session_mock[:user_lat] = 50.4501
        session_mock[:user_lng] = 30.5234

        reflex = build_reflex(user: voter)
        allow(reflex).to receive(:morph)

        expect(VoteService).to receive(:cast!).with(
          votable: poi, user: voter, value: -1, action: :change
        ).and_return([ double('vote'), :changed ])

        reflex.cast({
          'votable_type' => 'Poi', 'votable_id' => poi.id,
          'vote_value' => -1, 'vote_action' => 'change'
        })

        expect(reflex).to have_received(:morph).with(:nothing)
      end
    end

    context 'за POI без геолокации' do
      it 'НЕ вызывает VoteService.cast! (рендерит proximity-диалог, голос молча отбивается)' do
        reflex = build_reflex(user: voter)
        allow(reflex).to receive(:morph)

        expect(VoteService).not_to receive(:cast!)

        reflex.cast({ 'votable_type' => 'Poi', 'votable_id' => poi.id, 'vote_value' => -1 })
      end
    end

    context 'за POI автора (Pundit отклоняет)' do
      it 'НЕ вызывает VoteService.cast! и обрабатывает Pundit::NotAuthorizedError (morph :nothing)' do
        session_mock[:user_lat] = 50.4501
        session_mock[:user_lng] = 30.5234

        reflex = build_reflex(user: author)
        allow(reflex).to receive(:morph)

        # Authorize-ветка рефлекса: при NotAuthorizedError голос НЕ отправляется.
        allow(reflex).to receive(:authorize_with_pundit!).and_raise(Pundit::NotAuthorizedError.new('no'))

        expect(VoteService).not_to receive(:cast!)

        expect { reflex.cast({ 'votable_type' => 'Poi', 'votable_id' => poi.id, 'vote_value' => 1 }) }
          .not_to raise_error

        expect(reflex).to have_received(:morph).with(:nothing)
      end
    end

    context 'за Photo (галерея, без проксимити)' do
      it 'делегирует в VoteService.cast! для Photo и делает morph :nothing' do
        reflex = build_reflex(user: voter)
        allow(reflex).to receive(:morph)

        expect(VoteService).to receive(:cast!).with(
          votable: photo, user: voter, value: 1, action: :create
        ).and_return([ double('vote'), :created ])

        reflex.cast({ 'votable_type' => 'Photo', 'votable_id' => photo.id, 'vote_value' => 1 })

        expect(reflex).to have_received(:morph).with(:nothing)
      end
    end

    context 'неизвестный votable_type' do
      it 'не падает, делает morph :nothing' do
        reflex = build_reflex(user: voter)
        allow(reflex).to receive(:morph)

        expect(VoteService).not_to receive(:cast!)

        expect { reflex.cast({ 'votable_type' => 'Bogus', 'votable_id' => 1, 'vote_value' => 1 }) }
          .not_to raise_error
      end
    end
  end
end
