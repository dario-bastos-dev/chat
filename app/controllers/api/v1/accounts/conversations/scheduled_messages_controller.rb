class Api::V1::Accounts::Conversations::ScheduledMessagesController < Api::V1::Accounts::Conversations::BaseController
  before_action :fetch_scheduled_message, only: [:update, :destroy]
  before_action :authorize_action

  def index
    @scheduled_messages = @conversation.scheduled_messages.order(scheduled_at: :desc)
  end

  def create
    @scheduled_message = @conversation.scheduled_messages.new(scheduled_message_params.merge(
                                                                account_id: Current.account.id,
                                                                created_by_id: Current.user.id
                                                              ))

    return render_could_not_create_error(@scheduled_message.errors.messages) unless @scheduled_message.valid?

    @scheduled_message.save!
  end

  def update
    return render_could_not_create_error(@scheduled_message.errors.messages) unless @scheduled_message.update(scheduled_message_params)

    render :create
  end

  def destroy
    @scheduled_message.destroy!
    head :ok
  end

  private

  def scheduled_message_params
    params.permit(:title, :content, :scheduled_at).tap do |whitelisted|
      whitelisted[:template_params] = params[:template_params].permit! if params[:template_params].present?
    end
  end

  def fetch_scheduled_message
    @scheduled_message = @conversation.scheduled_messages.find(params[:id])
  end

  def authorize_action
    authorize(ScheduledMessage)
  end
end
