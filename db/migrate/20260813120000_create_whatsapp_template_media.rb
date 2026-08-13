class CreateWhatsappTemplateMedia < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_template_media do |t|
      t.bigint :account_id, null: false
      t.string :template_name, null: false
      t.string :language, null: false

      t.timestamps
    end

    # Templates are identified by name + language everywhere else in the app, and the media is shared
    # across every inbox of the account that carries the same template.
    add_index :whatsapp_template_media,
              [:account_id, :template_name, :language],
              unique: true,
              name: 'index_whatsapp_template_media_on_account_and_template'
  end
end
