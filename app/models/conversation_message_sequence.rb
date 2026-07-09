class ConversationMessageSequence < ApplicationRecord
  belongs_to :conversation
  belongs_to :message_sequence

  validates :conversation_id, uniqueness: { scope: :message_sequence_id }

  scope :active, -> { where(active: true) }
  scope :waiting_response, -> { where(waiting_interaction: true) }
  scope :ready_for_execution, -> { active.where(waiting_interaction: false) }
end
