require 'rails_helper'

RSpec.describe Conversations::SidebarCounter do
  subject(:counts) { described_class.new(account: account, user: user).perform }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:user) { create(:user, account: account, role: :administrator) }

  describe '#perform' do
    it 'counts only open conversations' do
      create(:conversation, account: account, inbox: inbox)
      create(:conversation, account: account, inbox: inbox, status: :resolved)
      create(:conversation, account: account, inbox: inbox, status: :pending)

      expect(counts[:all_count]).to eq(1)
    end

    it 'counts conversations where the user is mentioned or participating' do
      mentioned = create(:conversation, account: account, inbox: inbox)
      participating = create(:conversation, account: account, inbox: inbox)
      create(:conversation, account: account, inbox: inbox)
      create(:mention, account: account, conversation: mentioned, user: user)
      create(:mention, account: account, conversation: participating)
      create(:conversation_participant, account: account, conversation: participating, user: user)

      expect(counts).to include(all_count: 3, mentions_count: 1, participating_count: 1)
    end

    it 'counts conversations never answered or waiting for a reply' do
      create(:conversation, account: account, inbox: inbox)
      create(:conversation, account: account, inbox: inbox, first_reply_created_at: 1.hour.ago).update!(waiting_since: nil)
      # waiting_since is set on create, so this one replied once and is waiting again
      create(:conversation, account: account, inbox: inbox, first_reply_created_at: 1.hour.ago)

      expect(counts[:unattended_count]).to eq(2)
    end

    it 'computes every count in a single query' do
      create(:conversation, account: account, inbox: inbox)
      counter = described_class.new(account: account, user: user)
      count_queries = []
      callback = ->(*, payload) { count_queries << payload[:sql] if payload[:sql].include?('COUNT(') }

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { counter.perform }

      expect(count_queries.size).to eq(1)
    end

    context 'when the user is an agent' do
      let(:user) { create(:user, account: account, role: :agent) }

      before { create(:inbox_member, user: user, inbox: inbox) }

      it 'counts only conversations from inboxes the agent belongs to' do
        create(:conversation, account: account, inbox: inbox)
        hidden = create(:conversation, account: account, inbox: create(:inbox, account: account))
        create(:mention, account: account, conversation: hidden, user: user)

        expect(counts).to eq(all_count: 1, mentions_count: 0, participating_count: 0, unattended_count: 1)
      end
    end
  end
end
