# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CustomAttributeDefinition do
  let(:account) { create(:account) }

  describe 'validations' do
    describe 'attribute_key format' do
      it 'allows alphanumeric keys with underscores' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: 'order_date_1')
        expect(cad).to be_valid
      end

      it 'allows hyphens and dots' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: 'order-date.v2')
        expect(cad).to be_valid
      end

      it 'allows Unicode letters' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: '客户类型')
        expect(cad).to be_valid
      end

      it 'rejects keys with single quotes' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: "x'||(SELECT 1)||'")
        expect(cad).not_to be_valid
        expect(cad.errors[:attribute_key]).to be_present
      end

      it 'rejects keys with spaces' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: 'order date')
        expect(cad).not_to be_valid
      end

      it 'rejects keys with semicolons' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: 'key; DROP TABLE users--')
        expect(cad).not_to be_valid
      end

      it 'rejects contact attributes that conflict with the company_name contact filter' do
        cad = build(:custom_attribute_definition, account: account, attribute_model: 'contact_attribute', attribute_key: 'company_name')
        expect(cad).not_to be_valid
        expect(cad.errors[:attribute_key]).to be_present
      end

      it 'rejects keys with parentheses' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: 'key()')
        expect(cad).not_to be_valid
      end
    end
  end

  describe 'callbacks' do
    describe '#strip_attribute_key' do
      it 'strips leading and trailing whitespace from attribute_key' do
        cad = create(:custom_attribute_definition, account: account, attribute_key: '  order_date  ')
        expect(cad.attribute_key).to eq('order_date')
      end

      it 'strips leading and trailing whitespace from attribute_display_name' do
        cad = create(:custom_attribute_definition, account: account, attribute_display_name: '  Order Date  ')
        expect(cad.attribute_display_name).to eq('Order Date')
      end
    end

    describe 'widget pre-chat custom fields sync' do
      it 'syncs the pre-chat fields when a contact attribute changes or is deleted' do
        cad = create(:custom_attribute_definition, account: account, attribute_model: 'contact_attribute')

        expect { cad.update!(attribute_display_name: 'Updated') }.to have_enqueued_job(Inboxes::UpdateWidgetPreChatCustomFieldsJob)
        expect { cad.destroy! }.to have_enqueued_job(Inboxes::SyncWidgetPreChatCustomFieldsJob)
      end

      it 'does not sync the pre-chat fields for deal attributes' do
        cad = create(:custom_attribute_definition, account: account, attribute_model: 'deal_attribute')

        expect { cad.update!(attribute_display_name: 'Updated') }.not_to have_enqueued_job(Inboxes::UpdateWidgetPreChatCustomFieldsJob)
        expect { cad.destroy! }.not_to have_enqueued_job(Inboxes::SyncWidgetPreChatCustomFieldsJob)
      end
    end

    describe 'filtered unread count invalidation' do
      let(:invalidator) { instance_double(Conversations::UnreadCounts::FilteredCountInvalidator, custom_attribute_definition_changed!: true) }

      before do
        allow(Conversations::UnreadCounts::FilteredCountInvalidator).to receive(:new).with(account).and_return(invalidator)
        allow(Rails.configuration.dispatcher).to receive(:dispatch)
      end

      it 'invalidates conversation filters when a conversation custom attribute definition changes' do
        cad = create(:custom_attribute_definition, account: account, attribute_model: 'conversation_attribute')

        cad.update!(attribute_display_name: 'Updated Order Date')

        expect(invalidator).to have_received(:custom_attribute_definition_changed!).with(cad)
        expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
          'account.cache_invalidated',
          kind_of(Time),
          account: account,
          cache_keys: account.cache_keys
        )
      end

      it 'invalidates conversation filters when a conversation custom attribute definition is deleted' do
        cad = create(:custom_attribute_definition, account: account, attribute_model: 'conversation_attribute')

        cad.destroy!

        expect(invalidator).to have_received(:custom_attribute_definition_changed!).with(cad)
        expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
          'account.cache_invalidated',
          kind_of(Time),
          account: account,
          cache_keys: account.cache_keys
        )
      end

      it 'ignores contact custom attribute definition changes' do
        cad = create(:custom_attribute_definition, account: account, attribute_model: 'contact_attribute')

        cad.update!(attribute_display_name: 'Updated Contact Field')

        expect(invalidator).not_to have_received(:custom_attribute_definition_changed!)
        expect(Rails.configuration.dispatcher).not_to have_received(:dispatch)
      end
    end
  end
end
