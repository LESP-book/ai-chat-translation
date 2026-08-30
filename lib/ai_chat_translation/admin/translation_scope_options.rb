# frozen_string_literal: true

module AiChatTranslation
  module Admin
    class TranslationScopeOptions
      def self.public_channels(user)
        Chat::Channel
          .public_channels
          .where(status: Chat::Channel.statuses[:open])
          .includes(:chatable)
          .order(:id)
          .map { |channel| { id: channel.id, title: channel.title(user) } }
      end
    end
  end
end
