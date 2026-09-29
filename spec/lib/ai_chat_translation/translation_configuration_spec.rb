# frozen_string_literal: true

describe AiChatTranslation::TranslationConfiguration do
  before do
    enable_current_plugin
    SiteSetting.chat_enabled = true
    SiteSetting.ai_chat_translation_enabled = true
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = "fr|en"
    assign_fake_provider_to(:ai_default_llm_model)
  end

  it "defaults to the official post agent, including its negative built-in ID" do
    expect(described_class.translator_agent_id).to eq(SiteSetting.ai_translation_post_raw_translator_agent)
    expect(AiChatTranslation.enabled?).to eq(true)
  end

  it "uses the selected agent without changing the official post selection" do
    post_agent_id = SiteSetting.ai_translation_post_raw_translator_agent
    fast_model = Fabricate(:fake_model)
    agent = Fabricate(:ai_agent, enabled: true, default_llm: fast_model)
    SiteSetting.ai_chat_translation_translator_agent = agent.id.to_s

    expect(described_class.translator_agent_id).to eq(agent.id.to_s)
    expect(described_class.ready?).to eq(true)
    expect(SiteSetting.ai_translation_post_raw_translator_agent).to eq(post_agent_id)
  end

  it "ignores unrelated official translation agents when the Chat agents have models" do
    detector = AiAgent.find(SiteSetting.ai_translation_locale_detector_agent)
    detector.update!(default_llm: Fabricate(:fake_model))
    agent = Fabricate(:ai_agent, enabled: true, default_llm: Fabricate(:fake_model))
    SiteSetting.ai_chat_translation_translator_agent = agent.id.to_s
    SiteSetting.ai_default_llm_model = ""

    allow(DiscourseAi::Translation).to receive(:has_llm_model?).and_return(false)
    expect(AiChatTranslation.enabled?).to eq(true)
    expect(DiscourseAi::Translation).not_to have_received(:has_llm_model?)
  end

  it "does not fall back when a selected agent is disabled or missing" do
    agent = Fabricate(:ai_agent, enabled: true, default_llm: Fabricate(:fake_model))
    SiteSetting.ai_chat_translation_translator_agent = agent.id.to_s
    agent.update!(enabled: false)
    allow(DiscourseAi::Agents::Bot).to receive(:as)

    expect(described_class.translator_agent_id).to be_nil
    expect(AiChatTranslation.enabled?).to eq(false)
    expect(AiChatTranslation::ChatRawTranslator.new(text: "Hello", target_locale: "fr").translate).to be_nil

    SiteSetting.ai_chat_translation_translator_agent = "99999999"
    expect(AiChatTranslation::ChatRawTranslator.new(text: "Hello", target_locale: "fr").translate).to be_nil
    expect(described_class.translator_agent_id).to be_nil
    expect(AiChatTranslation.enabled?).to eq(false)
    expect(DiscourseAi::Agents::Bot).not_to have_received(:as)
  end

  it "offers the follow mode even when the official AI integration is unavailable" do
    hide_const("DiscourseAi::Configuration::AgentEnumerator")
    expect(AiChatTranslation::TranslatorAgentEnumerator.values).to eq(
      [{ name: I18n.t("ai_chat_translation.follow_official_post_agent"), value: "follow_official" }],
    )
  end
end
