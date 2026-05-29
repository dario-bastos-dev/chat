# frozen_string_literal: true

class AddColorToStages < ActiveRecord::Migration[7.0]
  def change
    add_column :stages, :color, :string, default: '#1f93ff'
    add_column :stages, :stage_type, :string, default: 'active'
  end
end
