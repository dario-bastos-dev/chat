# frozen_string_literal: true

class DealActivityPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    @account_user.administrator? || record_belongs_to_user?
  end

  def destroy?
    @account_user.administrator? || record_belongs_to_user?
  end

  def complete?
    true
  end

  private

  def record_belongs_to_user?
    record.user_id == @user.id
  end
end
