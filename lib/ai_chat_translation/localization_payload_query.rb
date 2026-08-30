# frozen_string_literal: true

module AiChatTranslation
  class LocalizationPayloadQuery
    def self.call(message:, locale:)
      new(message:, locale:).call
    end

    def initialize(message:, locale:)
      @message = message
      @locale = normalize_locale(locale)
    end

    def call
      source_hash = ChatMessageLocalizer.source_hash(@message)
      localizations =
        AiChatMessageLocalization
          .where(chat_message_id: @message.id, source_hash:, locale: candidate_locales)
          .select(:locale, :cooked, :source_hash)
          .to_a

      localization =
        localizations.find { |candidate| normalize_locale(candidate.locale) == @locale } ||
          localizations.find { |candidate| LocaleNormalizer.is_same?(candidate.locale, @locale) }

      {
        source_hash:,
        localization:
          if localization
            {
              locale: localization.locale,
              cooked: localization.cooked,
              source_hash: localization.source_hash,
            }
          end,
      }
    end

    private

    def candidate_locales
      ([
        @locale,
      ] + DiscourseAi::Translation.locales.filter_map do |candidate|
        normalized = normalize_locale(candidate)
        normalized if LocaleNormalizer.is_same?(normalized, @locale)
      end).uniq
    end

    def normalize_locale(locale)
      locale.to_s.tr("-", "_")
    end
  end
end
