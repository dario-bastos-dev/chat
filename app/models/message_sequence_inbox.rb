# == Schema Information
#
# Table name: message_sequence_inboxes
#
#  id                  :bigint           not null, primary key
#  message_sequence_id :bigint           not null
#  inbox_id            :bigint           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
class MessageSequenceInbox < ApplicationRecord
  belongs_to :message_sequence
  belongs_to :inbox
end
