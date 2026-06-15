class AddOptimizedIndexesToTaggings < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :taggings, [:tag_id, :taggable_type, :taggable_id],
              name: 'index_taggings_on_tag_and_type_and_id',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
