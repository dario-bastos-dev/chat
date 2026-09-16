require 'rails_helper'

RSpec.describe 'Canned Responses API', type: :request do
  let(:account) { create(:account) }

  before do
    create(:canned_response, account: account, content: 'Hey {{ contact.name }}, Thanks for reaching out', short_code: 'name-short-code')
  end

  describe 'GET /api/v1/accounts/{account.id}/canned_responses' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/canned_responses"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'returns all the canned responses' do
        get "/api/v1/accounts/#{account.id}/canned_responses",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(account.canned_responses.as_json)
      end

      it 'returns all the canned responses the user searched for' do
        cr1 = account.canned_responses.first
        create(:canned_response, account: account, content: 'Great! Looking forward', short_code: 'short-code')
        cr2 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'content-with-thanks')
        cr3 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'Thanks')

        params = { search: 'thanks' }

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(
          [cr3, cr2, cr1].as_json
        )
      end

      it 'includes a personal canned response owned by the requester' do
        own_personal = create(:canned_response, account: account, visibility: :personal, created_by_id: agent.id, short_code: 'own-personal')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response.parsed_body.pluck('id')).to include(own_personal.id)
      end

      it 'excludes a personal canned response owned by someone else' do
        other_agent = create(:user, account: account, role: :agent)
        others_personal = create(:canned_response, account: account, visibility: :personal, created_by_id: other_agent.id, short_code: 'others-personal')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response.parsed_body.pluck('id')).not_to include(others_personal.id)
      end

      it 'includes a team-restricted canned response when the requester is on that team' do
        team = create(:team, account: account)
        create(:team_member, team: team, user: agent)
        team_response = create(:canned_response, account: account, visibility: :team_visibility, team: team, short_code: 'team-response')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response.parsed_body.pluck('id')).to include(team_response.id)
      end

      it 'excludes a team-restricted canned response when the requester is not on that team' do
        team = create(:team, account: account)
        team_response = create(:canned_response, account: account, visibility: :team_visibility, team: team, short_code: 'other-team-response')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response.parsed_body.pluck('id')).not_to include(team_response.id)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/canned_responses' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/canned_responses"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'creates a new canned response' do
        params = { short_code: 'short', content: 'content' }

        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(account.canned_responses.count).to eq(2)
      end

      it 'returns a validation error for an invalid visibility value instead of crashing' do
        params = { short_code: 'short', content: 'content', visibility: 'not-a-real-visibility' }

        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/canned_responses/:id' do
    let(:canned_response) { CannedResponse.last }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'updates the canned response when the agent is the author' do
        canned_response.update!(created_by_id: agent.id)
        params = { short_code: 'B' }

        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(canned_response.reload.short_code).to eq('B')
      end

      it 'does not allow an agent who is not the author to update it' do
        params = { short_code: 'B' }

        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(canned_response.reload.short_code).not_to eq('B')
      end

      it 'allows an administrator to update any canned response' do
        params = { short_code: 'B' }

        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
            params: params,
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(canned_response.reload.short_code).to eq('B')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/canned_responses/:id' do
    let(:canned_response) { CannedResponse.last }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'destroys the canned response when the agent is the author' do
        canned_response.update!(created_by_id: agent.id)

        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:success)
        expect(CannedResponse.count).to eq(0)
      end

      it 'does not allow an agent who is not the author to destroy it' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(CannedResponse.count).to eq(1)
      end

      it 'allows an administrator to destroy any canned response' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
               headers: admin.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:success)
        expect(CannedResponse.count).to eq(0)
      end
    end
  end
end
