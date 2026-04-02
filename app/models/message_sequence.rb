# == Schema Information
#
# Table name: message_sequences
#
#  id              :bigint           not null, primary key
#  account_id      :bigint           not null
#  created_by_id   :bigint
#  updated_by_id   :bigint
#  name            :string           not null
#  activation_type :integer          default("tag"), not null
#  activation_tag  :string
#  inbox_scope     :integer          default("all_inboxes"), not null
#  active          :boolean          default(true)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class MessageSequence < ApplicationRecord
  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true
  belongs_to :macro, optional: true

  has_many :steps, class_name: 'MessageSequenceStep', dependent: :destroy
  has_many :message_sequence_inboxes, dependent: :destroy
  has_many :inboxes, through: :message_sequence_inboxes
  has_many :conversation_message_sequences, dependent: :destroy

  enum activation_type: { tag: 0, always_active: 1 }
  enum inbox_scope: { all_inboxes: 0, selected_inboxes: 1 }

  validates :name, presence: true
  validates :activation_tag, presence: true, if: :tag?

  accepts_nested_attributes_for :steps, allow_destroy: true
  accepts_nested_attributes_for :message_sequence_inboxes, allow_destroy: true

  scope :active, -> { where(active: true) }
end
