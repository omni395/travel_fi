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
end
