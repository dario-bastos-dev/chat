# frozen_string_literal: true

# Sync Evolution GO API environment variables to InstallationConfig
# This allows Evolution GO API configuration via environment variables
# while still making them available in the Super Admin panel

Rails.application.config.after_initialize do
  evolutiongo_url = ENV.fetch('EVOLUTIONGO_API_URL', nil)
  evolutiongo_token = ENV.fetch('EVOLUTIONGO_API_TOKEN', nil)

  next unless evolutiongo_url.present? || evolutiongo_token.present?

  if evolutiongo_url.present?
    config = InstallationConfig.find_or_initialize_by(name: 'EVOLUTIONGO_API_URL')
    if config.value.blank?
      config.value = evolutiongo_url
      config.locked = false
      config.save
      Rails.logger.info '[EVOLUTION_GO] Synced EVOLUTIONGO_API_URL from environment variable'
    end
  end

  if evolutiongo_token.present?
    config = InstallationConfig.find_or_initialize_by(name: 'EVOLUTIONGO_API_TOKEN')
    if config.value.blank?
      config.value = evolutiongo_token
      config.locked = false
      config.save
      Rails.logger.info '[EVOLUTION_GO] Synced EVOLUTIONGO_API_TOKEN from environment variable'
    end
  end
rescue StandardError => e
  Rails.logger.error "[EVOLUTION_GO] Failed to sync environment variables: #{e.message}"
end
