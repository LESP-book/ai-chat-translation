# frozen_string_literal: true

# name: ai-chat-translation
# about: AI translation support for Discourse Chat messages
# version: 0.1.0
# authors: kuma
# url: https://github.com/kuma/ai-chat-translation
# required_version: 3.4.0

enabled_site_setting :ai_chat_translation_enabled

module ::AiChatTranslation
  PLUGIN_NAME = "ai-chat-translation"

  def self.enabled?
    defined?(::Chat) && defined?(::DiscourseAi::Translation) && SiteSetting.chat_enabled &&
      SiteSetting.ai_chat_translation_enabled && DiscourseAi::Translation.enabled?
  end

  def self.backfill_enabled?
    enabled? && SiteSetting.ai_chat_translation_backfill_hourly_rate > 0 &&
      SiteSetting.ai_chat_translation_backfill_max_age_days > 0
  end
end

require_relative "lib/ai_chat_translation/engine"

after_initialize do
  next unless defined?(::Chat)
  next unless defined?(::DiscourseAi::Translation)

  %w[
    lib/ai_chat_translation/chat_raw_translator
    lib/ai_chat_translation/chat_message_localizer
    lib/ai_chat_translation/chat_message_locale_detector
    lib/ai_chat_translation/chat_message_candidates
    lib/ai_chat_translation/chat_message_serializer_extension
    lib/ai_chat_translation/messages_query_extension
    app/models/ai_chat_message_localization
    app/controllers/ai_chat_translation/translation_controller
    app/controllers/ai_chat_translation/admin/dashboard_controller
    app/jobs/regular/detect_translate_chat_message
    app/jobs/regular/localize_chat_messages
    app/jobs/scheduled/chat_messages_locale_detection_backfill
    app/jobs/scheduled/chat_message_localization_backfill
  ].each { |path| require_relative path }

  reloadable_patch do
    Chat::Message.has_many(
      :ai_chat_message_localizations,
      class_name: "AiChatMessageLocalization",
      dependent: :destroy,
      foreign_key: :chat_message_id,
    )

    Chat::MessageSerializer.prepend AiChatTranslation::ChatMessageSerializerExtension
    Chat::MessagesQuery.singleton_class.prepend AiChatTranslation::MessagesQueryExtension
  end

  on(:chat_message_created) do |message, _channel, _user|
    next unless AiChatTranslation.enabled?
    Jobs.enqueue(:detect_translate_chat_message, chat_message_id: message.id)
  end

  on(:chat_message_edited) do |message, _channel, _user|
    next unless AiChatTranslation.enabled?
    Jobs.enqueue_in(
      SiteSetting.chat_editing_grace_period.seconds,
      :detect_translate_chat_message,
      chat_message_id: message.id,
      force: true,
    )
  end
end
