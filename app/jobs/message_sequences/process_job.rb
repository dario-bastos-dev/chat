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

      hours, minutes = next_step.wait_time.split(':').map(&:to_i)
      step_wait_duration = hours.hours + minutes.minutes
      reference_time = conv_seq.last_step_executed_at || conv_seq.created_at

      # Se já deu o tempo, envia a mensagem
      if Time.current >= (reference_time + step_wait_duration)
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

    if step.send_attachment? && step.file.attached?
      # Copia o blob do arquivo para a nova mensagem
      attachment = message.attachments.new(
        account_id: conversation.account_id,
        file_type: 'file'
      )
      attachment.file.attach(step.file.blob)
    end

    message.save!
  end
end
