# frozen_string_literal: true

class CustomExceptions::ContactBlocked < CustomExceptions::Base
  def message
    I18n.t('errors.whatsapp.evolution_go.group_participant_blocked', name: @data[:name])
  end

  def http_status
    :unprocessable_entity
  end
end
