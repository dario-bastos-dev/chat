# Opens a one to one conversation with a member of a WhatsApp group, on the number the group came
# through. The member becomes a regular contact, matched the way an incoming message would match
# them, so their reply lands in this conversation instead of starting another one.
class Whatsapp::GroupParticipantConversationService
  pattr_initialize [:group_conversation!, :participant_jid!, :user!]

  def perform
    raise ActiveRecord::RecordNotFound unless group_conversation.contact.whatsapp_group?
    raise ActiveRecord::RecordNotFound if participant.blank? || business_number?

    existing_conversation || open_conversation
  end

  private

  def inbox
    group_conversation.inbox
  end

  # The roster is what the group reported about itself. A group that never reported one still
  # names whoever spoke on each of their messages.
  def participant
    @participant ||= roster_participant || speaker_participant
  end

  def roster_participant
    (group_conversation.additional_attributes['group_participants'] || []).find do |member|
      member.values_at('jid', 'lid', 'phone').include?(participant_jid)
    end
  end

  # content_attributes is stored as an encoded JSON string, hence the unwrapping before the lookup.
  def speaker_participant
    group_conversation.messages.incoming
                      .where("(content_attributes #>> '{}')::jsonb -> 'group_participant' ->> 'jid' = ?", participant_jid)
                      .last&.content_attributes&.dig('group_participant')
  end

  # The roster lists the business number too, and a conversation with itself is not one.
  def business_number?
    phone_digits.present? && phone_digits == inbox.channel.phone_number.to_s.delete('+')
  end

  # A member is addressed by their phone, by their lid, or both. The roster keeps the phone as a
  # jid, a message keeps it as e164; either way only the digits matter.
  def participant_jids
    @participant_jids ||= participant.values_at('jid', 'lid', 'phone').compact_blank
  end

  def lid_digits
    @lid_digits ||= participant_jids.find { |jid| jid.end_with?('@lid') }&.split('@')&.first
  end

  def phone_digits
    return @phone_digits if defined?(@phone_digits)

    phone = participant_jids.find { |jid| !jid.end_with?('@lid') }
    @phone_digits = phone ? phone.split('@').first.delete('+') : lid_mapping&.phone_number
  end

  def lid_mapping
    return if lid_digits.blank?

    @lid_mapping ||= Channel::WhatsappLidMapping.find_by(account_id: inbox.account_id, lid: lid_digits)
  end

  # The same source_id an incoming message from this member would carry: the phone when it is
  # known, the lid otherwise. The incoming flow swaps a lid for the phone once it learns it.
  def contact_inbox
    @contact_inbox ||= (phone_digits && inbox.contact_inboxes.find_by(source_id: phone_digits)) ||
                       (lid_digits && inbox.contact_inboxes.find_by(source_id: lid_digits)) ||
                       ContactInboxBuilder.new(contact: contact, inbox: inbox, source_id: phone_digits || lid_digits).perform
  end

  def contact
    find_contact || inbox.account.contacts.create!(
      name: participant['name'].presence || phone_number || lid_digits,
      phone_number: phone_number,
      identifier: phone_digits ? "#{phone_digits}@s.whatsapp.net" : "#{lid_digits}@lid"
    )
  end

  def find_contact
    contacts = inbox.account.contacts
    contact = contacts.find_by(phone_number: phone_number_variants) if phone_number
    contact || lid_mapping&.contact || contacts.find_by(identifier: participant_jids)
  end

  def phone_number
    "+#{phone_digits}" if phone_digits
  end

  # A Brazilian mobile may have been saved with or without the ninth digit.
  def phone_number_variants
    variant = case phone_digits
              when /\A(55\d{2})9(\d{8})\z/ then "#{Regexp.last_match(1)}#{Regexp.last_match(2)}"
              when /\A(55\d{2})(\d{8})\z/ then "#{Regexp.last_match(1)}9#{Regexp.last_match(2)}"
              end
    [phone_number, variant && "+#{variant}"].compact
  end

  # Picked the way an incoming message picks it, so the member's reply lands where the agent is.
  def existing_conversation
    conversations = inbox.conversations.where(contact_id: contact_inbox.contact_id)
    inbox.lock_to_single_conversation ? conversations.last : conversations.where.not(status: :resolved).last
  end

  def open_conversation
    conversation = ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id,
      status: :open,
      assignee_id: user.id,
      team_id: team_id,
      additional_attributes: { 'origin_group' => { 'conversation_id' => group_conversation.display_id,
                                                   'name' => group_conversation.contact.name } }
    )
    record_activity(conversation)
    conversation
  end

  # Setting a team the agent is not part of unassigns them and lets the team round robin hand the
  # conversation to someone else.
  def team_id
    group_conversation.team_id if group_conversation.team&.members&.include?(user)
  end

  def record_activity(conversation)
    participant_name = conversation.contact.name
    record(group_conversation, I18n.t('conversations.activity.group_participant_conversation.opened_in_group',
                                      user_name: user.name, participant_name: participant_name))
    record(conversation, I18n.t('conversations.activity.group_participant_conversation.opened_from_group',
                                user_name: user.name, group_name: group_conversation.contact.name))
  end

  def record(conversation, content)
    ::Conversations::ActivityMessageJob.perform_later(
      conversation,
      { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity, content: content }
    )
  end
end
