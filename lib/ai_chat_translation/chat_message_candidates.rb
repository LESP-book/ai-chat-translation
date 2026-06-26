# frozen_string_literal: true

module AiChatTranslation
  class ChatMessageCandidates
    def self.eligible_message?(message, force: false)
      return false if !AiChatTranslation.enabled?
      return false if message.blank? || message.deleted_at.present? || message.streaming?
      return false if message.message.blank?
      return false if message.message.length > SiteSetting.ai_translation_max_post_length
      return false if !eligible_user?(message.user)

      eligible_channel?(message.chat_channel)
    end

    def self.eligible_user?(user)
      return false if user.blank?
      return true if SiteSetting.ai_translation_include_bot_content

      !user.bot? && !user.is_system_user?
    end

    def self.eligible_channel?(channel)
      return false if channel.blank?

      if channel.direct_message_channel?
        case SiteSetting.ai_translation_personal_messages
        when "all"
          true
        when "group"
          channel.direct_message_group?
        else
          false
        end
      else
        channel.chatable_type == "Category" &&
          channel_allowed_by_setting?(channel) &&
          !DiscourseAi::Translation.category_excluded?(channel.chatable_id)
      end
    end

    def self.allowed_channel_ids
      SiteSetting
        .ai_chat_translation_allowed_channel_ids
        .to_s
        .split("|")
        .filter_map { |id| Integer(id, exception: false) }
        .uniq
    end

    def self.channel_allowed_by_setting?(channel)
      ids = allowed_channel_ids
      ids.blank? || ids.include?(channel.id)
    end

    def self.base_scope
      messages =
        Chat::Message
          .includes(:user, chat_channel: :chatable)
          .joins(:chat_channel)
          .where(
            "chat_messages.created_at > ?",
            SiteSetting.ai_chat_translation_backfill_max_age_days.days.ago,
          )
          .where(deleted_at: nil)
          .where(streaming: false)
          .where.not(message: [nil, ""])
          .where("LENGTH(chat_messages.message) <= ?", SiteSetting.ai_translation_max_post_length)

      messages = messages.where("chat_messages.user_id > 0") unless SiteSetting.ai_translation_include_bot_content

      excluded_category_ids = DiscourseAi::Translation.excluded_category_ids
      if excluded_category_ids.present?
        messages =
          messages.where(
            "chat_channels.chatable_type != 'Category' OR chat_channels.chatable_id NOT IN (?)",
            excluded_category_ids,
          )
      end

      allowed_ids = allowed_channel_ids
      messages = messages.where(chat_channel_id: allowed_ids) if allowed_ids.present?

      case SiteSetting.ai_translation_personal_messages
      when "all"
        messages
      when "group"
        messages.where(
          "chat_channels.chatable_type != 'DirectMessage' OR chat_channels.chatable_id IN (SELECT id FROM direct_message_channels WHERE direct_message_channels.group = TRUE)",
        )
      else
        messages.where.not(chat_channels: { chatable_type: "DirectMessage" })
      end
    end

    def self.needs_locale_detection(limit:)
      base_scope.where(locale: nil).order(updated_at: :desc).limit(limit)
    end

    def self.needs_localization(limit:)
      locales = DiscourseAi::Translation.locales
      return [] if locales.blank?

      pairs = []
      base_scope
        .includes(:ai_chat_message_localizations)
        .where.not(locale: nil)
        .order(updated_at: :desc)
        .find_each do |message|
          current_hash = ChatMessageLocalizer.source_hash(message)
          existing_base_locales =
            message
              .ai_chat_message_localizations
              .select { |localization| localization.source_hash == current_hash }
              .map { |localization| localization.locale.split("_").first }
              .to_set

          locales.each do |locale|
            next if LocaleNormalizer.is_same?(locale, message.locale)

            base_locale = locale.to_s.tr("-", "_").split("_").first
            next if existing_base_locales.include?(base_locale)

            pairs << [message.id, locale]
            return pairs if pairs.size >= limit
          end
        end

      pairs
    end

    def self.get_completion_all_locales
      Discourse.cache.fetch(progress_cache_key, expires_in: 30.minutes) { completion_all_locales }
    end

    def self.available_channel_options(user)
      Chat::Channel
        .public_channels
        .where(status: Chat::Channel.statuses[:open])
        .includes(:chatable)
        .order(:id)
        .map do |channel|
          { id: channel.id, title: channel.title(user), messages_count: channel.messages_count }
        end
    end

    def self.progress_cache_key
      [
        "ai-chat-translations-progress",
        SiteSetting.content_localization_supported_locales,
        SiteSetting.ai_chat_translation_backfill_max_age_days,
        SiteSetting.ai_chat_translation_allowed_channel_ids,
        SiteSetting.ai_translation_excluded_categories,
        SiteSetting.ai_translation_include_bot_content,
        SiteSetting.ai_translation_max_post_length,
        SiteSetting.ai_translation_personal_messages,
      ].join(":")
    end

    def self.completion_all_locales
      supported = DiscourseAi::Translation.locales
      return empty_progress if supported.blank?

      totals_by_locale = Hash.new(0)
      done_by_locale = Hash.new(0)
      total = 0
      messages_with_detected_locale = 0

      base_scope.includes(:ai_chat_message_localizations).find_each do |message|
        total += 1
        next if message.locale.blank?

        messages_with_detected_locale += 1
        current_hash = ChatMessageLocalizer.source_hash(message)
        current_localized_bases =
          message
            .ai_chat_message_localizations
            .select { |localization| localization.source_hash == current_hash }
            .map { |localization| localization.locale.to_s.tr("-", "_").split("_").first }
            .to_set

        supported.each do |locale|
          next if LocaleNormalizer.is_same?(locale, message.locale)

          totals_by_locale[locale] += 1
          base_locale = locale.to_s.tr("-", "_").split("_").first
          done_by_locale[locale] += 1 if current_localized_bases.include?(base_locale)
        end
      end

      translation_progress =
        supported
          .map { |locale| { locale:, done: done_by_locale[locale], total: totals_by_locale[locale] } }
          .sort_by do |row|
            percentage = row[:total] > 0 ? row[:done].to_f / row[:total] : 0
            -percentage
          end

      {
        translation_progress: translation_progress,
        total: total,
        messages_with_detected_locale: messages_with_detected_locale,
      }
    end

    def self.empty_progress
      { translation_progress: [], total: 0, messages_with_detected_locale: 0 }
    end
  end
end
