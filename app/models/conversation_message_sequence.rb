class ConversationMessageSequence < ApplicationRecord
  belongs_to :conversation
  belongs_to :message_sequence

  validates :conversation_id, uniqueness: { scope: :message_sequence_id }

  scope :active, -> { where(active: true) }
end
