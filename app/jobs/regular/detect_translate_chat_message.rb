# frozen_string_literal: true

module Jobs
  class DetectTranslateChatMessage < ::Jobs::Base
    # 沿用 discourse-ai 的 DetectTranslatePost：检测/翻译失败由后续编辑或回填作业重试，
    # 避免同一条消息在异常时被 Sidekiq 自动重复消耗 AI credit。
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !AiChatTranslation.enabled?
      return if args[:chat_message_id].blank?

      unless DiscourseAi::Translation.credits_available_for_post_detection?
        Rails.logger.info(
          "Chat translation skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      message = Chat::Message.find_by(id: args[:chat_message_id])
      force = args[:force] || false
      return if !AiChatTranslation::ChatMessageCandidates.eligible_message?(message, force:)

      detected_locale = message.locale.presence
      detected_locale ||= AiChatTranslation::ChatMessageLocaleDetector.detect_locale(message)
      return if detected_locale.blank?

      locales = DiscourseAi::Translation.locales
      return if locales.blank?

      current_hash = AiChatTranslation::ChatMessageLocalizer.source_hash(message)
      existing_base_locales =
        message
          .ai_chat_message_localizations
          .where(source_hash: current_hash)
          .pluck(:locale)
          .map { |locale| locale.split("_").first }
          .to_set

      localized = false
      locales.each do |locale|
        next if LocaleNormalizer.is_same?(locale, detected_locale)

        base_locale = locale.to_s.tr("-", "_").split("_").first
        next if !force && existing_base_locales.include?(base_locale)

        localized = true if localize(message, locale).present?
      end

      Chat::Publisher.publish_refresh!(message.chat_channel, message.reload) if localized
    end

    private

    def localize(message, locale)
      AiChatTranslation::ChatMessageLocalizer.localize(message, locale)
    rescue FinalDestination::SSRFDetector::LookupFailedError
      nil
    rescue => e
      DiscourseAi::Translation::VerboseLogger.log(
        "Failed to translate chat message #{message.id} to #{locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
      )
      nil
    end
  end
end
