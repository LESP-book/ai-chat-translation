# frozen_string_literal: true

module AiChatTranslation
  module Admin
    class DashboardController < ::Admin::AdminController
      requires_plugin AiChatTranslation::PLUGIN_NAME

      def progress
        if !AiChatTranslation.backfill_enabled?
          return render json: AiChatTranslation::ChatMessageCandidates.empty_progress
        end

        render json: AiChatTranslation::ChatMessageCandidates.get_completion_all_locales
      end

    end
  end
end
