# frozen_string_literal: true

describe AiChatTranslation::ChatRawTranslator do
  fab!(:user)
  fab!(:message) { Fabricate(:chat_message, user:, message: "Hello world") }

  before do
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    assign_fake_provider_to(:ai_default_llm_model)
  end

  it "passes the dedicated agent and its selected model to the official Bot via the real localizer" do
    model = Fabricate(:fake_model)
    agent = Fabricate(:ai_agent, enabled: true, default_llm: model)
    post_agent_id = SiteSetting.ai_translation_post_raw_translator_agent
    SiteSetting.ai_chat_translation_translator_agent = agent.id.to_s
    bot = instance_double(DiscourseAi::Agents::Bot)
    allow(DiscourseAi::Agents::Bot).to receive(:as) do |_user, agent: selected, model: selected_model|
      expect(selected.id).to eq(agent.id)
      expect(selected_model).to eq(model)
      bot
    end
    allow(bot).to receive(:reply) { |_context, llm_args:, &block| block.call("Bonjour", nil, :text) }

    localization = AiChatTranslation::ChatMessageLocalizer.localize(message, "fr")

    expect(localization.raw).to eq("Bonjour")
    expect(localization.source_hash).to eq(AiChatTranslation::ChatMessageLocalizer.source_hash(message))
    expect(SiteSetting.ai_translation_post_raw_translator_agent).to eq(post_agent_id)

    SiteSetting.ai_chat_translation_translator_agent = "follow_official"
    expect(localization.reload.raw).to eq("Bonjour")
    expect(AiChatMessageLocalization.count).to eq(1)
  end
end
