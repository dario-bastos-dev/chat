# frozen_string_literal: true

class CreateStages < ActiveRecord::Migration[7.0]
  def change
    create_table :stages do |t|
      t.references :pipeline, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.integer :win_probability, default: 0
      t.integer :rotting_days

      t.timestamps
    end

    add_index :stages, [:pipeline_id, :position], unique: true, name: 'index_stages_on_pipeline_id_and_position'
  end
end
