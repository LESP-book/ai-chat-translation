# frozen_string_literal: true

module AiChatTranslation
  class ChatRawTranslator < DiscourseAi::Translation::BaseTranslator
    private

    def agent_setting
      TranslationConfiguration.translator_agent_id
    end
  end
end
