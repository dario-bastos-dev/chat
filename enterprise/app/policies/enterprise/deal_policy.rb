module Enterprise::DealPolicy
  def show?
    custom_role_permissions? ? permitted_by_custom_role? : super
  end

  def update?
    custom_role_permissions? ? permitted_by_custom_role? : super
  end

  def move?
    update?
  end

  def win?
    update?
  end

  def lose?
    update?
  end

  def assign?
    custom_role_permissions? ? manage_all_deals? : super
  end

  def destroy?
    custom_role_permissions? ? manage_all_deals? : super
  end

  # Scoping for the Kanban/list endpoints. Prepended into DealPolicy::Scope so
  # the permission filter is applied before pagination.
  module Scope
    def resolve
      return super unless custom_role_permissions?

      case widest_deal_permission
      when 'deal_manage' then account_scope
      when 'deal_team_manage' then account_scope.where(assignee_id: teammate_ids + [@user.id, nil])
      when 'deal_unassigned_manage' then account_scope.where(assignee_id: [@user.id, nil])
      when 'deal_own_manage' then account_scope.where(assignee_id: @user.id)
      else account_scope.none
      end
    end

    private

    def widest_deal_permission
      CustomRole::DEAL_PERMISSIONS.find { |permission| custom_role_permissions.include?(permission) }
    end

    def teammate_ids
      TeamMember.where(team_id: @user.teams.where(account_id: @account.id).select(:id)).pluck(:user_id)
    end

    def custom_role_permissions?
      @account_user&.custom_role_id.present?
    end

    def custom_role_permissions
      @account_user&.custom_role&.permissions || []
    end
  end

  private

  def permitted_by_custom_role?
    return true if manage_all_deals?
    return own? || unassigned? || teammate_owned? if custom_role_permissions.include?('deal_team_manage')
    return own? || unassigned? if custom_role_permissions.include?('deal_unassigned_manage')
    return own? if custom_role_permissions.include?('deal_own_manage')

    false
  end

  def manage_all_deals?
    custom_role_permissions.include?('deal_manage')
  end

  def teammate_owned?
    return false if record.assignee_id.blank?

    TeamMember.where(user_id: record.assignee_id, team_id: @user.teams.where(account_id: @account.id).select(:id)).exists?
  end

  def custom_role_permissions?
    @account_user&.custom_role_id.present?
  end

  def custom_role_permissions
    @account_user&.custom_role&.permissions || []
  end
end
