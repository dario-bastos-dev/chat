# == Schema Information
#
# Table name: custom_roles
#
#  id          :bigint           not null, primary key
#  description :string
#  name        :string
#  permissions :text             default([]), is an Array
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_custom_roles_on_account_id  (account_id)
#
#

# Available permissions for custom roles:
# - 'conversation_manage': Can manage all conversations.
# - 'conversation_team_manage': Can manage their own, unassigned and their team's conversations.
# - 'conversation_unassigned_manage': Can manage unassigned conversations and assign to self.
# - 'conversation_participating_manage': Can manage conversations they are participating in (assigned to or a participant).
# - 'contact_manage': Can manage contacts.
# - 'report_manage': Can manage reports.
# - 'knowledge_base_manage': Can manage knowledge base portals.
# - 'deal_manage': Can manage all deals.
# - 'deal_team_manage': Can manage their own, unassigned and their team's deals.
# - 'deal_unassigned_manage': Can manage unassigned deals and those assigned to them.
# - 'deal_own_manage': Can manage only the deals assigned to them.
# - 'pipeline_manage': Can manage pipelines and their stages.

class CustomRole < ApplicationRecord
  belongs_to :account
  has_many :account_users, dependent: :nullify

  PERMISSIONS = %w[
    conversation_manage
    conversation_team_manage
    conversation_unassigned_manage
    conversation_participating_manage
    contact_manage
    report_manage
    knowledge_base_manage
    deal_manage
    deal_team_manage
    deal_unassigned_manage
    deal_own_manage
    pipeline_manage
  ].freeze

  # Deal permissions ordered from the widest scope to the narrowest. The first
  # one present on a role wins, so a role holding both `deal_manage` and
  # `deal_own_manage` resolves to `deal_manage`.
  DEAL_PERMISSIONS = %w[
    deal_manage
    deal_team_manage
    deal_unassigned_manage
    deal_own_manage
  ].freeze

  validates :name, presence: true
  validates :permissions, inclusion: { in: PERMISSIONS }
end
