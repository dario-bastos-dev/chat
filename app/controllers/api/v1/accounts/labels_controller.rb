class Api::V1::Accounts::LabelsController < Api::V1::Accounts::BaseController
  before_action :fetch_label, except: [:index, :create]
  before_action :check_authorization, except: [:index, :create]

  rescue_from ArgumentError, with: :render_invalid_enum_value

  def index
    @labels = policy_scope(Current.account.labels)
  end

  def show; end

  def create
    @label = Current.account.labels.create!(permitted_params.merge(created_by_id: current_user.id))
  end

  def update
    @label.update!(permitted_params)
  end

  def destroy
    label_title = @label.title
    account_id = Current.account.id
    label_deleted_at = Time.current

    @label.destroy!
    Labels::RemoveAssociationsJob.perform_later(
      label_title: label_title,
      account_id: account_id,
      label_deleted_at: label_deleted_at
    )
    head :ok
  end

  private

  def fetch_label
    @label = Current.account.labels.find(params[:id])
  end

  def check_authorization
    authorize(@label)
  end

  def render_invalid_enum_value(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end

  def permitted_params
    params.require(:label).permit(:title, :description, :color, :show_on_sidebar, :visibility, :team_id)
  end
end
