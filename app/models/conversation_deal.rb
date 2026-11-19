# frozen_string_literal: true

# == Schema Information
#
# Table name: conversation_deals
#
#  id              :bigint           not null, primary key
#  is_primary      :boolean          default(FALSE)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :bigint           not null
#  deal_id         :bigint           not null
#
# Indexes
#
#  index_conversation_deals_on_conversation_id  (conversation_id)
#  index_conversation_deals_on_deal_id          (deal_id)
#  index_conversation_deals_unique              (conversation_id,deal_id) UNIQUE
#

class ConversationDeal < ApplicationRecord
  belongs_to :conversation
  belongs_to :deal

  validates :conversation_id, uniqueness: { scope: :deal_id }

  before_save :ensure_single_primary

  scope :primary, -> { where(is_primary: true) }

  private

  def ensure_single_primary
    return unless is_primary && is_primary_changed?

    deal.conversation_deals.where.not(id: id).update_all(is_primary: false)
  end
end
