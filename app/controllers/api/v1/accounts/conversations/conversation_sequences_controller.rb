class Api::V1::Accounts::Conversations::ConversationSequencesController < Api::V1::Accounts::Conversations::BaseController
  before_action :authorize_action

  def index
    all_sequences = Current.account.message_sequences
    attached_ids = @conversation.conversation_message_sequences.pluck(:message_sequence_id)

    @sequences = all_sequences.map do |seq|
      conv_seq = @conversation.conversation_message_sequences.find_by(message_sequence_id: seq.id)
      {
        id: seq.id,
        name: seq.name,
        activation_type: seq.activation_type,
        active: seq.active,
        attached: attached_ids.include?(seq.id),
        conversation_sequence_id: conv_seq&.id,
        conversation_active: conv_seq&.active || false
      }
    end

    render json: @sequences
  end

  def create
    sequence = Current.account.message_sequences.find(params[:message_sequence_id])
    conv_seq = @conversation.conversation_message_sequences.find_or_initialize_by(message_sequence_id: sequence.id)
    conv_seq.active = true
    conv_seq.save!

    render json: { message_sequence_id: sequence.id, attached: true, conversation_active: true }, status: :ok
  end

  def destroy
    conv_seq = @conversation.conversation_message_sequences.find(params[:id])
    conv_seq.destroy!

    head :ok
  end

  private

  def authorize_action
    authorize(ConversationMessageSequence)
  end
end
