# frozen_string_literal: true

class PipelinePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    scope.exists?(id: record.id)
  end

  def create?
    administrator?
  end

  def update?
    administrator?
  end

  def destroy?
    administrator?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return account_scope if @account_user.administrator?
      return public_scope if team_ids.empty?

      public_scope.or(account_scope.where(id: restricted_ids_for_teams))
    end

    private

    def account_scope
      scope.where(account_id: @account.id)
    end

    def public_scope
      account_scope.where(visibility: 'public')
    end

    def team_ids
      @team_ids ||= @user.teams.where(account_id: @account.id).pluck(:id)
    end

    # `allowed_team_ids` is a jsonb array of integers, so the `?|` operator is
    # not usable (it only matches string elements). Containment against each
    # team id is the portable option.
    def restricted_ids_for_teams
      account_scope.where(
        'pipelines.allowed_team_ids @> ANY (ARRAY[?]::jsonb[])',
        team_ids.map { |id| "[#{id}]" }
      ).select(:id)
    end
  end

  private

  def administrator?
    @account_user.administrator?
  end
end

PipelinePolicy.prepend_mod_with('PipelinePolicy')
PipelinePolicy::Scope.prepend_mod_with('PipelinePolicy::Scope')
