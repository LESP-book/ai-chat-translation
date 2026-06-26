# frozen_string_literal: true

module Jobs
  class LocalizeChatMessages < ::Jobs::Base
    # 沿用 discourse-ai 的 LocalizePosts：backfill 会在后续周期重新发现未完成项，
    # 不依赖 Sidekiq 对同一批次自动重试，避免重复消耗 AI credit。
    sidekiq_options retry: false

    def execute(args)
      @backfill = args[:backfill]
      return if !AiChatTranslation.enabled?

      pairs = args[:pairs] || []
      return if pairs.blank?

      unless DiscourseAi::Translation.credits_available_for_post_localization?
        Rails.logger.info(
          "Chat localization skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      pairs.each do |chat_message_id, locale|
        message = ::Chat::Message.find_by(id: chat_message_id)
        next if !AiChatTranslation::ChatMessageCandidates.eligible_message?(message, force: true)

        localization = AiChatTranslation::ChatMessageLocalizer.localize(message, locale)
        ::Chat::Publisher.publish_refresh!(message.chat_channel, message.reload) if localization.present?
      rescue FinalDestination::SSRFDetector::LookupFailedError
        nil
      rescue => e
        DiscourseAi::Translation::VerboseLogger.log(
          "Failed to backfill chat message #{chat_message_id} to #{locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
        )
      end
    ensure
      decrement_backfill_counter if @backfill
    end

    private

    def decrement_backfill_counter
      current = Discourse.redis.decr(Jobs::ChatMessageLocalizationBackfill::REDIS_KEY)
      Discourse.redis.del(Jobs::ChatMessageLocalizationBackfill::REDIS_KEY) if current <= 0
    end
  end
end
