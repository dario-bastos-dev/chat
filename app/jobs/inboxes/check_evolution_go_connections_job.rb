class Inboxes::CheckEvolutionGoConnectionsJob < ApplicationJob
  queue_as :scheduled_jobs

  # HTTP status codes that indicate the instance is invalid and must be recreated
  CRITICAL_ERROR_CODES = [400, 401, 404].freeze

  def perform
    evolution_go_channels.find_each(batch_size: 50) do |channel|
      next if channel.account.blank? || channel.account.suspended?
      next if channel.inbox.blank?

      check_channel_connection(channel)
    rescue StandardError => e
      Rails.logger.error "[EVOLUTION_GO_HEALTH] Error checking channel #{channel.id}: #{e.class} - #{e.message}"
    end
  end

  private

  def evolution_go_channels
    Channel::Whatsapp.where(provider: 'evolution_go')
  end

  def check_channel_connection(channel)
    service = channel.provider_service
    return unless service.evolution_go_configured? && service.instance_token.present? && service.instance_id.present?

    # Force a real API check, bypassing the local cache
    status = service.get_connection_status(force_api_check: true)

    if status[:connected]
      handle_connected(channel)
    elsif status[:success]
      # API responded successfully but the channel is disconnected
      handle_disconnected(channel, service)
    elsif CRITICAL_ERROR_CODES.include?(status[:error_code])
      handle_critical_error(channel, service)
    else
      # Network errors, timeouts, 5xx — skip to avoid false positives
      Rails.logger.warn "[EVOLUTION_GO_HEALTH] Transient error for channel #{channel.id}, skipping"
    end
  end

  def handle_connected(channel)
    if channel.reauthorization_required?
      channel.reauthorized!
      Rails.logger.info "[EVOLUTION_GO_HEALTH] Channel #{channel.id} reconnected, cleared reauthorization alert"
    end

    config = channel.provider_config || {}
    return if config['connected'] == true && config['connection_status'] == 'open'

    config['connected'] = true
    config['connection_status'] = 'open'
    channel.update_column(:provider_config, config)
    Rails.logger.info "[EVOLUTION_GO_HEALTH] Channel #{channel.id} is connected, synced local state"
  end

  def handle_disconnected(channel, service)
    Rails.logger.info "[EVOLUTION_GO_HEALTH] Channel #{channel.id} disconnected, attempting reconnect"

    reconnect_result = service.reconnect_instance
    unless reconnect_result[:success]
      Rails.logger.error "[EVOLUTION_GO_HEALTH] Reconnect request failed for channel #{channel.id}"
      mark_disconnected(channel)
      return
    end

    # Wait briefly for the reconnection to take effect
    sleep(2)

    recheck = service.get_connection_status(force_api_check: true)
    if recheck[:connected]
      handle_connected(channel)
      Rails.logger.info "[EVOLUTION_GO_HEALTH] Channel #{channel.id} successfully reconnected"
    else
      Rails.logger.warn "[EVOLUTION_GO_HEALTH] Channel #{channel.id} still disconnected after reconnect attempt"
      mark_disconnected(channel)
    end
  end

  def handle_critical_error(channel, service)
    Rails.logger.error "[EVOLUTION_GO_HEALTH] Critical error for channel #{channel.id}, recreating instance"

    # Delete the broken instance
    service.delete_instance

    # Create a fresh instance
    result = service.create_instance
    if result[:success]
      Rails.logger.info "[EVOLUTION_GO_HEALTH] Channel #{channel.id} instance recreated successfully"
    else
      Rails.logger.error "[EVOLUTION_GO_HEALTH] Failed to recreate instance for channel #{channel.id}: #{result[:error]}"
    end

    # Mark as disconnected — user needs to re-scan QR code
    mark_disconnected(channel)
  end

  def mark_disconnected(channel)
    config = channel.reload.provider_config || {}
    config['connected'] = false
    config['connection_status'] = 'close'
    channel.update_column(:provider_config, config)
    channel.prompt_reauthorization! unless channel.reauthorization_required?
  end
end
