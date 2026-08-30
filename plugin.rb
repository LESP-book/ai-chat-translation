# frozen_string_literal: true

# name: ai-chat-translation
# about: AI translation support for Discourse Chat messages
# version: 0.2.0
# authors: kuma
# url: https://github.com/kuma/ai-chat-translation
# required_version: 2026.8.0

enabled_site_setting :ai_chat_translation_enabled

add_admin_route "ai_chat_translation.admin.title", "ai-chat-translation", use_new_show_route: true

register_asset "stylesheets/admin/ai-chat-translation-dashboard.scss", :admin

register_svg_icon "language"
register_svg_icon "comments"
register_svg_icon "circle-check"
register_svg_icon "clock"
register_svg_icon "rotate"
register_svg_icon "gear"
register_svg_icon "arrows-rotate"
register_svg_icon "layer-group"

module ::AiChatTranslation
  PLUGIN_NAME = "ai-chat-translation"
  EMPTY_PROGRESS = {
    translation_progress: [],
    total: 0,
    messages_with_detected_locale: 0,
    completed: 0,
    pending: 0,
    percentage: 0,
  }.freeze

  def self.empty_progress
    EMPTY_PROGRESS
  end

  def self.translation_integration_available?
    !!(
      defined?(::Chat) && defined?(::DiscourseAi::Translation) &&
        defined?(::AiChatTranslation::ChatMessageCandidates)
    )
  end

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

# These power settings fields that are registered even when Discourse AI has not
# finished loading. Keep the endpoint available independently of the runtime
# translation integration.
require_relative "lib/ai_chat_translation/admin/group_direct_message_options"
require_relative "lib/ai_chat_translation/admin/translation_scope_options"

after_initialize do
  require_relative "app/controllers/ai_chat_translation/admin/dashboard_controller"
  require_relative "app/controllers/ai_chat_translation/localizations_controller"
  require_relative "app/controllers/ai_chat_translation/translation_controller"
end

after_initialize do
  require_relative "app/controllers/ai_chat_translation/admin/translation_scopes_controller"
end

after_initialize do
  next unless defined?(::Chat)
  next unless defined?(::DiscourseAi::Translation)

  %w[
    lib/ai_chat_translation/chat_raw_translator
    lib/ai_chat_translation/chat_message_localizer
    lib/ai_chat_translation/localization_payload_query
    lib/ai_chat_translation/localization_update_publisher
    lib/ai_chat_translation/chat_message_locale_detector
    lib/ai_chat_translation/direct_message_translation_policy
    lib/ai_chat_translation/chat_message_candidates
    lib/ai_chat_translation/chat_message_serializer_extension
    lib/ai_chat_translation/messages_query_extension
    app/models/ai_chat_message_localization
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
