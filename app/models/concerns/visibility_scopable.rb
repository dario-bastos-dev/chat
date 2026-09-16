module VisibilityScopable
  extend ActiveSupport::Concern

  included do
    belongs_to :created_by, class_name: 'User', optional: true
    belongs_to :team, optional: true

    enum visibility: { personal: 0, team_visibility: 1, global: 2 }

    validates :team_id, presence: true, if: :team_visibility?
    validate :creator_must_belong_to_team, if: :team_visibility?

    before_validation :clear_team_id_unless_team_visibility
  end

  class_methods do
    def with_visibility(user, account_user)
      base = Current.account.public_send(model_name.plural)
      return base if account_user.administrator?

      scope = base.global.or(base.personal.where(created_by_id: user.id))
      team_ids = user.teams.pluck(:id)
      scope = scope.or(base.team_visibility.where(team_id: team_ids)) if team_ids.present?
      scope
    end
  end

  private

  def creator_must_belong_to_team
    return if created_by.blank? || team.blank?
    return if created_by.teams.exists?(id: team_id)

    errors.add(:team_id, :not_a_member, message: I18n.t('errors.validations.team_membership'))
  end

  def clear_team_id_unless_team_visibility
    self.team_id = nil unless team_visibility?
  end
end
