module Enterprise::PipelinePolicy
  def create?
    pipeline_manage? || super
  end

  def update?
    pipeline_manage? || super
  end

  def destroy?
    pipeline_manage? || super
  end

  # A role that can configure pipelines, or manage every deal, sees all of them
  # regardless of the pipeline's `restricted` visibility.
  module Scope
    def resolve
      return account_scope if bypasses_visibility?

      super
    end

    private

    def bypasses_visibility?
      (custom_role_permissions & %w[pipeline_manage deal_manage]).any?
    end

    def custom_role_permissions
      @account_user&.custom_role&.permissions || []
    end
  end

  private

  def pipeline_manage?
    @account_user&.custom_role&.permissions&.include?('pipeline_manage') || false
  end
end
