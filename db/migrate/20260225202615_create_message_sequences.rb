class CreateMessageSequences < ActiveRecord::Migration[7.0]
  def change
    create_table :message_sequences do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }
      
      t.string :name, null: false
      t.integer :activation_type, default: 0, null: false # tag: 0, always_active: 1
      t.string :activation_tag
      t.integer :inbox_scope, default: 0, null: false # all: 0, selected: 1
      t.boolean :active, default: true
      
      t.timestamps
    end

    create_table :message_sequence_steps do |t|
      t.references :message_sequence, null: false, foreign_key: true, index: true
      t.integer :position, null: false
      t.integer :step_type, default: 0, null: false # send_message: 0, send_attachment: 1
      t.text :content
      t.string :wait_time, null: false
      
      t.timestamps
    end

    create_table :message_sequence_inboxes do |t|
      t.references :message_sequence, null: false, foreign_key: true, index: true
      t.references :inbox, null: false, foreign_key: true, index: true
      
      t.timestamps
    end
    
    add_index :message_sequence_inboxes, [:message_sequence_id, :inbox_id], unique: true, name: 'idx_msg_seq_inboxes_uniq'
  end
end
