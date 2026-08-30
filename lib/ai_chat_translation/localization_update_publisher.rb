# frozen_string_literal: true

module AiChatTranslation
  class LocalizationUpdatePublisher
    EVENT_TYPE = "ai_chat_localization_updated"

    def self.publish!(message)
      channel = message.chat_channel
      targets = Chat::Publisher.calculate_publish_targets(channel, message)

      Chat::Publisher.publish_to_targets!(
        targets,
        channel,
        {
          type: EVENT_TYPE,
          chat_message_id: message.id,
          source_hash: ChatMessageLocalizer.source_hash(message),
        },
      )
    end
  end
end
