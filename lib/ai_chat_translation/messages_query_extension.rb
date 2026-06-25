# frozen_string_literal: true

module AiChatTranslation
  module MessagesQueryExtension
    def base_query(...)
      super.includes(:ai_chat_message_localizations)
    end
  end
end
