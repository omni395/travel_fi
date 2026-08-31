# frozen_string_literal: true

require 'rails_helper'

#
# Ui::VoteComponent — unit-спек рендера блока голосования сообщества.
#
# Покрывает:
#   - счётчики из VoteService.tally (Hash)
#   - активное состояние юзера (is-active) и data-current-vote (для create/destroy/change)
#   - логику can_vote? НЕ блокирует гостя/worker-контекст (иначе после live-обновления
#     через VoteBroadcaster кнопки стали бы disabled у всех)
#   - наличие ConfirmDialog «забрать голос» / «изменить голос»
#
RSpec.describe Ui::VoteComponent, type: :helper do
  let(:author) { create(:user) }
  let(:voter) { create(:user) }
  let(:poi) { create(:poi, user: author, status: :approved) }
  let(:photo) { create(:photo, poi: poi, user: author) }

  # Рендер компонента вне браузера — как в broadcaster-контексте.
  def render_component(votable, current_user: nil)
    ApplicationController.render(
      described_class.new(votable: votable, current_user: current_user),
      layout: false
    )
  end

  describe 'рендер POI' do
    context 'без голосов' do
      it 'показывает нулевые счётчики и не падает (регрессия delegate→Hash)' do
        html = render_component(poi)

        expect(html).to include('mdi-thumb-up-outline')
        expect(html).to include('mdi-thumb-down-outline')
        expect(html).to include('>0</span>')
      end

      it 'рендерит таргет-селектор votable id на корне' do
        html = render_component(poi)
        expect(html).to include("data-vote-component-votable-id-value=\"#{poi.id}\"")
        expect(html).to include('value="Poi"')
      end

      it 'рендерит счётчики с data-vote-counter (для broadcast text_content)' do
        html = render_component(poi)
        expect(html).to include('data-vote-counter="up"')
        expect(html).to include('data-vote-counter="down"')
        expect(html).to include('data-vote-counter="hint"')
      end
    end

    context 'с голосами' do
      it 'отображает счётчики ups/downs из VoteService.tally (Hash)' do
        create(:vote, votable: poi, user: create(:user), value: 1)
        create(:vote, votable: poi, user: create(:user), value: 1)
        create(:vote, votable: poi, user: create(:user), value: -1)

        html = render_component(poi)

        expect(html).to include('>2</span>')  # ups
        expect(html).to include('>1</span>')  # downs
      end
    end

    context 'активное состояние юзера' do
      it 'выделяет активную кнопку апрува и ставит data-current-vote=1, если юзер голосовал +1' do
        create(:vote, votable: poi, user: voter, value: 1)

        html = render_component(poi, current_user: voter)

        expect(html).to include('is-active')
        expect(html).to include('data-vote-component-current-vote-value="1"')
      end

      it 'напротив — data-current-vote=-1 без is-active при дизлайке' do
        create(:vote, votable: poi, user: voter, value: -1)

        html = render_component(poi, current_user: voter)

        expect(html).to include('data-vote-component-current-vote-value="-1"')
      end

      it 'никто не голосовал — кнопки без is-active, data-current-vote пуст' do
        html = render_component(poi, current_user: voter)
        expect(html).not_to include('is-active')
        expect(html).to include('data-vote-component-current-vote-value=""')
      end
    end

    context 'автор (can_vote? = false)' do
      it 'кнопки disabled для автора' do
        html = render_component(poi, current_user: author)
        expect(html).to include('disabled')
      end
    end

    context 'гость' do
      it 'кнопки НЕ disabled (блокирует только Pundit на бэке)' do
        html = render_component(poi, current_user: nil)
        expect(html).not_to include('disabled')
      end
    end

    context 'ConfirmDialog' do
      it 'рендерит диалоги «забрать голос» и «изменить голос»' do
        html = render_component(poi, current_user: voter)

        expect(html).to include('confirmDialogConfirmed')
        expect(html).to include('onRemoveConfirmed')
        expect(html).to include('onChangeConfirmed')
        expect(html).to include('removeDialog')
        expect(html).to include('changeDialog')
      end
    end
  end

  describe 'рендер Photo (галерея)' do
    it 'рендерит счётчики и таргет photo-<id>, не падает' do
      html = render_component(photo)

      expect(html).to include("data-vote-component-votable-id-value=\"#{photo.id}\"")
      expect(html).to include('value="Photo"')
      expect(html).to include('mdi-thumb-up-outline')
    end

    it 'для юзера (не автора) кнопки активны' do
      html = render_component(photo, current_user: voter)
      expect(html).not_to include('disabled')
    end

    it 'для автора фото disabled' do
      html = render_component(photo, current_user: author)
      expect(html).to include('disabled')
    end
  end
end
