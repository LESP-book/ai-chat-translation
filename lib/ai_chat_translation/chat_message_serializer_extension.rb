# frozen_string_literal: true

module AiChatTranslation
  module ChatMessageSerializerExtension
    def self.prepended(base)
      base.attributes(
        :locale,
        :ai_chat_localizations,
        :ai_chat_translation_outdated,
        :can_translate_chat_message,
      )
    end

    def locale
      object.locale
    end

    def ai_chat_localizations
      current_hash = ChatMessageLocalizer.source_hash(object)

      ai_chat_message_localizations
        .select { |localization| localization.source_hash == current_hash }
        .map do |localization|
          {
            locale: localization.locale,
            cooked: localization.cooked,
            source_hash: localization.source_hash,
          }
        end
    end

    def ai_chat_translation_outdated
      localizations = ai_chat_message_localizations
      return false if localizations.blank?

      current_hash = ChatMessageLocalizer.source_hash(object)
      localizations.none? { |localization| localization.source_hash == current_hash }
    end

    def can_translate_chat_message
      return false if scope.blank? || !scope.respond_to?(:can_localize_content?)
      return false if !scope.can_localize_content?

      ChatMessageCandidates.eligible_message?(object, force: true)
    end

    private

    def ai_chat_message_localizations
      @ai_chat_message_localizations ||=
        if object.association(:ai_chat_message_localizations).loaded?
          object.ai_chat_message_localizations
        else
          object.ai_chat_message_localizations.to_a
        end
    end
  end
end
