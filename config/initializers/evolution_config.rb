# frozen_string_literal: true

# Sync Evolution API environment variables to InstallationConfig
# This allows Evolution API configuration via environment variables
# while still making them available in the Super Admin panel

Rails.application.config.after_initialize do
  # Sync if environment variables are present
  evolution_url = ENV.fetch('EVOLUTION_API_URL', nil)
  evolution_token = ENV.fetch('EVOLUTION_API_TOKEN', nil)

  next unless evolution_url.present? && evolution_token.present?

  if evolution_url.present?
    config = InstallationConfig.find_or_initialize_by(name: 'EVOLUTION_API_URL')
    if config.value.blank?
      config.value = evolution_url
      config.locked = false
      config.save
      Rails.logger.info '[EVOLUTION] Synced EVOLUTION_API_URL from environment variable'
    end
  end

  if evolution_token.present?
    config = InstallationConfig.find_or_initialize_by(name: 'EVOLUTION_API_TOKEN')
    if config.value.blank?
      config.value = evolution_token
      config.locked = false
      config.save
      Rails.logger.info '[EVOLUTION] Synced EVOLUTION_API_TOKEN from environment variable'
    end
  end
rescue StandardError => e
  Rails.logger.error "[EVOLUTION] Failed to sync environment variables: #{e.message}"
end
