# frozen_string_literal: true

module AiChatTranslation
  module TranslationConfiguration
    FOLLOW_OFFICIAL = "follow_official"

    def self.translator_agent_id
      selected = SiteSetting.ai_chat_translation_translator_agent
      return SiteSetting.ai_translation_post_raw_translator_agent if selected == FOLLOW_OFFICIAL

      agent = AiAgent.find_by_id_from_cache(selected) if selected.match?(/\A-?\d+\z/)
      return selected if agent&.enabled?

      Rails.logger.warn("Chat translation unavailable: selected agent #{selected.inspect} is missing or disabled")
      nil
    end

    def self.ready?
      translator_id = translator_agent_id
      return false if translator_id.nil?

      detector_id = SiteSetting.ai_translation_locale_detector_agent
      [detector_id, translator_id].all? do |id|
        available =
          AiAgent.find_by_id_from_cache(id).present? &&
            DiscourseAi::Translation.llm_model_for_agent(id).present?
        if !available
          Rails.logger.warn("Chat translation unavailable: agent #{id.inspect} or its model is missing")
        end
        available
      end
    end
  end
end
