# frozen_string_literal: true

class DealPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    # Agents can see their own deals or if they're admin
    @account_user.administrator? || record_belongs_to_user?
  end

  def create?
    true
  end

  def update?
    # Agents can update their own deals or if they're admin
    @account_user.administrator? || record_belongs_to_user?
  end

  def destroy?
    @account_user.administrator?
  end

  def move?
    # Agents can move their own deals or if they're admin
    @account_user.administrator? || record_belongs_to_user?
  end

  def assign?
    @account_user.administrator?
  end

  def win?
    @account_user.administrator? || record_belongs_to_user?
  end

  def lose?
    @account_user.administrator? || record_belongs_to_user?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if @account_user.administrator?
        scope.all
      else
        scope.where(assignee_id: @user.id)
             .or(scope.where(assignee_id: nil))
      end
    end
  end

  private

  def record_belongs_to_user?
    return true if record.assignee_id.nil? # Unassigned deals can be accessed by anyone
    
    record.assignee_id == @user.id
  end
end
