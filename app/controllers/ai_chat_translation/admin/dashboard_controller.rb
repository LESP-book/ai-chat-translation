# frozen_string_literal: true

module AiChatTranslation
  module Admin
    class DashboardController < ::Admin::AdminController
      requires_plugin AiChatTranslation::PLUGIN_NAME

      def progress
        return render json: AiChatTranslation.empty_progress unless AiChatTranslation.translation_integration_available?
        return render json: AiChatTranslation.empty_progress unless AiChatTranslation.backfill_enabled?

        render json: AiChatTranslation::ChatMessageCandidates.get_completion_all_locales
      end

    end
  end
end
