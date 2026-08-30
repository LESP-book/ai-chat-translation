# frozen_string_literal: true

module AiChatTranslation
  module Admin
    class TranslationScopesController < ::Admin::AdminController
      requires_plugin AiChatTranslation::PLUGIN_NAME

      def show
        render json: {
                 channel_options: TranslationScopeOptions.public_channels(current_user),
                 direct_message_channel_options: GroupDirectMessageOptions.all,
               }
      end
    end
  end
end
