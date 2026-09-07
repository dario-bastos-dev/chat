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

  describe 'POST /api/v1/accounts/{account.id}/deals/schedule_messages' do
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:deal) { create(:deal, account: account, contact: contact, pipeline: pipeline, stage: stage) }
    let(:schedule_params) do
      { title: 'Follow-up', content: 'Podemos avancar?', scheduled_at: 2.days.from_now.iso8601 }
    end

    def schedule(deal_ids, user)
      post "/api/v1/accounts/#{account.id}/deals/schedule_messages",
           params: schedule_params.merge(deal_ids: deal_ids),
           headers: user.create_new_auth_token,
           as: :json
    end

    it 'schedules one message on the primary open conversation' do
      create(:conversation_deal, conversation: conversation, deal: deal, is_primary: true)

      schedule([deal.id], admin)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['scheduled_count']).to eq(1)
      expect(conversation.scheduled_messages.pending.count).to eq(1)
      expect(conversation.scheduled_messages.last.deal_id).to eq(deal.id)
    end

    # Duas oportunidades do mesmo cliente nao podem virar duas mensagens iguais.
    it 'sends a single message per contact' do
      other_deal = create(:deal, account: account, contact: contact, pipeline: pipeline, stage: stage)
      create(:conversation_deal, conversation: conversation, deal: deal, is_primary: true)
      create(:conversation_deal, conversation: conversation, deal: other_deal, is_primary: true)

      schedule([deal.id, other_deal.id], admin)

      expect(response.parsed_body['scheduled_count']).to eq(1)
      expect(response.parsed_body['skipped_duplicate_contact'].size).to eq(1)
    end

    # O DispatchJob cancela a mensagem se a conversa nao estiver aberta, entao
    # agendar nela seria jogar a mensagem fora sem avisar ninguem.
    it 'skips a deal whose only conversation is resolved' do
      resolved = create(:conversation, account: account, inbox: inbox, contact: contact, status: :resolved)
      create(:conversation_deal, conversation: resolved, deal: deal, is_primary: true)

      schedule([deal.id], admin)

      expect(response.parsed_body['scheduled_count']).to eq(0)
      expect(response.parsed_body['skipped_without_conversation']).to eq([deal.id])
      expect(ScheduledMessage.count).to eq(0)
    end

    # O policy_scope de negocio alcanca todo negocio sem responsavel, incluindo
    # os de caixas de entrada que o agente nao acessa.
    it 'skips a conversation the agent cannot access' do
      agent = create(:user, account: account, role: :agent)
      create(:conversation_deal, conversation: conversation, deal: deal, is_primary: true)

      schedule([deal.id], agent)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['scheduled_count']).to eq(0)
      expect(response.parsed_body['skipped_unauthorized']).to eq([deal.id])
      expect(ScheduledMessage.count).to eq(0)
    end

    it 'does not schedule the same message twice' do
      create(:conversation_deal, conversation: conversation, deal: deal, is_primary: true)

      schedule([deal.id], admin)
      schedule([deal.id], admin)

      expect(response.parsed_body['skipped_already_scheduled']).to eq([deal.id])
      expect(conversation.scheduled_messages.count).to eq(1)
    end
  end
end
