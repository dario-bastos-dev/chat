class AddTemplateParamsToMessageSequenceSteps < ActiveRecord::Migration[7.0]
  def change
    add_column :message_sequence_steps, :template_params, :jsonb
  end
end
