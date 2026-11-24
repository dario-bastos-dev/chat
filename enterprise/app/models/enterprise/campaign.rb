module Enterprise::Campaign
  extend ActiveSupport::Concern

  # WhatsApp campaigns are sent by Whatsapp::OneoffCampaignService with its own cadence and resume from
  # processed_deliveries; the upstream cursor-based batch sending is not part of this fork.
  included do
    has_many :campaign_recipients, dependent: :delete_all
  end
end
