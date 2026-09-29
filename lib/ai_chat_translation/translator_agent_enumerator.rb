# frozen_string_literal: true

require "enum_site_setting"

module AiChatTranslation
  class TranslatorAgentEnumerator < ::EnumSiteSetting
    def self.valid_value?(_value)
      true # Match the official agent enum: retain deleted selections so they fail closed at runtime.
    end

    def self.values
      options = [
        {
          name: I18n.t("ai_chat_translation.follow_official_post_agent"),
          value: TranslationConfiguration::FOLLOW_OFFICIAL,
        },
      ]
      return options unless defined?(::DiscourseAi::Configuration::AgentEnumerator)

      options + DiscourseAi::Configuration::AgentEnumerator.values
    end
  end
end
