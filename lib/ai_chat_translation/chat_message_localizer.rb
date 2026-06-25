# frozen_string_literal: true

module AiChatTranslation
  class ChatMessageLocalizer
    def self.source_hash(message)
      Digest::SHA256.hexdigest(message.message.to_s)
    end

    def self.localize(message, target_locale = I18n.locale, llm_model: nil)
      return if message.blank? || target_locale.blank? || message.message.blank?
      return if LocaleNormalizer.is_same?(message.locale, target_locale)
      return if message.message.length > SiteSetting.ai_translation_max_post_length

      target_locale = target_locale.to_s.sub("-", "_")
      translated_raw =
        ChatRawTranslator.new(text: message.message, target_locale:, llm_model:).translate
      return if translated_raw.blank?

      localization =
        AiChatMessageLocalization.find_or_initialize_by(
          chat_message_id: message.id,
          locale: target_locale,
        )

      localization.raw = translated_raw
      localization.cooked = Chat::Message.cook(translated_raw, user_id: Discourse::SYSTEM_USER_ID)
      localization.source_hash = source_hash(message)
      localization.localizer_user_id = Discourse.system_user.id
      localization.save!
      localization
    end
  end
end
