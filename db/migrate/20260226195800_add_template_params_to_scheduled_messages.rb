class AddTemplateParamsToScheduledMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :scheduled_messages, :template_params, :jsonb, default: nil
  end
end
