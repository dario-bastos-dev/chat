class Conversations::RedistributeService
  def initialize(account:, conversations:, team: nil, include_deals: false)
    @account = account
    @conversations = conversations
    @team = team
    @include_deals = include_deals
    @agent_by_key = {}
  end

  def perform
    @load = open_conversation_counts
    # Quem tem conversa na selecao esta sendo esvaziado e nao pode receber nada. Isso tambem impede
    # que um negocio ja movido nesta rodada seja movido de novo, pois o novo dono nunca e o antigo.
    @donor_ids = @conversations.where.not(assignee_id: nil).distinct.pluck(:assignee_id)
    @conversations.includes(:inbox).order(:id).each { |conversation| redistribute(conversation) }
  end

  private

  def redistribute(conversation)
    candidate_ids = candidate_ids_for(conversation)
    return if candidate_ids.empty?

    # Uma conversa do mesmo contato, ou que compartilhe um negocio aberto, ja redistribuida
    # nesta rodada fixa o agente: senao o negocio ficaria com um e a conversa com outro.
    keys = affinity_keys(conversation)
    agent_id = keys.filter_map { |key| @agent_by_key[key] }.find { |id| candidate_ids.include?(id) }
    agent_id ||= candidate_ids.min_by { |id| [@load[id], id] }

    previous_assignee_id = conversation.assignee_id
    ActiveRecord::Base.transaction do
      conversation.update!(assignee_id: agent_id, team_id: @team&.id || conversation.team_id)
      transfer_deals(conversation, previous_assignee_id, agent_id) if @include_deals
    end

    keys.each { |key| @agent_by_key[key] = agent_id }
    @load[agent_id] += 1
  # Deixar o erro derrubar o job faria o Sidekiq repetir tudo e tirar as conversas ja
  # redistribuidas de quem acabou de recebe-las; so a conversa que falhou fica para tras.
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @account).capture_exception
  end

  def candidate_ids_for(conversation)
    ids = conversation.inbox.members.ids
    ids &= team_member_ids if @team
    ids - @donor_ids
  end

  def affinity_keys(conversation)
    [[:contact, conversation.contact_id]] + conversation.deals.open_deals.ids.map { |id| [:deal, id] }
  end

  # So sai do lugar o negocio que era do antigo responsavel da conversa ou estava sem dono;
  # um negocio de outro vendedor ligado ao mesmo contato continua com ele.
  def transfer_deals(conversation, previous_assignee_id, agent_id)
    agent = @account.users.find(agent_id)
    conversation.deals.open_deals.where(assignee_id: [previous_assignee_id, nil].uniq).find_each do |deal|
      next if deal.assignee_id == agent_id

      deal.update!(assignee_id: agent_id)
      deal.deal_activities.create!(
        account: @account,
        activity_type: 'note',
        description: I18n.t('deals.activity.redistributed', agent_name: agent.name, conversation_id: conversation.display_id),
        completed_at: Time.current
      )
    end
  end

  def team_member_ids
    @team_member_ids ||= @team.members.ids
  end

  def open_conversation_counts
    counts = @account.conversations.open.where.not(assignee_id: nil).group(:assignee_id).count
    Hash.new(0).merge(counts)
  end
end
