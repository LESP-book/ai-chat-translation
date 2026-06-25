# frozen_string_literal: true

module AiChatTranslation
  class ChatRawTranslator < DiscourseAi::Translation::BaseTranslator
    private

    def agent_setting
      SiteSetting.ai_translation_post_raw_translator_agent
    end
  end
end
