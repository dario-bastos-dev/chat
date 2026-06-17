# app/services/account_importer.rb
class AccountImporter
  attr_reader :data

  def initialize(data:)
    @data = data
  end

  def perform
    new_account_id = nil

    ActiveRecord::Base.transaction do
      # 1. Create target account with all original attributes (feature flags, limits, settings, etc)
      account_attrs = data['account'].except('id', 'created_at', 'updated_at')
      account_attrs['name'] = data['account']['name'] + " (Migrada)"
      
      new_account = Account.create!(account_attrs)
      new_account_id = new_account.id

      user_mapping = {}
      inbox_mapping = {}
      contact_mapping = {}
      conversation_mapping = {}
      team_mapping = {}
      sla_mapping = {}
      portal_mapping = {}
      category_mapping = {}

      # 2. Import agents
      data['agents']&.each do |agent_data|
        user = User.find_by(email: agent_data['email'])
        unless user
          temp_password = "ChatWoot2026!#" + SecureRandom.hex(4).upcase
          user = User.create!(
            email: agent_data['email'],
            name: agent_data['name'],
            display_name: agent_data['display_name'],
            password: temp_password
          )
        end

        AccountUser.create!(
          account_id: new_account_id,
          user_id: user.id,
          role: agent_data['role'] || 'agent'
        )
        user_mapping[agent_data['id']] = user.id
      end

      # 3. Import Account Labels
      data['labels']&.each do |label_data|
        Label.create!(
          account_id: new_account_id,
          title: label_data['title'],
          description: label_data['description'],
          color: label_data['color'],
          show_on_sidebar: label_data['show_on_sidebar']
        )
      end

      # 4. Import Canned Responses
      data['canned_responses']&.each do |canned_data|
        CannedResponse.create!(
          account_id: new_account_id,
          short_code: canned_data['short_code'],
          content: canned_data['content']
        )
      end

      # 5. Import Custom Attributes
      data['custom_attribute_definitions']&.each do |attr_data|
        CustomAttributeDefinition.create!(
          account_id: new_account_id,
          attribute_key: attr_data['attribute_key'],
          attribute_display_name: attr_data['attribute_display_name'],
          attribute_display_type: attr_data['attribute_display_type'],
          attribute_model: attr_data['attribute_model'],
          default_value: attr_data['default_value']
        )
      end

      # 6. Working Hours will be imported after Inboxes (Step 10.1)

      # 7. Import Webhooks
      data['webhooks']&.each do |webhook_data|
        Webhook.create!(
          account_id: new_account_id,
          url: webhook_data['url'],
          subscriptions: webhook_data['subscriptions']
        )
      end

      # 8. Import SLA Policies
      if data['sla_policies'] && Account.method_defined?(:sla_policies)
        data['sla_policies'].each do |sla_data|
          new_sla = SlaPolicy.create!(
            account_id: new_account_id,
            name: sla_data['name'],
            description: sla_data['description'],
            first_response_time_threshold: sla_data['first_response_time_threshold'],
            next_response_time_threshold: sla_data['next_response_time_threshold'],
            resolution_time_threshold: sla_data['resolution_time_threshold'],
            only_during_business_hours: sla_data['only_during_business_hours']
          )
          sla_mapping[sla_data['id']] = new_sla.id
        end
      end

      # 9. Import Teams and Members
      if data['teams'] && Account.method_defined?(:teams)
        data['teams'].each do |team_data|
          new_team = Team.create!(
            account_id: new_account_id,
            name: team_data['name'],
            description: team_data['description'],
            allow_auto_assign: team_data['allow_auto_assign']
          )
          team_mapping[team_data['id']] = new_team.id

          team_data['member_ids']&.each do |old_uid|
            new_uid = user_mapping[old_uid]
            TeamMember.create!(team_id: new_team.id, user_id: new_uid) if new_uid
          end
        end
      end

      # 10. Import Inboxes and Members
      data['inboxes']&.each do |inbox_data|
        channel = Channel::Api.create!(account_id: new_account_id)
        new_inbox = Inbox.create!(
          name: inbox_data['name'],
          account_id: new_account_id,
          channel: channel
        )
        inbox_mapping[inbox_data['id']] = new_inbox.id

        inbox_data['member_ids']&.each do |old_uid|
          new_uid = user_mapping[old_uid]
          InboxMember.create!(inbox_id: new_inbox.id, user_id: new_uid) if new_uid
        end
      end

      # 10.1 Import Working Hours (mapped to new inboxes)
      data['working_hours']&.each do |wh_data|
        new_inbox_id = inbox_mapping[wh_data['inbox_id']]
        next unless new_inbox_id

        WorkingHour.create!(
          account_id: new_account_id,
          inbox_id: new_inbox_id,
          day_of_week: wh_data['day_of_week'],
          closed_all_day: wh_data['closed_all_day'],
          open_hour: wh_data['open_hour'],
          open_minutes: wh_data['open_minutes'],
          close_hour: wh_data['close_hour'],
          close_minutes: wh_data['close_minutes']
        )
      end

      # 11. Import Contacts (with de-duplication)
      data['contacts']&.each do |contact_data|
        existing_contact = nil
        if contact_data['phone_number'].present?
          existing_contact = Contact.find_by(account_id: new_account_id, phone_number: contact_data['phone_number'])
        end
        if existing_contact.nil? && contact_data['email'].present?
          existing_contact = Contact.find_by(account_id: new_account_id, email: contact_data['email'].downcase)
        end
        if existing_contact.nil? && contact_data['identifier'].present?
          existing_contact = Contact.find_by(account_id: new_account_id, identifier: contact_data['identifier'])
        end

        if existing_contact
          contact_mapping[contact_data['id']] = existing_contact.id
        else
          new_contact = Contact.create!(
            account_id: new_account_id,
            name: contact_data['name'],
            email: contact_data['email'],
            phone_number: contact_data['phone_number'],
            additional_attributes: contact_data['additional_attributes'],
            created_at: contact_data['created_at'],
            updated_at: contact_data['updated_at']
          )
          if contact_data['label_list'] && new_contact.respond_to?(:label_list)
            new_contact.label_list.add(contact_data['label_list'])
            new_contact.save!
          end
          contact_mapping[contact_data['id']] = new_contact.id
        end
      end

      # 12. Import Conversations and Tags
      data['conversations']&.each do |convo_data|
        new_inbox_id = inbox_mapping[convo_data['inbox_id']]
        new_contact_id = contact_mapping[convo_data['contact_id']]
        next unless new_inbox_id && new_contact_id

        contact_inbox = ContactInbox.find_by(contact_id: new_contact_id, inbox_id: new_inbox_id)
        unless contact_inbox
          contact = Contact.find(new_contact_id)
          source_id = contact.phone_number.presence || contact.email.presence || SecureRandom.uuid
          contact_inbox = ContactInbox.create!(contact_id: new_contact_id, inbox_id: new_inbox_id, source_id: source_id)
        end

        new_sla_id = convo_data['sla_policy_id'] ? sla_mapping[convo_data['sla_policy_id']] : nil

        new_convo = Conversation.create!(
          account_id: new_account_id,
          inbox_id: new_inbox_id,
          contact_id: new_contact_id,
          contact_inbox_id: contact_inbox.id,
          status: convo_data['status'],
          sla_policy_id: new_sla_id,
          created_at: convo_data['created_at'],
          updated_at: convo_data['updated_at']
        )
        
        if convo_data['label_list'] && new_convo.respond_to?(:label_list)
          new_convo.label_list.add(convo_data['label_list'])
          new_convo.save!
        end
        
        conversation_mapping[convo_data['id']] = new_convo.id
      end

      # 13. Import FAQ Base
      if data['portals'] && Account.method_defined?(:portals)
        data['portals'].each do |portal_data|
          new_portal = Portal.create!(
            account_id: new_account_id,
            name: portal_data['name'],
            slug: portal_data['slug'] + "-#{new_account_id}",
            custom_domain: portal_data['custom_domain'],
            config: portal_data['config'],
            archived: portal_data['archived']
          )
          portal_mapping[portal_data['id']] = new_portal.id
        end
      end

      if data['categories'] && data['portals']
        data['categories'].each do |cat_data|
          new_pid = portal_mapping[cat_data['portal_id']]
          next unless new_pid

          new_cat = Category.create!(
            account_id: new_account_id,
            portal_id: new_pid,
            name: cat_data['name'],
            slug: cat_data['slug'] + "-#{new_account_id}",
            description: cat_data['description'],
            locale: cat_data['locale'],
            icon: cat_data['icon']
          )
          category_mapping[cat_data['id']] = new_cat.id
        end
      end

      if data['articles'] && data['portals']
        data['articles'].each do |art_data|
          new_pid = portal_mapping[art_data['portal_id']]
          new_cid = category_mapping[art_data['category_id']]
          next unless new_pid && new_cid

          new_author_id = user_mapping[art_data['author_id']] || user_mapping.values.first

          Article.create!(
            account_id: new_account_id,
            portal_id: new_pid,
            category_id: new_cid,
            author_id: new_author_id,
            title: art_data['title'],
            content: art_data['content'],
            status: art_data['status'],
            views: art_data['views'],
            meta: art_data['meta']
          )
        end
      end

      # 14. Import Messages
      data['messages']&.each do |msg_data|
        new_convo_id = conversation_mapping[msg_data['conversation_id']]
        next unless new_convo_id

        sender_id = msg_data['sender_type'] == 'User' ? user_mapping[msg_data['sender_id']] : contact_mapping[msg_data['sender_id']]
        new_inbox_id = inbox_mapping[msg_data['inbox_id']] || Conversation.find(new_convo_id).inbox_id

        new_msg = Message.create!(
          account_id: new_account_id,
          conversation_id: new_convo_id,
          inbox_id: new_inbox_id,
          content: msg_data['content'],
          message_type: msg_data['message_type'],
          private: msg_data['private'],
          sender_type: msg_data['sender_type'],
          sender_id: sender_id,
          created_at: msg_data['created_at'],
          updated_at: msg_data['updated_at'],
          content_attributes: msg_data['content_attributes']
        )

        msg_data["attachments_metadata"]&.each do |att_data|
          blob = ActiveStorage::Blob.find_by(key: att_data["blob_key"])
          if blob
            blob.update_columns(metadata: {}) if blob.metadata.nil?
            new_msg.attachments.create!(
              account_id: new_account_id,
              file_type: att_data["file_type"],
              external_url: att_data["external_url"],
              file: blob
            )
          else
            if att_data["external_url"].present?
              filename = att_data['blob_filename'] || 'Arquivo'
              fallback_link = "\n\n[Anexo original: #{filename}] - #{att_data['external_url']}"
              new_msg.update_columns(content: (new_msg.content || "") + fallback_link)
            end
          end
        end
      end
    end

    new_account_id
  end
end
