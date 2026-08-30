# frozen_string_literal: true

module AiChatTranslation
  class LocalizationsController < ::ApplicationController
    before_action :ensure_logged_in
    before_action :ensure_translation_integration_available
    before_action :ensure_enabled

    def show
      channel = Chat::Channel.find_by(id: params[:channel_id])
      raise ActiveRecord::RecordNotFound if channel.blank?
      raise Discourse::InvalidAccess if !guardian.can_preview_chat_channel?(channel)

      message = channel.chat_messages.find_by(id: params[:message_id])
      raise ActiveRecord::RecordNotFound if message.blank?

      render json: LocalizationPayloadQuery.call(message:, locale: I18n.locale)
    end

    private

    def ensure_translation_integration_available
      return if AiChatTranslation.translation_integration_available?

      render json: failed_json.merge(error: I18n.t("ai_chat_translation.errors.disabled")),
             status: :bad_request
    end

    def ensure_enabled
      return if AiChatTranslation.enabled?

      render json: failed_json.merge(error: I18n.t("ai_chat_translation.errors.disabled")),
             status: :bad_request
    end
  end
end
