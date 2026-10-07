class Api::V1::Accounts::Conversations::SidebarCountsController < Api::V1::Accounts::BaseController
  def index
    render json: { payload: ::Conversations::SidebarCounter.new(account: Current.account, user: Current.user).perform }
  end
end
