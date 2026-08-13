class MessageSequenceListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]

    return unless message.incoming?

    conversation = message.conversation
    return if conversation.blank?

    # Busca as sequências associadas a esta conversa que estão aguardando interação do contato
    waiting_sequences = conversation.conversation_message_sequences.waiting_response

    return if waiting_sequences.empty?

    # Retoma as sequências definindo waiting_interaction como false e reinicia a contagem do
    # wait_time do próximo passo a partir do momento da retomada
    waiting_sequences.update_all(waiting_interaction: false, last_step_executed_at: Time.current)
  end
end
