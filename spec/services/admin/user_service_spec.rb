# frozen_string_literal: true

require 'rails_helper'

#
# Admin::UserService — unit-тесты админ-сервиса пользователей.
#
RSpec.describe Admin::UserService, type: :service do
  let(:admin) { create(:user, :admin) }

  describe '.update' do
    it 'обновляет name/status и роль' do
      user = create(:user)
      moderator_role = Role.find_or_create_by!(name: 'moderator')

      described_class.update(
        user: user,
        params: { name: 'Updated Name', status: 'suspended', role_id: moderator_role.id },
        current_user: admin
      )

      user.reload
      expect(user.name).to eq('Updated Name')
      expect(user).to be_suspended
      expect(user).to have_role(:moderator)
    end

    it 'бросает UpdateError при невалидном email' do
      user = create(:user)

      expect { described_class.update(user: user, params: { email: 'bad-email' }, current_user: admin) }
        .to raise_error(Admin::UserService::UpdateError)
    end
  end

  describe '.change_status' do
    it 'меняет статус' do
      user = create(:user)

      described_class.change_status(user: user, status: 'banned', current_user: admin)

      expect(user.reload).to be_banned
    end

    it 'не даёт менять статус удалённому' do
      user = create(:user, :suspended)
      user.update!(status: 'deleted')

      expect { described_class.change_status(user: user, status: 'active', current_user: admin) }
        .to raise_error(Admin::UserService::StatusError)
    end
  end

  describe '.destroy' do
    it 'мягко удаляет (статус deleted)' do
      user = create(:user)

      described_class.destroy(user: user, current_user: admin)

      expect(user.reload).to be_deleted
    end

    it 'не даёт удалить себя' do
      expect { described_class.destroy(user: admin, current_user: admin) }
        .to raise_error(Admin::UserService::DestroyError)
    end
  end
end
