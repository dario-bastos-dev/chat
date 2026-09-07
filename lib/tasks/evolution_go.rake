namespace :evolution_go do
  # Contacts first seen by @lid used to end up duplicated once WhatsApp revealed the phone: the
  # lookup that links the two halves only landed later. This reconciles the pairs already in the
  # database. Reports by default; pass APPLY=1 to actually merge — a wrong merge is expensive to
  # undo, so it is opt-in.
  desc 'Reconcile Evolution GO contacts duplicated between @lid and phone (APPLY=1 to merge)'
  task reconcile_lid_contacts: :environment do
    apply = ENV['APPLY'] == '1'
    puts apply ? 'APPLY mode: merging' : 'Report mode: nothing will be changed (APPLY=1 to merge)'

    Channel::Whatsapp.where(provider: 'evolution_go').find_each do |channel|
      inbox = channel.inbox
      next if inbox.blank?

      lid_contact_inboxes = inbox.contact_inboxes.joins(:contact).where('contacts.identifier LIKE ?', '%@lid')

      lid_contact_inboxes.find_each do |lid_contact_inbox|
        lid = lid_contact_inbox.source_id
        mapping = Channel::WhatsappLidMapping.find_by(account_id: inbox.account_id, lid: lid)

        unless mapping
          puts "  inbox #{inbox.id} lid #{lid}: no mapping, cannot resolve a phone"
          next
        end

        phone = mapping.phone_number.to_s.gsub(/^\+/, '')
        real_contact = inbox.account.contacts.find_by(phone_number: "+#{phone}")

        if real_contact.nil?
          puts "  inbox #{inbox.id} lid #{lid} -> +#{phone}: promote contact #{lid_contact_inbox.contact_id}"
          next unless apply

          lid_contact_inbox.update!(source_id: phone)
          lid_contact_inbox.contact.update!(phone_number: "+#{phone}", identifier: "#{phone}@s.whatsapp.net")
        elsif real_contact.id != lid_contact_inbox.contact_id
          puts "  inbox #{inbox.id} lid #{lid} -> +#{phone}: merge #{lid_contact_inbox.contact_id} into #{real_contact.id}"
          next unless apply

          ContactMergeAction.new(
            account: inbox.account,
            base_contact: real_contact,
            mergee_contact: lid_contact_inbox.contact
          ).perform
        end
      end
    end
  end

  # Failed deletes, double creates and the health job's recreate path can each leave an instance
  # running on the Evolution GO server with no channel pointing at it. This only reports them:
  # deleting a live instance costs the customer a QR scan, so that stays a human decision.
  desc 'List Evolution GO instances that no channel points at'
  task orphan_instances: :environment do
    channel = Channel::Whatsapp.find_by(provider: 'evolution_go')
    abort 'No Evolution GO channel configured, cannot reach the API' if channel.blank?

    result = channel.provider_service.list_instances
    abort "Could not list instances: #{result[:error]}" unless result[:success]

    known_ids = Channel::Whatsapp.where(provider: 'evolution_go')
                                 .filter_map { |ch| ch.provider_config['instance_id'].presence }
                                 .to_set

    orphans = result[:instances].reject do |instance|
      known_ids.include?((instance['id'] || instance['Id'] || instance['instanceId']).to_s)
    end

    puts "Instances on the server: #{result[:instances].size}"
    puts "Instances referenced by a channel: #{known_ids.size}"
    puts "Orphans: #{orphans.size}"

    orphans.each do |instance|
      id = instance['id'] || instance['Id'] || instance['instanceId']
      puts "  #{id}\t#{instance['name'] || instance['Name']}"
    end
  end

  # The contact's message and the echo of a reply sent from the phone used to be handled by two
  # workers at once: neither found an open conversation, because the other had not committed yet,
  # and each created one. The advisory lock in Whatsapp::IncomingMessageEvolutionGoService stops
  # new ones; this merges the pairs already in the database.
  #
  # Nothing is ever deleted. A row that cannot move because the target already holds an equivalent
  # one stays on the source, and the source survives as a resolved conversation, so a merge can be
  # walked back from the ids printed here. Reports by default; pass APPLY=1 to write.
  desc 'Merge Evolution GO conversations duplicated by concurrent webhooks (APPLY=1 to merge)'
  task merge_duplicate_conversations: :environment do
    apply = ENV['APPLY'] == '1'
    window = (ENV['WINDOW'].presence || '5').to_f
    limit = ENV['LIMIT'].presence&.to_i
    conn = ActiveRecord::Base.connection
    conversation_type = conn.quote('Conversation')

    # Nothing about these is unique per conversation, so every row moves.
    plain = %w[messages reporting_events sla_events scheduled_messages calls csat_survey_responses
               captain_message_reports]

    # A unique index covers conversation_id together with these columns, so a row only moves when
    # the target holds none with the same key.
    guarded = {
      'conversation_participants' => %w[user_id],
      'mentions' => %w[user_id],
      'conversation_deals' => %w[deal_id],
      'conversation_message_sequences' => %w[message_sequence_id],
      'applied_slas' => %w[account_id sla_policy_id],
      'automation_rule_pending_executions' => %w[automation_rule_id episode_key],
      'captain_faq_observations' => %w[faq_suggestion_id]
    }

    # Three unique indexes, two of them partial. Modelling that here would be guesswork, so these
    # rows only move when the target has none at all.
    only_if_empty = %w[conversation_outcomes]

    # Conversations of one contact_inbox opened within seconds of each other. Grouped as clusters
    # rather than pairs: a contact_inbox can hold three of them, and merging pairwise would leave
    # the middle one half moved.
    clusters = []
    Conversation.where(status: :open).order(:contact_inbox_id, :created_at, :id)
                .pluck(:contact_inbox_id, :id, :created_at).each do |contact_inbox_id, id, created_at|
      last = clusters.last
      if last && last[:contact_inbox_id] == contact_inbox_id && (created_at - last[:seen_at]) <= window
        last[:ids] << id
        last[:seen_at] = created_at
      else
        clusters << { contact_inbox_id: contact_inbox_id, ids: [id], seen_at: created_at }
      end
    end
    clusters.select! { |cluster| cluster[:ids].size > 1 }
    clusters = clusters.first(limit) if limit

    puts apply ? "APPLY mode: merging #{clusters.size} clusters" : "Report mode: #{clusters.size} clusters, nothing will change (APPLY=1 to merge)"

    clusters.each do |cluster|
      ids = cluster[:ids].sort
      # The highest id is the one set_conversation keeps choosing with `.last`, so merging into it
      # leaves the behaviour of every later message unchanged.
      target = ids.last
      sources = ids[0..-2]
      list = sources.join(',')
      puts "contact_inbox #{cluster[:contact_inbox_id]}: #{sources.join(', ')} -> #{target}"

      unless apply
        (plain + guarded.keys + only_if_empty).each do |table|
          count = conn.select_value("SELECT COUNT(*) FROM #{table} WHERE conversation_id IN (#{list})").to_i
          puts "    #{table}: #{count} on sources" if count.positive?
        end
        %w[notifications taggings].each do |table|
          type_column, id_column = table == 'notifications' ? %w[primary_actor_type primary_actor_id] : %w[taggable_type taggable_id]
          count = conn.select_value(
            "SELECT COUNT(*) FROM #{table} WHERE #{type_column} = #{conversation_type} AND #{id_column} IN (#{list})"
          ).to_i
          puts "    #{table}: #{count} on sources" if count.positive?
        end
        next
      end

      Conversation.transaction do
        # The same lock the incoming service takes, so a webhook for this contact waits instead of
        # dropping a message into a conversation that is being emptied.
        conn.execute("SELECT pg_advisory_xact_lock(#{Whatsapp::IncomingMessageEvolutionGoService::CONVERSATION_LOCK_NAMESPACE}, " \
                     "#{cluster[:contact_inbox_id].to_i})")

        plain.each do |table|
          moved = conn.exec_update("UPDATE #{table} SET conversation_id = #{target} WHERE conversation_id IN (#{list})")
          puts "    #{table}: #{moved} moved" if moved.positive?
        end

        guarded.each do |table, keys|
          # One source at a time: once the first has moved, the next is checked against a target
          # that already holds those rows, so two sources cannot collide with each other either.
          sources.each do |source|
            match = keys.map { |key| "x.#{key} IS NOT DISTINCT FROM #{table}.#{key}" }.join(' AND ')
            moved = conn.exec_update(
              "UPDATE #{table} SET conversation_id = #{target} WHERE conversation_id = #{source} " \
              "AND NOT EXISTS (SELECT 1 FROM #{table} x WHERE x.conversation_id = #{target} AND #{match})"
            )
            puts "    #{table}: #{moved} moved from #{source}" if moved.positive?
          end
        end

        only_if_empty.each do |table|
          moved = conn.exec_update(
            "UPDATE #{table} SET conversation_id = #{target} WHERE conversation_id IN (#{list}) " \
            "AND NOT EXISTS (SELECT 1 FROM #{table} x WHERE x.conversation_id = #{target})"
          )
          puts "    #{table}: #{moved} moved" if moved.positive?
        end

        moved = conn.exec_update(
          "UPDATE notifications SET primary_actor_id = #{target} " \
          "WHERE primary_actor_type = #{conversation_type} AND primary_actor_id IN (#{list})"
        )
        puts "    notifications: #{moved} moved" if moved.positive?

        sources.each do |source|
          moved = conn.exec_update(
            "UPDATE taggings SET taggable_id = #{target} " \
            "WHERE taggable_type = #{conversation_type} AND taggable_id = #{source} " \
            "AND NOT EXISTS (SELECT 1 FROM taggings x WHERE x.taggable_type = #{conversation_type} " \
            "AND x.taggable_id = #{target} AND x.tag_id = taggings.tag_id " \
            "AND x.context IS NOT DISTINCT FROM taggings.context)"
          )
          puts "    taggings: #{moved} moved from #{source}" if moved.positive?
        end

        # last_activity_at orders the agent's list, so it has to reflect the newest message the
        # merged conversation now holds.
        conn.exec_update(
          "UPDATE conversations SET last_activity_at = " \
          "COALESCE((SELECT MAX(created_at) FROM messages WHERE conversation_id = #{target}), last_activity_at) " \
          "WHERE id = #{target}"
        )

        # update_all on purpose, never the model: resolving through it fires conversation.resolved,
        # and CsatSurveyListener answers that by sending the survey to the contact. Repairing data
        # must not message dozens of real customers, nor call the account's agent bot webhook.
        Conversation.where(id: sources).update_all(
          status: Conversation.statuses[:resolved], status_changed_at: Time.current, updated_at: Time.current
        )
        puts "    sources resolved: #{sources.join(', ')}"
      end
    end
  end

end
