# frozen_string_literal: true

module AiChatTranslation
  class TranslationController < ::ApplicationController
    before_action :ensure_logged_in
    before_action :check_permissions
    before_action :rate_limit!

    def translate
      if !AiChatTranslation.enabled?
        return(
          render json: failed_json.merge(error: I18n.t("ai_chat_translation.errors.disabled")),
                 status: :bad_request
        )
      end

      channel = Chat::Channel.find_by(id: params[:channel_id])
      raise ActiveRecord::RecordNotFound if channel.blank?
      raise Discourse::InvalidAccess if !guardian.can_preview_chat_channel?(channel)

      message = channel.chat_messages.find_by(id: params[:message_id])
      raise ActiveRecord::RecordNotFound if message.blank?

      unless ChatMessageCandidates.eligible_message?(message, force: true)
        return(
          render_json_error(
            I18n.t("ai_chat_translation.errors.not_translatable"),
            status: :unprocessable_entity,
          )
        )
      end

      Jobs.enqueue(:detect_translate_chat_message, chat_message_id: message.id, force: true)
      render json: success_json
    end

    private

    def check_permissions
      guardian.ensure_can_localize_content!
    end

    def rate_limit!
      # 与 discourse-ai 帖子翻译控制器保持同一模式：3 次 / 5 分钟；
      # 仅 key 独立，避免聊天手动翻译与帖子手动翻译互相占用额度。
      RateLimiter.new(current_user, "ai_translate_chat_message", 3, 5.minutes).performed!
    rescue RateLimiter::LimitExceeded
      render_json_error(I18n.t("rate_limiter.slow_down"))
    end
  end
end
