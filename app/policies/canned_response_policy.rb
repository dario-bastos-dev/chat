class CannedResponsePolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    true
  end

  def show?
    visible_to_user?
  end

  def update?
    author_or_admin?
  end

  def destroy?
    author_or_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.with_visibility(user, account_user)
    end
  end

  private

  def visible_to_user?
    @account_user.administrator? || record.global? || author? || (record.team_visibility? && team_member?)
  end

  def author_or_admin?
    @account_user.administrator? || author?
  end

  def author?
    record.created_by_id == @account_user.user_id
  end

  def team_member?
    record.team_id.present? && @account_user.user.teams.exists?(id: record.team_id)
  end
end
