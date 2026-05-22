class MessageSequences::ProcessJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # 1. Processa todos os vínculos ativos e envia as mensagens programadas
    ConversationMessageSequence.active.includes(:conversation, :message_sequence).find_each do |conv_seq|
      conversation = conv_seq.conversation
      sequence = conv_seq.message_sequence

      # Desativa se a sequência ou a conversa mudaram para um estado onde não devem mais receber do funil
      unless sequence.active? && (conversation.open? || conversation.pending?)
        conv_seq.update!(active: false)
        next
      end

      # Identifica qual o próximo passo a executar (current_step começa em 0)
      next_step = sequence.steps.order(:position).offset(conv_seq.current_step).first

      if next_step.nil?
        conv_seq.update!(active: false)
        
        # Executa a macro se houver uma vinculada
        if sequence.macro_id.present?
          user = sequence.created_by || sequence.account.users.first
          Macros::ExecutionService.new(sequence.macro, conversation, user).perform
        end

        next
      end

      days, hours, minutes, seconds = next_step.wait_time.split(':').map(&:to_i)
      step_wait_duration = days.days + hours.hours + minutes.minutes + seconds.seconds
      reference_time = conv_seq.last_step_executed_at || conv_seq.created_at

      # Se já deu o tempo, envia a mensagem
      if Time.current >= (reference_time + step_wait_duration)
        # Verifica se o envio está dentro do horário permitido, caso restrição esteja ativa
        if sequence.restrict_execution_time?
          account_timezone = sequence.account.timezone.presence || 'UTC'
          current_hour = Time.current.in_time_zone(account_timezone).hour
          
          # Se estiver fora do horário, a mensagem não é enviada agora e será avaliada no próximo minuto
          next if current_hour < sequence.execution_start_hour || current_hour >= sequence.execution_end_hour
        end

        execute_step(conversation, next_step)

        conv_seq.update!(
          current_step: conv_seq.current_step + 1,
          last_step_executed_at: Time.current
        )
      end
    end
  end

  private

  def execute_step(conversation, step)
    message_params = {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: step.content,
      private: false
    }

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
