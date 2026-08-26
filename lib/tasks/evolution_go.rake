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
end
