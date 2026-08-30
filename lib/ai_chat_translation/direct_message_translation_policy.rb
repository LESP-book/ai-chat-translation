# frozen_string_literal: true

module AiChatTranslation
  class DirectMessageTranslationPolicy
    def self.allowed_channel_ids
      SiteSetting
        .ai_chat_translation_allowed_direct_message_channel_ids
        .to_s
        .split("|")
        .filter_map { |id| Integer(id, exception: false) }
        .uniq
    end

    def self.eligible_channel?(channel)
      channel.present? && channel.direct_message_channel? && channel.direct_message_group? &&
        allowed_channel_ids.include?(channel.id)
    end

    def self.scope_condition(channel_column:)
      ids = allowed_channel_ids
      return ["1 = 0", {}] if ids.blank?

      [
        "chat_channels.chatable_type = 'DirectMessage' AND " \
          "#{channel_column} IN (:direct_message_channel_ids) AND " \
          "chat_channels.chatable_id IN " \
          "(SELECT id FROM direct_message_channels WHERE direct_message_channels.group = TRUE)",
        { direct_message_channel_ids: ids },
      ]
    end

    def self.cache_key
      allowed_channel_ids.sort.join("|")
    end
  end
end
