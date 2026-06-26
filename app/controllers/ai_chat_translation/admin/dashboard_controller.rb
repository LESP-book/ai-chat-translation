# frozen_string_literal: true

module AiChatTranslation
  module Admin
    class DashboardController < ::Admin::AdminController
      requires_plugin AiChatTranslation::PLUGIN_NAME

      def show
        render json: base_result
      end

      def progress
        if !AiChatTranslation.backfill_enabled?
          return render json: AiChatTranslation::ChatMessageCandidates.empty_progress
        end

        render json: AiChatTranslation::ChatMessageCandidates.get_completion_all_locales
      end

      private

      def base_result
        {
          enabled: AiChatTranslation.enabled?,
          backfill_enabled: AiChatTranslation.backfill_enabled?,
          hourly_rate: SiteSetting.ai_chat_translation_backfill_hourly_rate,
          backfill_max_age_days: SiteSetting.ai_chat_translation_backfill_max_age_days,
          allowed_channel_ids: AiChatTranslation::ChatMessageCandidates.allowed_channel_ids,
          channel_options: AiChatTranslation::ChatMessageCandidates.available_channel_options(current_user),
        }
      end
    end
  end
end
