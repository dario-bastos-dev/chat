# == Schema Information
#
# Table name: whatsapp_template_media
#
#  id            :bigint           not null, primary key
#  language      :string           not null
#  template_name :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#
# Indexes
#
#  index_whatsapp_template_media_on_account_and_template  (account_id,template_name,language) UNIQUE
#

# Keeps the media a template was created with, so sending it does not depend on Meta's approval
# sample. Meta requires the header media on every send and only stores the sample it reviewed, whose
# URL is signed and expires — this record is the stable copy the send points Meta at.
#
# Scoped to the account: the same template name can exist on several inboxes of the same WABA and the
# media is the same for all of them.
class WhatsappTemplateMedia < ApplicationRecord
  self.table_name = 'whatsapp_template_media'

  belongs_to :account
  has_one_attached :file

  validates :template_name, presence: true, uniqueness: { scope: [:account_id, :language] }
  validates :language, presence: true

  # Maps [name, language] to the media URL for every template of the account that has one, so a list
  # of templates can be enriched without a query per template.
  def self.url_map(account_id)
    with_attached_file.where(account_id: account_id).each_with_object({}) do |record, map|
      url = record.url
      map[[record.template_name, record.language]] = url if url.present?
    end
  end

  def self.url_for(account_id, template_name, language)
    find_by(account_id: account_id, template_name: template_name, language: language)&.url
  end

  def url
    return unless file.attached?

    ActiveStorage::Current.url_options = Rails.application.routes.default_url_options if ActiveStorage::Current.url_options.blank?
    file.blob.url
  end
end
