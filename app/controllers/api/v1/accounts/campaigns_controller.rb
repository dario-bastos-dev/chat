class Api::V1::Accounts::CampaignsController < Api::V1::Accounts::BaseController
  before_action :campaign, except: [:index, :create, :audience_estimate]
  before_action :check_authorization

  def index
    @campaigns = Current.account.campaigns
  end

  def show; end

  def create
    @campaign = Current.account.campaigns.new(campaign_params.except(:attachments))
    
    if campaign_params[:attachments].present?
      campaign_params[:attachments].each do |uploaded_file|
        Rails.logger.info "[CAMPAIGN UPLOAD] Explicitly creating and uploading blob for #{uploaded_file.original_filename}..."
        begin
          blob = ActiveStorage::Blob.create_and_upload!(
            io: uploaded_file.open,
            filename: uploaded_file.original_filename,
            content_type: uploaded_file.content_type
          )
          @campaign.attachments.attach(blob)
          Rails.logger.info "[CAMPAIGN UPLOAD] ✅ Uploaded successfully: Blob ID #{blob.id}"
        rescue => e
          Rails.logger.error "[CAMPAIGN UPLOAD] ❌ FAILED to upload: #{e.class} - #{e.message}"
        end
      end
    end

    @campaign.save!

    Campaigns::TriggerOneoffCampaignJob.perform_later(@campaign) if @campaign.one_off? && @campaign.scheduled_at <= Time.now.utc
  end

  def update
    @campaign.update!(campaign_params)
  end

  def destroy
    @campaign.destroy!
    head :ok
  end

  def audience_estimate
    target_type = params[:target_type] || 'contacts'
    label_ids = params[:label_ids] || []
    inbox_id = params[:inbox_id]

    if label_ids.blank?
      render json: { count: 0 } and return
    end

    audience_labels = Current.account.labels.where(id: label_ids).pluck(:title)
    if audience_labels.blank?
      render json: { count: 0 } and return
    end

    count = if target_type == 'conversations'
              Current.account.conversations.where(inbox_id: inbox_id, status: :open).tagged_with(audience_labels, any: true).count
            else
              Current.account.contacts.tagged_with(audience_labels, any: true).count
            end
    render json: { count: count }
  end

  private

  def campaign
    @campaign ||= Current.account.campaigns.find_by(display_id: params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(:title, :description, :message, :enabled, :trigger_only_during_business_hours, :inbox_id, :sender_id,
                                     :scheduled_at, :cadence_interval, :pause_after, :campaign_status,
                                     audience: [:type, :id, :value], trigger_rules: {}, template_params: {}, attachments: [])
  end
end
