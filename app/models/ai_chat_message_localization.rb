# frozen_string_literal: true

class AiChatMessageLocalization < ActiveRecord::Base
  belongs_to :chat_message, class_name: "Chat::Message"
  belongs_to :localizer_user, class_name: "User", optional: true

  validates :chat_message_id, :locale, :source_hash, presence: true
  validates :locale, uniqueness: { scope: :chat_message_id }
end
