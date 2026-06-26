# frozen_string_literal: true

module Jobs
  class ChatMessageLocalizationBackfill < ::Jobs::Scheduled
    every 15.minutes
    cluster_concurrency 1

    REDIS_KEY = "ai-chat-translation:localize_chat_messages:in_progress"

    def execute(args)
      return if !AiChatTranslation.backfill_enabled?

      return if Discourse.redis.get(REDIS_KEY).to_i > 0

      unless DiscourseAi::Translation.credits_available_for_post_localization?
        Rails.logger.info(
          "Chat localization backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      limit = SiteSetting.ai_chat_translation_backfill_hourly_rate / (60 / 15)
      return if limit <= 0

      pairs = AiChatTranslation::ChatMessageCandidates.needs_localization(limit:)
      return if pairs.blank?

      parallel_jobs = SiteSetting.ai_translation_backfill_parallel_jobs
      chunks = pairs.each_slice((pairs.size.to_f / parallel_jobs).ceil).to_a

      # 这里沿用 discourse-ai 帖子翻译 backfill 的 15 分钟 Redis TTL。
      # 它不是新增业务超时，而是用于防止后台进度计数因 job 崩溃永久卡住。
      Discourse.redis.setex(REDIS_KEY, 15.minutes.to_i, chunks.size)
      chunks.each { |chunk| Jobs.enqueue(:localize_chat_messages, pairs: chunk, backfill: true) }
    end
  end
end
