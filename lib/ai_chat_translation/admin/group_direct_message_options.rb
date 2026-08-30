# frozen_string_literal: true

module AiChatTranslation
  module Admin
    class GroupDirectMessageOptions
      def self.all
        Chat::Channel
          .where(chatable_type: "DirectMessage")
          .joins(
            "INNER JOIN direct_message_channels ON " \
              "direct_message_channels.id = chat_channels.chatable_id",
          )
          .where(direct_message_channels: { group: true })
          .order(:id)
          .map { |channel| { id: channel.id, title: title_for(channel) } }
      end

      def self.title_for(channel)
        channel.name.presence || I18n.t("ai_chat_translation.admin.group_direct_messages.unnamed", id: channel.id)
      end
      private_class_method :title_for
    end
  end
end
