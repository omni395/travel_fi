# frozen_string_literal: true

require 'rails_helper'

#
# UsersController — request-спеки авторизации профиля.
#
# Регрессия FIX 2: GET /:id/edit больше не падает с
# Pundit::PolicyScopingNotPerformedError (skip_policy_scope для show/edit).
#
RSpec.describe UsersController, type: :request do
  let(:owner) { create(:user, name: 'Owner User') }
  let(:stranger) { create(:user) }
  let(:admin) { create(:user, :admin) }

  describe 'GET /users/:id (show)' do
    it '200 для владельца' do
      sign_in owner
      get user_path(id: owner)
      expect(response).to have_http_status(:ok)
    end

    it '200 для админа' do
      sign_in admin
      get user_path(id: owner)
      expect(response).to have_http_status(:ok)
    end

    it 'редирект для чужого пользователя' do
      sign_in stranger
      get user_path(id: owner)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'GET /users/:id/edit (edit)' do
    it '200 для владельца (без PolicyScopingNotPerformedError)' do
      sign_in owner
      get edit_user_path(id: owner)
      expect(response).to have_http_status(:ok)
    end

    it '200 для админа' do
      sign_in admin
      get edit_user_path(id: owner)
      expect(response).to have_http_status(:ok)
    end

    it 'редирект для чужого пользователя' do
      sign_in stranger
      get edit_user_path(id: owner)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'PATCH /users/:id (update)' do
    it 'обновляет имя владельцу и редиректит на профиль (redirect)' do
      sign_in owner
      patch update_user_path(id: owner), params: { name: 'Updated Name' }
      expect(response).to have_http_status(:found)
      # friendly_id перегенерирует slug при смене имени — редирект на актуальный профиль
      expect(response).to redirect_to(user_path(id: owner.reload))
      expect(owner.name).to eq('Updated Name')
    end

    it 'редирект для чужого пользователя (без права update)' do
      sign_in stranger
      patch update_user_path(id: owner), params: { name: 'Hacked' }
      expect(response).to have_http_status(:redirect)
      expect(owner.reload.name).to eq('Owner User')
    end

    it '422 при коротком имени (ошибка валидации)' do
      sign_in owner
      patch update_user_path(id: owner), params: { name: 'A' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(owner.reload.name).to eq('Owner User')
    end
  end
end
