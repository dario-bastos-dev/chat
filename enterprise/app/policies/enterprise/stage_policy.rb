module Enterprise::StagePolicy
  def create?
    pipeline_manage? || super
  end

  def update?
    pipeline_manage? || super
  end

  def destroy?
    pipeline_manage? || super
  end

  def reorder?
    pipeline_manage? || super
  end

  private

  def pipeline_manage?
    @account_user&.custom_role&.permissions&.include?('pipeline_manage') || false
  end
end
