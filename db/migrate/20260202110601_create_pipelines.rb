# frozen_string_literal: true

class CreatePipelines < ActiveRecord::Migration[7.0]
  def change
    create_table :pipelines do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.boolean :is_default, default: false

      t.timestamps
    end

    add_index :pipelines, [:account_id, :is_default], name: 'index_pipelines_on_account_id_and_is_default'
  end
end
