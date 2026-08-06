# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DealListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }
  let(:stage) { pipeline.stages.ordered.first }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  describe '#conversation_created' do
    it 'links the contact open deals to the new conversation' do
      deal = create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact)
      event = Events::Base.new('conversation.created', Time.zone.now, conversation: conversation)

      listener.conversation_created(event)

      expect(conversation.reload.deals).to include(deal)
    end
  end

  describe '#message_created' do
    let!(:linked_deals) do
      Array.new(3) do
        deal = create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact,
                             custom_attributes: { 'is_rotting' => true })
        create(:conversation_deal, conversation: conversation, deal: deal)
        deal
      end
    end

    it 'refreshes last_activity_at for every linked deal' do
      message = create(:message, account: account, inbox: inbox, conversation: conversation)

      listener.message_created(Events::Base.new('message.created', Time.zone.now, message: message))

      expect(linked_deals.map { |deal| deal.reload.last_activity_at }).to all(be_present)
    end

    it 'clears the rotting flag' do
      message = create(:message, account: account, inbox: inbox, conversation: conversation)

      listener.message_created(Events::Base.new('message.created', Time.zone.now, message: message))

      expect(linked_deals.map { |deal| deal.reload.custom_attributes['is_rotting'] }).to all(be(false))
    end

    # Roda a cada mensagem recebida: precisa ser uma query so, nao uma por negocio.
    it 'issues a single update regardless of how many deals are linked' do
      message = create(:message, account: account, inbox: inbox, conversation: conversation)
      updates = 0
      subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        updates += 1 if payload[:sql].to_s.start_with?('UPDATE "deals"')
      end

      listener.message_created(Events::Base.new('message.created', Time.zone.now, message: message))

      ActiveSupport::Notifications.unsubscribe(subscription)
      expect(updates).to eq(1)
    end
  end

  describe '#deal_created' do
    it 'enqueues auto assignment when there is no assignee' do
      deal = create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: nil)

      expect do
        listener.deal_created(Events::Base.new('deal.created', Time.zone.now, deal: deal))
      end.to have_enqueued_job(Deals::AutoAssignmentJob)
    end

    it 'skips auto assignment when the deal already has an assignee' do
      agent = create(:user)
      create(:account_user, user: agent, account: account, role: :agent)
      deal = create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: agent)

      expect do
        listener.deal_created(Events::Base.new('deal.created', Time.zone.now, deal: deal))
      end.not_to have_enqueued_job(Deals::AutoAssignmentJob)
    end
  end
end
