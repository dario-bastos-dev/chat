require 'rails_helper'

describe MessageSequenceListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message_sequence) { create(:message_sequence, account: account) }
  let!(:conv_seq) do
    create(:conversation_message_sequence,
           conversation: conversation,
           message_sequence: message_sequence,
           waiting_interaction: true)
  end

  describe '#message_created' do
    context 'when an incoming message is created' do
      let(:message) { create(:message, conversation: conversation, account: account, message_type: :incoming) }
      let(:event) { Events::Base.new('message_created', Time.zone.now, message: message) }

      it 'updates waiting_interaction to false' do
        expect(conv_seq.waiting_interaction).to be_truthy
        listener.message_created(event)
        expect(conv_seq.reload.waiting_interaction).to be_falsey
      end
    end

    context 'when an outgoing message is created' do
      let(:message) { create(:message, conversation: conversation, account: account, message_type: :outgoing) }
      let(:event) { Events::Base.new('message_created', Time.zone.now, message: message) }

      it 'does not update waiting_interaction' do
        expect(conv_seq.waiting_interaction).to be_truthy
        listener.message_created(event)
        expect(conv_seq.reload.waiting_interaction).to be_truthy
      end
    end

    context 'when a private message is created' do
      let(:message) { create(:message, conversation: conversation, account: account, message_type: :outgoing, private: true) }
      let(:event) { Events::Base.new('message_created', Time.zone.now, message: message) }

      it 'does not update waiting_interaction' do
        expect(conv_seq.waiting_interaction).to be_truthy
        listener.message_created(event)
        expect(conv_seq.reload.waiting_interaction).to be_truthy
      end
    end
  end
end
