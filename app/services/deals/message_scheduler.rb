# frozen_string_literal: true

# Agendamento em massa a partir do Kanban. Uma mensagem programada pertence a
# uma conversa, e um negocio pode ter varias, entao a escolha do destino e a
# parte que importa aqui:
#
# 1. so a conversa primaria do negocio e alvo, e apenas se estiver aberta —
#    caindo para a conversa aberta mais recente quando nao houver primaria.
#    Agendar numa conversa fechada seria jogar a mensagem fora: o
#    ScheduledMessages::DispatchJob a cancela na hora do disparo.
# 2. a conversa escolhida ainda passa pela ConversationPolicy. O policy_scope de
#    negocio e mais largo que o de conversa (um agente enxerga todo negocio sem
#    responsavel), entao sem esta checagem a acao em massa entregaria mensagem
#    por caixa de entrada que o agente nao acessa — algo que a tela da conversa
#    impede.
# 3. cada contato recebe no maximo uma mensagem por execucao, mesmo que tenha
#    varios negocios selecionados ou que a mesma conversa esteja vinculada a
#    mais de um deles.
#
# O retorno diz o que ficou de fora e por que: numa acao sobre dezenas de cards,
# um "pronto" sem numeros esconde justamente os casos que precisam de atencao.
class Deals::MessageScheduler
  def initialize(account:, user_context:, deals:, params:)
    @account = account
    @user_context = user_context
    @deals = deals
    @params = params
    @scheduled_count = 0
    @skipped_without_conversation = []
    @skipped_unauthorized = []
    @skipped_duplicate_contact = []
    @skipped_already_scheduled = []
    @failed = []
    @contact_ids = Set.new
  end

  def perform
    @deals.each { |deal| schedule_for(deal) }

    {
      scheduled_count: @scheduled_count,
      skipped_without_conversation: @skipped_without_conversation,
      skipped_unauthorized: @skipped_unauthorized,
      skipped_duplicate_contact: @skipped_duplicate_contact,
      skipped_already_scheduled: @skipped_already_scheduled,
      failed: @failed
    }
  end

  private

  def schedule_for(deal)
    conversation = target_conversation(deal)
    return @skipped_without_conversation << deal.id if conversation.blank?
    return @skipped_unauthorized << deal.id unless authorized?(conversation)
    return @skipped_duplicate_contact << deal.id unless @contact_ids.add?(conversation.contact_id)
    return @skipped_already_scheduled << deal.id if already_scheduled?(conversation)

    message = build_message(deal, conversation)
    if message.save
      @scheduled_count += 1
    else
      @failed << { deal_id: deal.id, errors: message.errors.full_messages }
    end
  end

  # Le do preload de `conversation_deals: :conversation` feito no controller;
  # `deal.conversations.open` reconsultaria o banco por negocio.
  def target_conversation(deal)
    links = deal.conversation_deals
    primary = links.detect(&:is_primary)&.conversation
    return primary if primary&.open?

    links.filter_map { |link| link.conversation if link.conversation.open? }
         .max_by { |conversation| conversation.last_activity_at || conversation.created_at }
  end

  def authorized?(conversation)
    Pundit.policy!(@user_context, conversation).show?
  end

  # Repetir a acao com os mesmos cards selecionados nao pode gerar duas
  # mensagens iguais na mesma conversa.
  def already_scheduled?(conversation)
    conversation.scheduled_messages.pending.exists?(
      content: @params[:content],
      scheduled_at: @params[:scheduled_at]
    )
  end

  def build_message(deal, conversation)
    conversation.scheduled_messages.new(
      account_id: @account.id,
      created_by_id: @user_context[:user].id,
      deal_id: deal.id,
      title: @params[:title],
      content: @params[:content],
      scheduled_at: @params[:scheduled_at]
    )
  end
end
