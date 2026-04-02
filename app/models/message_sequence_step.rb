# == Schema Information
#
# Table name: message_sequence_steps
#
#  id                  :bigint           not null, primary key
#  message_sequence_id :bigint           not null
#  position            :integer          not null
#  step_type           :integer          default("send_message"), not null
#  content             :text
#  wait_time           :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
class MessageSequenceStep < ApplicationRecord
  belongs_to :message_sequence

  enum step_type: { send_message: 0, send_attachment: 1 }

  has_one_attached :file

  validates :content, presence: true, if: :send_message?
  validates :wait_time, presence: true, format: { with: /\A\d+:\d{2}:\d{2}:\d{2}\z/ }
  validates :position, presence: true
end
