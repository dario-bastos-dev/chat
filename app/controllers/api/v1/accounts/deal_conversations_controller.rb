# frozen_string_literal: true

class Api::V1::Accounts::DealConversationsController < Api::V1::Accounts::BaseController
  before_action :fetch_deal
  before_action :fetch_conversation_deal, only: [:destroy]

  def index
    @conversations = @deal.conversations
                         .includes(:contact, :inbox, :messages)
                         .order(created_at: :desc)
    render json: @conversations.map { |c| conversation_json(c) }
  end

  def create
    conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    @conversation_deal = @deal.conversation_deals.find_or_create_by!(
      conversation: conversation
    )
    render json: conversation_json(conversation), status: :created
  end

  def destroy
    @conversation_deal.destroy!
    head :ok
  end

  private

  def fetch_deal
    @deal = Current.account.deals.find(params[:deal_id])
  end

  def fetch_conversation_deal
    @conversation_deal = @deal.conversation_deals.find(params[:id])
  end

  def conversation_json(conversation)
    {
      id: conversation.id,
      display_id: conversation.display_id,
      status: conversation.status,
      created_at: conversation.created_at,
      contact: {
        id: conversation.contact&.id,
        name: conversation.contact&.name
      },
      inbox: {
        id: conversation.inbox&.id,
        name: conversation.inbox&.name,
        channel_type: conversation.inbox&.channel_type
      },
      meta: {
        sender: {
          name: conversation.contact&.name
        }
      },
      last_message: conversation.messages.last&.content&.truncate(100)
    }
  end
end
