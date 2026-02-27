class MessageSequences::ProcessJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    MessageSequence.active.find_each do |sequence|
      # Here we apply the logic to find conversations that might need a sequence message
      conversations = find_applicable_conversations(sequence)
      
      conversations.find_each do |conversation|
        # Process what step of the sequence should be fired next based on inactivity duration
        last_contact_message = conversation.messages.incoming.last
        next unless last_contact_message
        
        inactivity_duration = Time.current - last_contact_message.created_at
        
        # Example pseudo-logic to trigger step based on wait_time (HH:MM format)
        sequence.steps.order(:position).each do |step|
          hours, minutes = step.wait_time.split(':').map(&:to_i)
          step_wait_duration = hours.hours + minutes.minutes
          
          # We need to ensure we only send this step once per conversation
          # (A tracking mechanism should be implemented, e.g., a join table `conversation_message_sequence_steps_logs`)
          # For brevity in the MVP, we assume basic execution logic.
        end
      end
    end
  end

  private

  def find_applicable_conversations(sequence)
    # Filter by Inbox Scope
    inboxes = sequence.selected_inboxes? ? sequence.inboxes : sequence.account.inboxes
    conversations = Conversation.where(inbox: inboxes).resolved.invert # Active conversations

    # Filter by Activation Type
    if sequence.tag?
      # Return conversations that have the tag
      label = sequence.account.labels.find_by(title: sequence.activation_tag)
      conversations.joins(:taggings).where(taggings: { tag_id: label.id }) if label
    else
      # Always active
      conversations
    end
  end
end
