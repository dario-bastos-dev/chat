require 'rails_helper'

RSpec.describe MessageSequences::ProcessJob, type: :job do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :open) }
  let(:message_sequence) { create(:message_sequence, account: account) }
  let!(:step_1) { create(:message_sequence_step, message_sequence: message_sequence, position: 1, wait_time: "0:00:00:05") } # 5 segundos
  let!(:conv_seq) do
    create(:conversation_message_sequence,
           conversation: conversation,
           message_sequence: message_sequence,
           created_at: 10.seconds.ago,
           current_step: step_1)
  end

  describe '#perform' do
    context 'when the conversation messaging window is open' do
      before do
        allow_any_instance_of(Conversation).to receive(:can_reply?).and_return(true)
      end

      it 'executes the step, creates the outgoing message, and advances current_step' do
        expect {
          described_class.new.perform
        }.to change(conversation.messages, :count).by(1)

        last_message = conversation.messages.last
        expect(last_message.message_type).to eq('outgoing')
        expect(last_message.private).to be_falsey
        expect(last_message.content).to eq(step_1.content)

        expect(conv_seq.reload.current_step).to be_nil
        expect(conv_seq.waiting_interaction).to be_falsey
      end
    end

    context 'when the conversation messaging window is closed' do
      before do
        allow_any_instance_of(Conversation).to receive(:can_reply?).and_return(false)
      end

      it 'pauses the sequence, sets waiting_interaction to true, and creates a private note explaining the pause' do
        expect {
          described_class.new.perform
        }.to change(conversation.messages, :count).by(1)

        last_message = conversation.messages.last
        expect(last_message.message_type).to eq('outgoing')
        expect(last_message.private).to be_truthy # Nota privada
        expect(last_message.content).to include('was temporarily suspended')

        # A sequência deve estar pausada (waiting_interaction: true) e o passo NÃO deve ter avançado
        expect(conv_seq.reload.waiting_interaction).to be_truthy
        expect(conv_seq.current_step).to eq(step_1)
      end
    end

    context 'when the sequence link is already in waiting_interaction status' do
      before do
        conv_seq.update!(waiting_interaction: true)
        allow_any_instance_of(Conversation).to receive(:can_reply?).and_return(true)
      end

      it 'does not process the sequence link' do
        expect {
          described_class.new.perform
        }.not_to change(conversation.messages, :count)

        expect(conv_seq.reload.current_step).to eq(step_1)
        expect(conv_seq.waiting_interaction).to be_truthy
      end
    end

    context 'when the step type is execute_macro' do
      let(:macro) { create(:macro, account: account) }
      
      before do
        step_1.update!(step_type: :execute_macro, macro: macro, content: nil)
      end

      it 'executes the macro, does not create an outgoing message, and advances current_step when window is open' do
        allow_any_instance_of(Conversation).to receive(:can_reply?).and_return(true)
        execution_service = double
        expect(Macros::ExecutionService).to receive(:new).with(macro, conversation, anything).and_return(execution_service)
        expect(execution_service).to receive(:perform)

        expect {
          described_class.new.perform
        }.not_to change(conversation.messages, :count)

        expect(conv_seq.reload.current_step).to be_nil
        expect(conv_seq.waiting_interaction).to be_falsey
      end

      it 'executes the macro even when the conversation messaging window is closed' do
        allow_any_instance_of(Conversation).to receive(:can_reply?).and_return(false)
        execution_service = double
        expect(Macros::ExecutionService).to receive(:new).with(macro, conversation, anything).and_return(execution_service)
        expect(execution_service).to receive(:perform)

        expect {
          described_class.new.perform
        }.not_to change(conversation.messages, :count)

        # Não deve pausar a sequência e deve avançar o passo
        expect(conv_seq.reload.current_step).to be_nil
        expect(conv_seq.waiting_interaction).to be_falsey
      end

      it 'nullifies macro_id in step when the macro is deleted' do
        expect(step_1.macro_id).to eq(macro.id)
        macro.destroy!
        expect(step_1.reload.macro_id).to be_nil
      end

      it 'creates a private note and advances current_step when the macro has been deleted' do
        macro.destroy!
        step_1.reload
        allow_any_instance_of(Conversation).to receive(:can_reply?).and_return(true)

        expect {
          described_class.new.perform
        }.to change(conversation.messages, :count).by(1)

        last_message = conversation.messages.last
        expect(last_message.message_type).to eq('outgoing')
        expect(last_message.private).to be_truthy
        expect(last_message.content).to include('tried to execute a macro that has been deleted')

        expect(conv_seq.reload.current_step).to be_nil
      end
    end

    context 'when the step type is send_template' do
      let(:template_params) do
        {
          'name' => 'hello_world',
          'namespace' => 'ns1',
          'language' => 'en',
          'processed_params' => {
            '1' => '{{ contact.name }}'
          }
        }
      end

      before do
        allow_any_instance_of(Conversation).to receive(:can_reply?).and_return(false)
        step_1.update!(step_type: :send_template, template_params: template_params, content: nil)
      end

      it 'executes and processes liquid variables even when the messaging window is closed' do
        expect_any_instance_of(Whatsapp::LiquidTemplateProcessorService).to receive(:process_template_params)
          .with(template_params)
          .and_call_original

        expect {
          described_class.new.perform
        }.to change(conversation.messages, :count).by(1)

        last_message = conversation.messages.last
        expect(last_message.message_type).to eq('outgoing')
        expect(last_message.private).to be_falsey
        
        expected_params = {
          'name' => 'hello_world',
          'namespace' => 'ns1',
          'language' => 'en',
          'processed_params' => {
            '1' => conversation.contact.name
          }
        }
        expect(last_message.additional_attributes['template_params']).to eq(expected_params)
        expect(conv_seq.reload.current_step).to be_nil
      end
    end
  end
end
