class DisableReportRollupForAllAccounts < ActiveRecord::Migration[7.1]
  def up
    return unless Account.respond_to?(:feature_report_rollup)

    Account.feature_report_rollup.find_each(batch_size: 100) do |account|
      account.disable_features(:report_rollup)
      account.save!(validate: false)
    end
  end
end
