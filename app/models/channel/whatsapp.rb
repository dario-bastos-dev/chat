# == Schema Information
#
# Table name: channel_whatsapp
#
#  id                             :bigint           not null, primary key
#  business_management_token      :text
#  message_templates              :jsonb
#  message_templates_last_updated :datetime
#  phone_number                   :string           not null
#  phone_number_health            :jsonb            not null
#  phone_number_health_checked_at :datetime
#  phone_number_health_error      :string
#  provider                       :string           default("default")
#  provider_config                :jsonb
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :integer          not null
#
# Indexes
#
#  index_channel_whatsapp_on_phone_number                    (phone_number) UNIQUE
#  index_channel_whatsapp_on_phone_number_health_checked_at  (phone_number_health_checked_at)
#

class Channel::Whatsapp < ApplicationRecord
  include Channelable
  include Reauthorizable

  self.table_name = 'channel_whatsapp'
  # `provider_config: {}` permits any nested key, which keeps the Evolution-only
  # settings (instance_id, delay_time, …) editable without listing them here.
  EDITABLE_ATTRS = [:phone_number, :provider, { provider_config: {} }].freeze
  encrypts :business_management_token if Chatwoot.encryption_configured?

  # default at the moment is 360dialog lets change later.
  PROVIDERS = %w[default whatsapp_cloud evolution evolution_go].freeze
  before_validation :ensure_webhook_verify_token

  validates :provider, inclusion: { in: PROVIDERS }
  validates :phone_number, presence: true, uniqueness: true
  validate :validate_provider_config

  after_create :sync_templates, unless: -> { evolution_provider? || evolution_go_provider? }
  after_create :create_evolution_instance, if: :evolution_provider?
  after_create :create_evolution_go_instance, if: :evolution_go_provider?
  after_update :update_evolution_settings, if: :evolution_provider?
  after_update :update_evolution_go_settings, if: :evolution_go_provider?
  after_update_commit :log_credentials_transfer, if: :saved_change_to_provider_config?
  before_destroy :teardown_webhooks, unless: -> { evolution_provider? || evolution_go_provider? }
  before_destroy :delete_evolution_instance, if: :evolution_provider?
  before_destroy :delete_evolution_go_instance, if: :evolution_go_provider?
  after_commit :setup_webhooks, on: :create, if: :should_auto_setup_webhooks?

  def name
    'Whatsapp'
  end

  # Mirrors Channel::TwilioSms#voice_enabled? so the call subsystem can duck-type across providers.
  # Meta's Calling API is available to any whatsapp_cloud inbox (embedded-signup or manual keys);
  # only 360dialog (default provider) can't reach the call APIs.
  def voice_enabled?
    voice_calling_supported? &&
      provider_config['calling_enabled'].present? &&
      account.feature_enabled?('channel_voice')
  end

  # Mutes only the incoming side of calling; default on, so only an explicit false disables inbound.
  def inbound_calls_enabled?
    provider_config['inbound_calls_enabled'] != false
  end

  # Whether this inbox can do WhatsApp calling at all. Meta's Calling API is
  # reachable by any whatsapp_cloud inbox, so 360dialog inboxes can't be toggled
  # on even though calling_enabled would persist.
  def voice_calling_supported?
    provider == 'whatsapp_cloud'
  end

  def provider_service
    case provider
    when 'whatsapp_cloud'
      Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: self)
    when 'evolution'
      Whatsapp::Providers::EvolutionService.new(whatsapp_channel: self)
    when 'evolution_go'
      Whatsapp::Providers::EvolutionGoService.new(whatsapp_channel: self)
    else
      Whatsapp::Providers::Whatsapp360DialogService.new(whatsapp_channel: self)
    end
  end

  def template_access_token
    return provider_config['api_key'] unless ChatwootApp.chatwoot_cloud? && provider_config['source'] == 'embedded_signup'

    business_management_token.presence || provider_config['api_key']
  end

  def serializable_hash(options = nil)
    super.except('business_management_token')
  end

  # Enables voice: turns calling on at Meta (idempotent), then re-registers webhooks
  # with the in-memory calling_enabled flag so the `calls` field is subscribed. The
  # flag is persisted only after registration succeeds, so a webhook failure can't
  # leave the inbox reporting voice_enabled? while the WABA isn't subscribed to calls.
  # Saved with validate: false to skip validate_provider_config's remote credential
  # re-check, which could spuriously fail and desync the flag from Meta.
  def enable_voice_calling!
    raise 'WhatsApp calling requires a whatsapp_cloud inbox' unless voice_calling_supported?
    raise 'WhatsApp calling requires the channel_voice feature' unless account.feature_enabled?('channel_voice')

    provider_service.update_calling_status('ENABLED')
    self.provider_config = provider_config.merge('calling_enabled' => true)
    webhook_setup_service.register_callback
    save!(validate: false)
  end

  # Disables voice: unsets calling_enabled (gates the call subsystem) and re-registers
  # webhooks, which drops `calls` from the subscription (best-effort, so a Meta outage
  # can't trap admins). Leaves Meta's WABA calling.status untouched.
  def disable_voice_calling!
    raise 'WhatsApp calling requires a whatsapp_cloud inbox' unless voice_calling_supported?

    self.provider_config = provider_config.merge('calling_enabled' => false)
    save!(validate: false)
    begin
      webhook_setup_service.register_callback
    rescue StandardError => e
      Rails.logger.warn "[WHATSAPP CALL] disable webhook re-subscribe failed: #{e.message}"
    end
  end

  # Whether the pending (unsaved) provider_config change drops the embedded_signup
  # source marker, i.e. this save is an embedded signup → manual setup transfer.
  def embedded_to_manual_transfer_pending?
    before, after = provider_config_change
    before&.dig('source') == 'embedded_signup' && after['source'] != 'embedded_signup'
  end

  # Templates carry the media stored locally when they were created here, so the UI can stop asking
  # for a URL on every send. Templates created straight at Meta have none and keep the old behaviour.
  #
  # This renders on the inbox list, which is the app shell, so it never raises: losing the hint only
  # brings the URL field back, while an exception would empty the sidebar. The send resolves the
  # stored media on its own regardless of what the UI knew.
  def message_templates_with_media
    templates = synced_message_templates
    return templates if templates.none? { |template| media_header_template?(template) }

    media_urls = WhatsappTemplateMedia.url_map(account_id)
    return templates if media_urls.blank?

    templates.map do |template|
      url = media_urls[[template['name'], template['language']]]
      url.present? ? template.merge('chatwoot_media_url' => url) : template
    end
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP] Could not resolve stored template media for channel #{id}: #{e.message}")
    synced_message_templates
  end

  # The column defaults to an empty hash, so a channel that never synced is not a list of templates.
  # Array.wrap would turn that default into a single blank template.
  def synced_message_templates
    message_templates.is_a?(Array) ? message_templates : []
  end

  # Most inboxes have no media template at all, so the lookup is skipped entirely for them instead of
  # querying once per inbox while the list renders.
  def media_header_template?(template)
    Array.wrap(template['components']).any? do |component|
      component['type'] == 'HEADER' && %w[IMAGE VIDEO DOCUMENT].include?(component['format'])
    end
  end

  def history_sync
    provider_config['history_sync'] || {}
  end

  # History chunks are processed concurrently, so only the history_sync key is written: rewriting the
  # whole provider_config would let one worker's stale snapshot clobber the credentials another wrote.
  # Going through SQL also skips validate_provider_config, which would re-check the token on every chunk.
  def update_history_sync!(attributes)
    payload = history_sync.merge(attributes.stringify_keys, 'updated_at' => Time.current.iso8601)
    # rubocop:disable Rails/SkipsModelValidations
    Channel::Whatsapp.where(id: id).update_all(
      ["provider_config = jsonb_set(provider_config, '{history_sync}', ?::jsonb)", payload.to_json]
    )
    # rubocop:enable Rails/SkipsModelValidations
    provider_config['history_sync'] = payload
  end

  def mark_message_templates_updated
    # rubocop:disable Rails/SkipsModelValidations
    update_column(:message_templates_last_updated, Time.zone.now)
    # rubocop:enable Rails/SkipsModelValidations
  end

  delegate :send_message, to: :provider_service
  delegate :send_template, to: :provider_service
  delegate :delete_message, to: :provider_service
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

  def evolution_go_provider?
    provider == 'evolution_go'
  end

  # Logs only the embedded signup → manual migration (the save drops the
  # embedded_signup source marker), so credential rotations on inboxes that are
  # already manual stay silent.
  def log_credentials_transfer
    before, after = saved_change_to_provider_config
    return unless before&.dig('source') == 'embedded_signup' && after['source'] != 'embedded_signup'

    Rails.logger.info("[WHATSAPP_EMBEDDED_TO_MANUAL] success account_id=#{account_id} channel_id=#{id}")
  end

  def perform_webhook_setup
    webhook_setup_service.perform
  end

  def webhook_setup_service
    Whatsapp::WebhookSetupService.new(self, provider_config['business_account_id'], provider_config['api_key'])
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

  def create_evolution_go_instance
    result = provider_service.create_instance
    unless result[:success]
      errors.add(:base, result[:error])
      throw :abort
    end
  end

  def delete_evolution_go_instance
    provider_service.delete_instance
  end

  def update_evolution_go_settings
    return unless saved_change_to_provider_config?

    Rails.logger.info '[EVOLUTION_GO CALLBACK] Provider config changed, updating settings'
    provider_service.update_settings
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO CALLBACK] Error updating settings: #{e.class} - #{e.message}"
    raise
  end

  def should_auto_setup_webhooks?
    # Only auto-setup webhooks for whatsapp_cloud provider with manual setup
    # Embedded signup calls setup_webhooks explicitly in EmbeddedSignupService
    # Evolution and Evolution GO handle their own webhook setup
    provider == 'whatsapp_cloud' && provider_config['source'] != 'embedded_signup'
  end
end
