# frozen_string_literal: true

module Jobs
  class ChatMessagesLocaleDetectionBackfill < ::Jobs::Scheduled
    every 5.minutes
    # 沿用 discourse-ai 的 PostsLocaleDetectionBackfill：scheduled job 下一轮会重新扫描，
    # 不需要 Sidekiq 对同一次扫描自动重试。
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !AiChatTranslation.backfill_enabled?

      unless DiscourseAi::Translation.credits_available_for_agent_ids?(
               [
                 SiteSetting.ai_translation_locale_detector_agent,
                 AiChatTranslation::TranslationConfiguration.translator_agent_id,
               ],
             )
        Rails.logger.info(
          "Chat locale detection backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      limit = SiteSetting.ai_chat_translation_backfill_hourly_rate / (60 / 5)
      return if limit <= 0

      messages = AiChatTranslation::ChatMessageCandidates.needs_locale_detection(limit:)
      messages.each do |message|
        AiChatTranslation::ChatMessageLocaleDetector.detect_locale(message)
      rescue FinalDestination::SSRFDetector::LookupFailedError
        nil
      rescue => e
        DiscourseAi::Translation::VerboseLogger.log(
          "Failed to detect chat message #{message.id}'s locale: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
        )
      end
    end
  end
end
