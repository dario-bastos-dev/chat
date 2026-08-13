class MessageSequences::ProcessJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # 1. Processa todos os vínculos ativos e prontos que devem receber as mensagens programadas
    ConversationMessageSequence.ready_for_execution
                                .includes(:conversation, :current_step, message_sequence: :steps)
                                .find_each do |conv_seq|
      process_conversation_sequence(conv_seq)
    rescue StandardError => e
      Rails.logger.error("[MessageSequences::ProcessJob] Failed to process ConversationMessageSequence##{conv_seq.id}: #{e.message}")
    end
  end

  private

  def process_conversation_sequence(conv_seq)
    conversation = conv_seq.conversation
    sequence = conv_seq.message_sequence

    # Desativa se a sequência ou a conversa mudaram para um estado onde não devem mais receber do funil
    unless sequence.active? && (conversation.open? || conversation.pending?)
      conv_seq.update!(active: false)
      return
    end

    next_step = conv_seq.current_step

    return finalize_sequence(conv_seq, conversation, sequence) if next_step.nil?

    days, hours, minutes, seconds = next_step.wait_time.split(':').map(&:to_i)
    step_wait_duration = days.days + hours.hours + minutes.minutes + seconds.seconds
    reference_time = conv_seq.last_step_executed_at || conv_seq.created_at

    # Se ainda não deu o tempo configurado no passo, nada a fazer agora
    return if Time.current < (reference_time + step_wait_duration)

    account_timezone = sequence.account.reporting_timezone.presence || 'UTC'
    current_time_in_zone = Time.current.in_time_zone(account_timezone)

    # Se o dia da semana atual não estiver liberado, a mensagem não é enviada agora e será avaliada no próximo dia permitido
    return unless sequence.allowed_on_weekday?(current_time_in_zone.wday)

    # Verifica se o envio está dentro do horário permitido, caso restrição esteja ativa
    if sequence.restrict_execution_time?
      current_hour = current_time_in_zone.hour

      # Se estiver fora do horário, a mensagem não é enviada agora e será avaliada no próximo minuto
      return if current_hour < sequence.execution_start_hour || current_hour >= sequence.execution_end_hour
    end

    # Verificação prévia da janela de conversação do canal apenas para mensagens e arquivos externos (ignora macros e templates)
    if !next_step.execute_macro? && !next_step.send_template? && !conversation.can_reply?
      conv_seq.update!(waiting_interaction: true)

      # Insere uma nota privada informando o agente sobre a pausa da sequência
      conversation.messages.create!(
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: :outgoing,
        private: true,
        content: I18n.t('message_sequences.paused_window', sequence_name: sequence.name)
      )
      return
    end

    execute_step(conversation, next_step)

    conv_seq.update!(
      current_step: next_step_after(sequence, next_step),
      last_step_executed_at: Time.current
    )
  end

  def next_step_after(sequence, step)
    sorted_steps = sequence.steps.sort_by(&:position)
    sorted_steps.find { |candidate| candidate.position > step.position }
  end

  def finalize_sequence(conv_seq, conversation, sequence)
    if sequence.macro_id.present?
      reference_time = conv_seq.last_step_executed_at || conv_seq.created_at
      delay = sequence.macro_execution_time.to_i.minutes

      # Aguarda o tempo configurado antes de rodar a macro final; a linha permanece ativa até lá
      return if Time.current < (reference_time + delay)

      run_macro(sequence.macro, conversation, sequence)
    end

    conv_seq.update!(active: false)
  end

  def run_macro(macro, conversation, sequence)
    user = sequence.created_by || sequence.account.users.first

    if user.blank?
      Rails.logger.error("[MessageSequences::ProcessJob] No user available to execute macro##{macro.id} for sequence##{sequence.id}")
      return
    end

    Macros::ExecutionService.new(macro, conversation, user).perform
  end

  def execute_step(conversation, step)
    if step.execute_macro?
      if step.macro.present?
        run_macro(step.macro, conversation, step.message_sequence)
      else
        # Se o macro foi excluído, insere uma nota privada e avança para que o worker não trave
        conversation.messages.create!(
          account_id: conversation.account_id,
          inbox_id: conversation.inbox_id,
          message_type: :outgoing,
          private: true,
          content: I18n.t('message_sequences.macro_deleted', sequence_name: step.message_sequence.name)
        )
      end
      return
    end

    message_params = {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: step.content,
      private: false
    }

    if step.send_template? && step.template_params.present?
      campaign_duck = MessageSequences::ProcessJob::CampaignDuck.new(
        step.message_sequence.created_by || step.message_sequence.account.users.first,
        conversation.inbox,
        conversation.account
      )
      liquid_processor = Whatsapp::LiquidTemplateProcessorService.new(
        campaign: campaign_duck,
        contact: conversation.contact
      )
      processed_template_params = liquid_processor.process_template_params(step.template_params)

      message_params[:additional_attributes] = {
        template_params: processed_template_params
      }
    end

    message = conversation.messages.build(message_params)

    if !step.send_message? && step.file.attached?
      determined_file_type = case step.step_type
                             when 'send_image' then 'image'
                             when 'send_audio' then 'audio'
                             when 'send_document' then 'file'
                             else 'file'
                             end

      # Copia o blob do arquivo para a nova mensagem
      attachment = message.attachments.new(
        account_id: conversation.account_id,
        file_type: determined_file_type
      )
      attachment.file.attach(step.file.blob)
    end

    message.save!
  end
end

class MessageSequences::ProcessJob::CampaignDuck
  attr_reader :sender, :inbox, :account

  def initialize(sender, inbox, account)
    @sender = sender
    @inbox = inbox
    @account = account
  end
end
