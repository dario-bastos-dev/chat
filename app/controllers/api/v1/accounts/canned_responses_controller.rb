class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_canned_response, only: [:update, :destroy]

  def index
    render json: canned_responses.map { |cr| canned_response_json(cr) }
  end

  def create
    @canned_response = Current.account.canned_responses.new(canned_response_params)
    @canned_response.save!
    render json: canned_response_json(@canned_response)
  end

  def update
    @canned_response.file.purge if params[:remove_file].present? && @canned_response.file.attached?
    @canned_response.update!(canned_response_params)
    render json: canned_response_json(@canned_response)
  end

  def destroy
    @canned_response.destroy!
    head :ok
  end

  private

  def fetch_canned_response
    @canned_response = Current.account.canned_responses.find(params[:id])
  end

  def canned_response_params
    params.require(:canned_response).permit(:short_code, :content, :file)
  end

  def canned_response_json(cr)
    json = cr.as_json(only: [:id, :short_code, :content, :account_id, :created_at, :updated_at])
    if cr.file.attached?
      json['file_url'] = url_for(cr.file)
      json['file_name'] = cr.file.filename.to_s
      json['file_content_type'] = cr.file.content_type
      json['file_signed_id'] = cr.file.blob.signed_id
      json['file_size'] = cr.file.blob.byte_size
    end
    json
  end

  def canned_responses
    if params[:search]
      Current.account.canned_responses
             .where('short_code ILIKE :search OR content ILIKE :search', search: "%#{params[:search]}%")
             .order_by_search(params[:search])

    else
      Current.account.canned_responses
    end
  end
end
