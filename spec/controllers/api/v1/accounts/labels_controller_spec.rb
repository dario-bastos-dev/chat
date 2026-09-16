require 'rails_helper'

RSpec.describe 'Label API', type: :request do
  let!(:account) { create(:account) }
  let!(:label) { create(:label, account: account) }
  let!(:conversation) { create(:conversation, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/labels' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/labels"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :administrator) }

      it 'returns all the labels in account' do
        get "/api/v1/accounts/#{account.id}/labels",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include(label.title)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/labels/:id' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/labels/#{label.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'shows the contact' do
        get "/api/v1/accounts/#{account.id}/labels/#{label.id}",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include(label.title)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/labels' do
    let(:valid_params) { { label: { title: 'test' } } }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        expect { post "/api/v1/accounts/#{account.id}/labels", params: valid_params }.not_to change(Label, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'creates the contact' do
        expect do
          post "/api/v1/accounts/#{account.id}/labels", headers: admin.create_new_auth_token,
                                                        params: valid_params
        end.to change(Label, :count).by(1)

        expect(response).to have_http_status(:success)
      end

      it 'allows a regular agent to create a label' do
        agent = create(:user, account: account, role: :agent)

        expect do
          post "/api/v1/accounts/#{account.id}/labels", headers: agent.create_new_auth_token,
                                                        params: valid_params
        end.to change(Label, :count).by(1)

        expect(response).to have_http_status(:success)
        expect(Label.last.created_by_id).to eq(agent.id)
      end

      it 'returns a validation error for an invalid visibility value instead of crashing' do
        invalid_params = { label: { title: 'test', visibility: 'not-a-real-visibility' } }

        post "/api/v1/accounts/#{account.id}/labels", headers: admin.create_new_auth_token,
                                                       params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/labels/:id' do
    let(:valid_params) { { title: 'Test_2' }  }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/labels/#{label.id}",
            params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'updates the label' do
        patch "/api/v1/accounts/#{account.id}/labels/#{label.id}",
              headers: admin.create_new_auth_token,
              params: valid_params,
              as: :json

        expect(response).to have_http_status(:success)
        expect(label.reload.title).to eq('test_2')
      end

      it 'allows an agent who authored the label to update it' do
        agent = create(:user, account: account, role: :agent)
        label.update!(created_by_id: agent.id)

        patch "/api/v1/accounts/#{account.id}/labels/#{label.id}",
              headers: agent.create_new_auth_token,
              params: valid_params,
              as: :json

        expect(response).to have_http_status(:success)
        expect(label.reload.title).to eq('test_2')
      end

      it 'does not allow an agent who did not author the label to update it' do
        agent = create(:user, account: account, role: :agent)

        patch "/api/v1/accounts/#{account.id}/labels/#{label.id}",
              headers: agent.create_new_auth_token,
              params: valid_params,
              as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(label.reload.title).not_to eq('test_2')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/labels/:id' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/labels/#{label.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'deletes the label and enqueues label cleanup' do
        label_deleted_at = Time.zone.parse('2026-05-07 10:00:00 UTC')
        conversation.label_list.add(label.title)
        conversation.save!

        clear_enqueued_jobs

        travel_to(label_deleted_at) do
          expect do
            delete "/api/v1/accounts/#{account.id}/labels/#{label.id}", headers: admin.create_new_auth_token, as: :json
          end.to have_enqueued_job(Labels::RemoveAssociationsJob).with(
            label_title: label.title,
            account_id: account.id,
            label_deleted_at: label_deleted_at
          )
        end

        expect(response).to have_http_status(:ok)
        expect(Label.exists?(label.id)).to be(false)
      end

      it 'does not allow an agent who did not author the label to destroy it' do
        agent = create(:user, account: account, role: :agent)

        delete "/api/v1/accounts/#{account.id}/labels/#{label.id}", headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(Label.exists?(label.id)).to be(true)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/labels visibility scoping' do
    let(:agent) { create(:user, account: account, role: :agent) }

    it 'includes a personal label owned by the requester' do
      own_personal = create(:label, account: account, visibility: :personal, created_by_id: agent.id, title: 'own-personal')

      get "/api/v1/accounts/#{account.id}/labels", headers: agent.create_new_auth_token, as: :json

      titles = response.parsed_body['payload'].pluck('title')
      expect(titles).to include(own_personal.title)
    end

    it 'excludes a personal label owned by someone else' do
      other_agent = create(:user, account: account, role: :agent)
      others_personal = create(:label, account: account, visibility: :personal, created_by_id: other_agent.id, title: 'others-personal')

      get "/api/v1/accounts/#{account.id}/labels", headers: agent.create_new_auth_token, as: :json

      titles = response.parsed_body['payload'].pluck('title')
      expect(titles).not_to include(others_personal.title)
    end

    it 'includes a team-restricted label when the requester is on that team' do
      team = create(:team, account: account)
      create(:team_member, team: team, user: agent)
      team_label = create(:label, account: account, visibility: :team_visibility, team: team, title: 'team-label')

      get "/api/v1/accounts/#{account.id}/labels", headers: agent.create_new_auth_token, as: :json

      titles = response.parsed_body['payload'].pluck('title')
      expect(titles).to include(team_label.title)
    end

    it 'excludes a team-restricted label when the requester is not on that team' do
      team = create(:team, account: account)
      team_label = create(:label, account: account, visibility: :team_visibility, team: team, title: 'other-team-label')

      get "/api/v1/accounts/#{account.id}/labels", headers: agent.create_new_auth_token, as: :json

      titles = response.parsed_body['payload'].pluck('title')
      expect(titles).not_to include(team_label.title)
    end
  end
end
