require 'rails_helper'

RSpec.describe CannedResponse do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:short_code) }
  end

  describe 'visibility' do
    let(:account) { create(:account) }
    let(:creator) { create(:user, account: account) }
    let(:other_user) { create(:user, account: account) }
    let(:team) { create(:team, account: account) }

    after do
      Current.account = nil
    end

    it 'defaults to personal' do
      canned_response = CannedResponse.new(account: account, short_code: 'code', content: 'hello')

      expect(canned_response.visibility).to eq('personal')
    end

    it 'requires a team when visibility is team_visibility' do
      canned_response = build(:canned_response, account: account, visibility: :team_visibility, created_by_id: creator.id, team: nil)

      expect(canned_response.valid?).to be false
      expect(canned_response.errors[:team_id]).to be_present
    end

    it 'rejects a team the creator does not belong to' do
      canned_response = build(:canned_response, account: account, visibility: :team_visibility, created_by_id: creator.id, team: team)

      expect(canned_response.valid?).to be false
      expect(canned_response.errors[:team_id]).to be_present
    end

    it 'accepts a team the creator belongs to' do
      create(:team_member, team: team, user: creator)
      canned_response = build(:canned_response, account: account, visibility: :team_visibility, created_by_id: creator.id, team: team)

      expect(canned_response.valid?).to be true
    end

    describe '.with_visibility' do
      let!(:global_response) { create(:canned_response, account: account, visibility: :global) }
      let!(:own_personal_response) { create(:canned_response, account: account, visibility: :personal, created_by_id: creator.id) }
      let!(:others_personal_response) { create(:canned_response, account: account, visibility: :personal, created_by_id: other_user.id) }
      let!(:team_response) { create(:canned_response, account: account, visibility: :team_visibility, team: team) }

      it 'returns everything for an administrator' do
        admin = create(:user, account: account, role: :administrator)
        account_user = admin.account_users.find_by(account: account)
        Current.account = account

        result = CannedResponse.with_visibility(admin, account_user)

        expect(result).to include(global_response, own_personal_response, others_personal_response, team_response)
      end

      it 'returns global, own personal and team records for a member of the team' do
        create(:team_member, team: team, user: creator)
        account_user = creator.account_users.find_by(account: account)
        Current.account = account

        result = CannedResponse.with_visibility(creator, account_user)

        expect(result).to include(global_response, own_personal_response, team_response)
        expect(result).not_to include(others_personal_response)
      end

      it 'excludes team records for a non member' do
        account_user = creator.account_users.find_by(account: account)
        Current.account = account

        result = CannedResponse.with_visibility(creator, account_user)

        expect(result).not_to include(team_response)
      end
    end
  end
end
