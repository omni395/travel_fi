# frozen_string_literal: true

require 'rails_helper'

#
# UserInactivityJob — unit-спек: обёртка над UserService.mark_inactive_old_users.
#
RSpec.describe UserInactivityJob, type: :job do
  it 'переводит неактивных юзеров в inactive' do
    old_user = create(:user, :active)
    old_user.versions.update_all(created_at: 7.months.ago)

    expect { described_class.perform_now }
      .to change { old_user.reload.status }.from('active').to('inactive')
  end
end
