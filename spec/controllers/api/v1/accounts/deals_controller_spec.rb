require 'rails_helper'

RSpec.describe 'Deals API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account, is_default: true) }
  let(:stage) { pipeline.stages.find_by(stage_type: 'active') }
  let(:contact) { create(:contact, account: account) }

  describe 'POST /api/v1/accounts/{account.id}/deals' do
    let(:deal_params) { { title: 'Consultoria', stage_id: stage.id, contact_id: contact.id } }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/deals", params: { deal: deal_params }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      # `value` e NOT NULL no banco, e o campo e opcional no formulario: sem
      # valor, ou com o campo em branco, o negocio nasce zerado.
      it 'creates the deal with a zero value when no value is sent' do
        post "/api/v1/accounts/#{account.id}/deals",
             params: { deal: deal_params },
             headers: admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(account.deals.last).to have_attributes(title: 'Consultoria', value: 0)
      end

      it 'creates the deal with a zero value when the value is blank' do
        post "/api/v1/accounts/#{account.id}/deals",
             params: { deal: deal_params.merge(value: '') },
             headers: admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(account.deals.last.value).to eq(0)
      end

      it 'rejects a negative value' do
        post "/api/v1/accounts/#{account.id}/deals",
             params: { deal: deal_params.merge(value: -1) },
             headers: admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(account.deals).to be_empty
      end

      # O dashboard identifica conversas pelo display_id, nunca pela chave primaria.
      it 'links the deal to the conversation sent as display_id' do
        conversation = create(:conversation, account: account, contact: contact)

        post "/api/v1/accounts/#{account.id}/deals",
             params: { deal: deal_params, conversation_id: conversation.display_id },
             headers: admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(account.deals.last.conversations).to contain_exactly(conversation)
      end

      it 'does not create the deal when the conversation is unknown' do
        post "/api/v1/accounts/#{account.id}/deals",
             params: { deal: deal_params, conversation_id: 0 },
             headers: admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:not_found)
        expect(account.deals).to be_empty
      end
    end
  end
end
