# frozen_string_literal: true

class Ui::VoteComponentPreview < Lookbook::Preview
  # @label Default Vote Block
  def default
    render Ui::VoteComponent.new(votable: mock_poi)
  end

  private

  def mock_poi(approved: false)
    votes_mock = Object.new
    votes_mock.define_singleton_method(:where) { |_| votes_mock }
    votes_mock.define_singleton_method(:pick) { |_| nil }
    votes_mock.define_singleton_method(:exists?) { |**_| false }

    poi = Object.new
    poi.define_singleton_method(:id) { 1 }
    poi.define_singleton_method(:user_id) { 99 }
    poi.define_singleton_method(:community_approved?) { approved }
    poi.define_singleton_method(:community_rejected?) { false }
    poi.define_singleton_method(:votes) { votes_mock }
    poi.define_singleton_method(:class) { Struct.new(:name).new("Poi") }

    # Стабильная заглушка для VoteService, возвращающая Hash
    unless defined?(VoteService)
      Object.const_set(:VoteService, Module.new)
    end
    VoteService.define_singleton_method(:tally) do |_votable|
      { ups: 5, downs: 1, total: 6, net: 4 }
    end

    poi
  end
end
