# frozen_string_literal: true

class StagePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
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

  def reorder?
    administrator?
  end

  private

  def administrator?
    @account_user.administrator?
  end
end

StagePolicy.prepend_mod_with('StagePolicy')
