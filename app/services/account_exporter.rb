# app/services/account_exporter.rb
class AccountExporter
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def perform
    {
      metadata: {
        exported_at: Time.now.utc,
        chatwoot_version: Chatwoot.config[:version] || 'unknown',
        source_account_id: account.id
      },
      account: account.as_json(except: [:id, :created_at, :updated_at]),
      custom_attribute_definitions: export_relation(:custom_attribute_definitions),
      labels: export_relation(:labels),
      canned_responses: export_relation(:canned_responses),
      webhooks: export_relation(:webhooks),
      working_hours: export_relation(:working_hours),
      custom_filters: export_relation(:custom_filters),
      automation_rules: export_relation(:automation_rules),
      macros: export_relation(:macros),
      sla_policies: export_relation(:sla_policies),
      agents: export_agents,
      teams: export_teams,
      inboxes: export_inboxes,
      contacts: export_contacts,
      conversations: export_conversations,
      portals: export_relation(:portals),
      categories: export_relation(:categories),
      articles: export_relation(:articles),
      messages: export_messages
    }
  end

  private

  def export_relation(relation_name)
    if account.respond_to?(relation_name)
      account.send(relation_name).as_json
    end
  end

  def export_agents
    # Usando includes(:user) para evitar N+1 queries e tratando usuarios deletados (nil)
    account.account_users.includes(:user).map do |au|
      next unless au.user

      au.user.as_json(only: [:id, :email, :name, :display_name]).merge('role' => au.role)
    end.compact
  end

  def export_teams
    return unless account.respond_to?(:teams)

    # Usando includes para evitar queries N+1
    account.teams.includes(:team_members).map do |team|
      team.as_json.merge('member_ids' => team.team_members.pluck(:user_id))
    end
  end

  def export_inboxes
    # Usando includes para evitar queries N+1 e tratando canal nulo (nil) defensivamente
    account.inboxes.includes(:inbox_members).map do |inbox|
      inbox_json = inbox.as_json
      inbox_json['channel_details'] = inbox.channel&.as_json if inbox.channel.present?
      inbox_json['member_ids'] = inbox.inbox_members.pluck(:user_id)
      inbox_json
    end
  end

  def export_contacts
    # Usando includes(:taggings) para evitar queries N+1 no label_list
    account.contacts.includes(:taggings).map do |contact|
      contact_json = contact.as_json
      contact_json['label_list'] = contact.label_list if contact.respond_to?(:label_list)
      contact_json
    end
  end

  def export_conversations
    # Usando includes(:taggings) para evitar queries N+1 no label_list
    account.conversations.includes(:taggings).map do |convo|
      convo_json = convo.as_json
      convo_json['label_list'] = convo.label_list if convo.respond_to?(:label_list)
      convo_json
    end
  end

  def export_messages
    messages = []
    # Usando find_each para carregar mensagens em lotes (evita estouro de memoria OOM)
    # Usando includes para carregar anexos de forma eficiente
    Message.where(account_id: account.id)
           .includes(attachments: { file_attachment: :blob })
           .find_each(batch_size: 1000) do |msg|
      
      msg_json = msg.as_json
      if msg.attachments.any?
        msg_json['attachments_metadata'] = msg.attachments.map do |att|
          {
            file_type: att.file_type,
            external_url: att.external_url,
            blob_key: att.file&.blob&.key,
            blob_filename: att.file&.blob&.filename.to_s,
            blob_content_type: att.file&.blob&.content_type
          }
        end
      end
      messages << msg_json
    end
    messages
  end
end
