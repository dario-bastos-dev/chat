require 'rails_helper'

RSpec.describe 'Conversation sidebar counts API', type: :request do
  let(:account) { create(:account) }

  describe 'GET /api/v1/accounts/{account.id}/conversations/sidebar_counts' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations/sidebar_counts"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated agent' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:inbox) { create(:inbox, account: account) }

      before { create(:inbox_member, user: agent, inbox: inbox) }

      it 'returns the open conversation counts the agent can access' do
        create(:conversation, account: account, inbox: inbox)
        create(:conversation, account: account, inbox: create(:inbox, account: account))

        get "/api/v1/accounts/#{account.id}/conversations/sidebar_counts",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['payload']).to eq(
          'all_count' => 1, 'mentions_count' => 0, 'participating_count' => 0, 'unattended_count' => 1
        )
      end
    end
  end
end
