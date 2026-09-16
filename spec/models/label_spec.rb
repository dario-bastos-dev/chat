require 'rails_helper'

RSpec.describe Label do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
  end

  describe 'title validations' do
    it 'would not let you start title without numbers or letters' do
      label = FactoryBot.build(:label, title: '_12')
      expect(label.valid?).to be false
    end

    it 'would not let you use special characters' do
      label = FactoryBot.build(:label, title: 'jell;;2_12')
      expect(label.valid?).to be false
    end

    it 'would not allow space' do
      label = FactoryBot.build(:label, title: 'heeloo _12')
      expect(label.valid?).to be false
    end

    it 'allows foreign charactes' do
      label = FactoryBot.build(:label, title: '学中文_12')
      expect(label.valid?).to be true
    end

    it 'converts uppercase letters to lowercase' do
      label = FactoryBot.build(:label, title: 'Hello_World')
      expect(label.valid?).to be true
      expect(label.title).to eq 'hello_world'
    end

    it 'validates uniqueness of label name for account' do
      account = create(:account)
      label = FactoryBot.create(:label, account: account)
      duplicate_label = FactoryBot.build(:label, title: label.title, account: account)
      expect(duplicate_label.valid?).to be false
    end
  end

  describe 'visibility' do
    let(:account) { create(:account) }
    let(:creator) { create(:user, account: account) }
    let(:other_user) { create(:user, account: account) }
    let(:team) { create(:team, account: account) }

    it 'defaults to personal' do
      label = Label.new(account: account, title: 'default-visibility-label')

      expect(label.visibility).to eq('personal')
    end

    it 'requires a team when visibility is team_visibility' do
      label = build(:label, account: account, visibility: :team_visibility, created_by_id: creator.id, team: nil)

      expect(label.valid?).to be false
      expect(label.errors[:team_id]).to be_present
    end

    it 'clears the team when visibility is not team_visibility' do
      create(:team_member, team: team, user: creator)
      label = create(:label, account: account, visibility: :team_visibility, created_by_id: creator.id, team: team)

      label.update!(visibility: :personal)

      expect(label.reload.team_id).to be_nil
    end

    it 'rejects a team the creator does not belong to' do
      label = build(:label, account: account, visibility: :team_visibility, created_by_id: creator.id, team: team)

      expect(label.valid?).to be false
      expect(label.errors[:team_id]).to be_present
    end

    it 'accepts a team the creator belongs to' do
      create(:team_member, team: team, user: creator)
      label = build(:label, account: account, visibility: :team_visibility, created_by_id: creator.id, team: team)

      expect(label.valid?).to be true
    end

    describe '.with_visibility' do
      let!(:global_label) { create(:label, account: account, visibility: :global) }
      let!(:own_personal_label) { create(:label, account: account, visibility: :personal, created_by_id: creator.id) }
      let!(:others_personal_label) { create(:label, account: account, visibility: :personal, created_by_id: other_user.id) }

      after do
        Current.account = nil
      end

      it 'returns everything for an administrator' do
        admin = create(:user, account: account, role: :administrator)
        account_user = admin.account_users.find_by(account: account)
        Current.account = account

        result = Label.with_visibility(admin, account_user)

        expect(result).to include(global_label, own_personal_label, others_personal_label)
      end

      it 'returns global and own personal records for a regular agent' do
        account_user = creator.account_users.find_by(account: account)
        Current.account = account

        result = Label.with_visibility(creator, account_user)

        expect(result).to include(global_label, own_personal_label)
        expect(result).not_to include(others_personal_label)
      end
    end
  end

  describe '.after_update_commit' do
    let(:label) { create(:label) }

    it 'calls update job' do
      expect(Labels::UpdateJob).to receive(:perform_later).with('new-title', label.title, label.account_id)

      label.update(title: 'new-title')
    end

    it 'does not call update job if title is not updated' do
      expect(Labels::UpdateJob).not_to receive(:perform_later)

      label.update(description: 'new-description')
    end
  end
end
