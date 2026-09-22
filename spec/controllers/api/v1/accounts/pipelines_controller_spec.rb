require 'rails_helper'

RSpec.describe 'Pipelines API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }
  let(:stage) { pipeline.stages.find_by(stage_type: 'active') }
  let(:contact) { create(:contact, account: account) }
  let(:board_path) { "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/board" }

  describe 'GET /api/v1/accounts/{account.id}/pipelines/{id}/board' do
    before do
      create(:deal, account: account, contact: contact, pipeline: pipeline, stage: stage, assignee: agent)
      create(:deal, account: account, contact: contact, pipeline: pipeline, stage: stage, assignee: colleague)
    end

    it 'lists the assignees of every deal for an administrator' do
      get board_path, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['assignees'].pluck('id')).to contain_exactly(agent.id, colleague.id)
    end

    # O board de um agente comum so tem os negocios dele e os sem responsavel;
    # oferecer um colega no filtro sempre levaria a um board vazio.
    it 'lists only the assignees an agent can see' do
      get board_path, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['assignees'].pluck('id')).to eq([agent.id])
    end

    it 'flags when unassigned deals are visible' do
      create(:deal, account: account, contact: contact, pipeline: pipeline, stage: stage, assignee: nil)

      get board_path, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['has_unassigned']).to be(true)
    end

    it 'does not flag unassigned deals when there are none' do
      get board_path, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['has_unassigned']).to be(false)
    end

    # Com a lista calculada sobre o board filtrado, escolher um responsavel
    # sumiria com todos os outros do seletor.
    it 'keeps the full list while the board is filtered by one assignee' do
      get board_path, params: { assignee_id: agent.id }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['assignees'].pluck('id')).to contain_exactly(agent.id, colleague.id)
    end
  end
end
