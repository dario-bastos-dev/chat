class MessageSequences::ProcessJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # 1. Processa todos os vínculos ativos e prontos que devem receber as mensagens programadas
    ConversationMessageSequence.ready_for_execution.includes(:conversation, :message_sequence).find_each do |conv_seq|
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
          account_timezone = sequence.account.reporting_timezone.presence || 'UTC'
          current_hour = Time.current.in_time_zone(account_timezone).hour
          
          # Se estiver fora do horário, a mensagem não é enviada agora e será avaliada no próximo minuto
          next if current_hour < sequence.execution_start_hour || current_hour >= sequence.execution_end_hour
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
          next
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
    if step.execute_macro?
      if step.macro.present?
        user = step.message_sequence.created_by || step.message_sequence.account.users.first
        Macros::ExecutionService.new(step.macro, conversation, user).perform
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
