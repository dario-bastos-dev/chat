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
  belongs_to :macro, optional: true

  enum step_type: { send_message: 0, send_image: 1, send_document: 2, send_audio: 3, execute_macro: 4, send_template: 5 }

  has_one_attached :file

  validates :content, presence: true, if: :send_message?
  validates :macro_id, presence: true, if: :execute_macro?
  validates :template_params, presence: true, if: :send_template?
  validates :wait_time, presence: true, format: { with: /\A\d+:\d{2}:\d{2}:\d{2}\z/ }
  validates :position, presence: true
  validate :acceptable_file

  before_validation :clean_unused_fields

  private

  def clean_unused_fields
    self.macro_id = nil if macro_id.blank? || !execute_macro?
    self.template_params = nil if template_params.blank? || !send_template?
    file.purge if file.attached? && (send_message? || execute_macro? || send_template?)
  end

  def acceptable_file
    return unless file.attached?

    if send_image?
      errors.add(:file, 'precisa ser uma imagem válida') unless file.content_type.to_s.start_with?('image/')
    elsif send_audio?
      errors.add(:file, 'precisa ser um áudio válido') unless file.content_type.to_s.start_with?('audio/', 'video/mp4') # Alguns áudios como mp4a podem cair em video ou application
    elsif send_document?
      if file.content_type.to_s.start_with?('image/', 'audio/', 'video/')
        errors.add(:file, 'precisa ser um documento válido, não uma mídia')
      end
    end
  end
end
