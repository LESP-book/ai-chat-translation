# frozen_string_literal: true

module AiChatTranslation
  class ChatMessageLocaleDetector
    def self.detect_locale(message)
      return if message.blank? || message.message.blank?

      detected_locale = DiscourseAi::Translation::LanguageDetector.new(message.message).detect
      return if detected_locale.blank?

      message.update!(locale: detected_locale.to_s.sub("-", "_"))
      detected_locale
    end
  end
end
