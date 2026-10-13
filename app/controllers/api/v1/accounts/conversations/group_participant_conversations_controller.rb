class Api::V1::Accounts::Conversations::GroupParticipantConversationsController < Api::V1::Accounts::Conversations::BaseController
  def create
    conversation = Whatsapp::GroupParticipantConversationService.new(
      group_conversation: @conversation,
      participant_jid: params.require(:participant_jid),
      user: Current.user
    ).perform

    render json: { id: conversation.display_id }
  end
end
