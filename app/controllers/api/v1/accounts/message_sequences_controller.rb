class Api::V1::Accounts::MessageSequencesController < Api::V1::Accounts::BaseController
  before_action :fetch_message_sequence, only: [:show, :update, :destroy]

  def index
    @message_sequences = Current.account.message_sequences.order(:id)
  end

  def show
    head :not_found if @message_sequence.nil?
  end

  def create
    @message_sequence = Current.account.message_sequences.new(
      message_sequence_params.merge(created_by_id: current_user.id)
    )

    return render_could_not_create_error(@message_sequence.errors.messages) unless @message_sequence.save

    render :show
  end

  def update
    ActiveRecord::Base.transaction do
      @message_sequence.assign_attributes(message_sequence_params.merge(updated_by_id: current_user.id))
      @message_sequence.save!
      render :show
    rescue StandardError => e
      Rails.logger.error e
      render_could_not_create_error(@message_sequence.errors.messages)
    end
  end

  def destroy
    @message_sequence.destroy!
    head :ok
  end

  private

  def message_sequence_params
    params.permit(
      :name, :activation_type, :activation_tag, :inbox_scope, :active,
      :macro_id, :macro_execution_time, :restrict_execution_time, :execution_start_hour, :execution_end_hour,
      steps_attributes: [:id, :position, :step_type, :content, :wait_time, :file, :macro_id, :_destroy, template_params: {}],
      inbox_ids: []
    )
  end

  def fetch_message_sequence
    @message_sequence = Current.account.message_sequences.find_by!(id: params[:id])
  end
end
