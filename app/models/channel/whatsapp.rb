# == Schema Information
#
# Table name: channel_whatsapp
#
#  id                             :bigint           not null, primary key
#  message_templates              :jsonb
#  message_templates_last_updated :datetime
#  phone_number                   :string           not null
#  provider                       :string           default("default")
#  provider_config                :jsonb
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :integer          not null
#
# Indexes
#
#  index_channel_whatsapp_on_phone_number  (phone_number) UNIQUE
#

class Channel::Whatsapp < ApplicationRecord
  include Channelable
  include Reauthorizable

  self.table_name = 'channel_whatsapp'
  EDITABLE_ATTRS = [:phone_number, :provider, { provider_config: [:api_key, :phone_number_id, :business_account_id, :webhook_verify_token,
                                                                  :reject_calls, :msg_call, :ignore_groups, :always_online, :read_messages,
                                                                  :read_status, :sync_full_history] }].freeze

  # default at the moment is 360dialog lets change later.
  PROVIDERS = %w[default whatsapp_cloud evolution].freeze
  before_validation :ensure_webhook_verify_token

  validates :provider, inclusion: { in: PROVIDERS }
  validates :phone_number, presence: true, uniqueness: true
  validate :validate_provider_config

  after_create :sync_templates, unless: :evolution_provider?
  after_create :create_evolution_instance, if: :evolution_provider?
  after_update :update_evolution_settings, if: :evolution_provider?
  before_destroy :teardown_webhooks, unless: :evolution_provider?
  before_destroy :delete_evolution_instance, if: :evolution_provider?

  def name
    'Whatsapp'
  end

  def provider_service
    case provider
    when 'whatsapp_cloud'
      Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: self)
    when 'evolution'
      Whatsapp::Providers::EvolutionService.new(whatsapp_channel: self)
    else
      Whatsapp::Providers::Whatsapp360DialogService.new(whatsapp_channel: self)
    end
  end

  def mark_message_templates_updated
    # rubocop:disable Rails/SkipsModelValidations
    update_column(:message_templates_last_updated, Time.zone.now)
    # rubocop:enable Rails/SkipsModelValidations
  end

  delegate :send_message, to: :provider_service
  delegate :send_template, to: :provider_service
  delegate :sync_templates, to: :provider_service
  delegate :media_url, to: :provider_service
  delegate :api_headers, to: :provider_service

  def setup_webhooks
    perform_webhook_setup
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP] Webhook setup failed: #{e.message}"
    prompt_reauthorization!
  end

  private

  def ensure_webhook_verify_token
    provider_config['webhook_verify_token'] ||= SecureRandom.hex(16) if provider == 'whatsapp_cloud'
  end

  def validate_provider_config
    errors.add(:provider_config, 'Invalid Credentials') unless provider_service.validate_provider_config?
  end

  def evolution_provider?
    provider == 'evolution'
  end

  def perform_webhook_setup
    business_account_id = provider_config['business_account_id']
    api_key = provider_config['api_key']

    Whatsapp::WebhookSetupService.new(self, business_account_id, api_key).perform
  end

  def teardown_webhooks
    Whatsapp::WebhookTeardownService.new(self).perform
  end

  def create_evolution_instance
    result = provider_service.create_instance
    unless result[:success]
      errors.add(:base, result[:error])
      throw :abort
    end
  end

  def delete_evolution_instance
    provider_service.delete_instance
  end

  def update_evolution_settings
    Rails.logger.info "[EVOLUTION CALLBACK] update_evolution_settings triggered"
    Rails.logger.info "[EVOLUTION CALLBACK] saved_change_to_provider_config? = #{saved_change_to_provider_config?}"
    
    if saved_change_to_provider_config?
      Rails.logger.info "[EVOLUTION CALLBACK] Provider config changed, calling update_settings"
      Rails.logger.info "[EVOLUTION CALLBACK] Old config: #{saved_change_to_provider_config[0]}"
      Rails.logger.info "[EVOLUTION CALLBACK] New config: #{saved_change_to_provider_config[1]}"
      
      provider_service.update_settings
    else
      Rails.logger.info "[EVOLUTION CALLBACK] No provider_config changes detected, skipping"
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION CALLBACK] Error updating settings: #{e.class} - #{e.message}\n#{e.backtrace[0..3].join("\n")}"
    raise
  end
end
