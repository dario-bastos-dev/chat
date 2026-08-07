class InboxPolicy < ApplicationPolicy
  class Scope
    attr_reader :user_context, :user, :scope, :account, :account_user

    def initialize(user_context, scope)
      @user_context = user_context
      @user = user_context[:user]
      @account = user_context[:account]
      @account_user = user_context[:account_user]
      @scope = scope
    end

    def resolve
      user.assigned_inboxes
    end
  end

  def index?
    true
  end

  def show?
    # FIXME: for agent bots, lets bring this validation to policies as well in future
    return true if @user.is_a?(AgentBot)

    Current.user.assigned_inboxes.include? record
  end

  def assignable_agents?
    true
  end

  def agent_bot?
    true
  end

  def message_templates?
    true
  end

  def campaigns?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def set_agent_bot?
    @account_user.administrator?
  end

  def avatar?
    @account_user.administrator?
  end

  def sync_templates?
    @account_user.administrator?
  end

  def whatsapp_business_management_token?
    @account_user.administrator?
  end

  def health?
    @account_user.administrator?
  end

  def reset_secret?
    @account_user.administrator?
  end

  def evolution_qrcode?
    @account_user.administrator?
  end

  def evolution_status?
    @account_user.administrator?
  end

  def evolution_create_instance?
    @account_user.administrator?
  end

  def evolution_disconnect?
    @account_user.administrator?
  end

  def evolution_diagnostics?
    @account_user.administrator?
  end

  def evolution_go_qrcode?
    @account_user.administrator?
  end

  def evolution_go_pairing?
    @account_user.administrator?
  end

  def evolution_go_status?
    @account_user.administrator?
  end

  def evolution_go_create_instance?
    @account_user.administrator?
  end

  def evolution_go_disconnect?
    @account_user.administrator?
  end

  def set_inbound_calls?
    @account_user.administrator?
  end
end
