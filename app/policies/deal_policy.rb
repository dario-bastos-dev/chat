# frozen_string_literal: true

class DealPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    scope.exists?(id: record.id)
  end

  def create?
    true
  end

  def update?
    manageable?
  end

  def move?
    manageable?
  end

  def win?
    manageable?
  end

  def lose?
    manageable?
  end

  def assign?
    administrator?
  end

  def destroy?
    administrator?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return account_scope if @account_user.administrator?

      # Plain agents keep the historical reach: their own deals plus the
      # unassigned pool. Custom roles narrow or widen this in the Enterprise
      # overlay.
      account_scope.where(assignee_id: [@user.id, nil])
    end

    private

    def account_scope
      scope.where(account_id: @account.id)
    end
  end

  private

  def administrator?
    @account_user.administrator?
  end

  def manageable?
    administrator? || own? || unassigned?
  end

  def own?
    record.assignee_id == @user.id
  end

  def unassigned?
    record.assignee_id.nil?
  end
end

DealPolicy.prepend_mod_with('DealPolicy')
DealPolicy::Scope.prepend_mod_with('DealPolicy::Scope')
