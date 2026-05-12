# frozen_string_literal: true

class AddSettingsToPipelines < ActiveRecord::Migration[7.0]
  def change
    add_column :pipelines, :lost_reasons, :jsonb, default: []
    add_column :pipelines, :visibility, :string, default: 'public'
    add_column :pipelines, :allowed_team_ids, :jsonb, default: []
  end
end
