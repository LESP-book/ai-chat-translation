# frozen_string_literal: true

class CreateAiChatTranslationTables < ActiveRecord::Migration[8.0]
  def up
    add_column :chat_messages, :locale, :string, limit: 20 if !column_exists?(:chat_messages, :locale)
    add_index :chat_messages, :locale if !index_exists?(:chat_messages, :locale)

    return if table_exists?(:ai_chat_message_localizations)

    create_table :ai_chat_message_localizations do |t|
      t.bigint :chat_message_id, null: false
      t.string :locale, limit: 20, null: false
      t.text :raw
      t.text :cooked
      t.string :source_hash, limit: 64, null: false
      t.integer :localizer_user_id
      t.timestamps
    end

    add_index(
      :ai_chat_message_localizations,
      %i[chat_message_id locale],
      unique: true,
      name: "idx_ai_chat_msg_localizations_on_msg_id_locale",
    )
    add_index :ai_chat_message_localizations, :locale
    add_index :ai_chat_message_localizations, :source_hash
  end

  def down
    drop_table :ai_chat_message_localizations if table_exists?(:ai_chat_message_localizations)
    remove_index :chat_messages, :locale if index_exists?(:chat_messages, :locale)
    remove_column :chat_messages, :locale if column_exists?(:chat_messages, :locale)
  end
end
