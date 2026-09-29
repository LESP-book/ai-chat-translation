# frozen_string_literal: true

describe Jobs::DetectTranslateChatMessage do
  fab!(:user)
  fab!(:message) { Fabricate(:chat_message, user:, message: "Hello world") }

  before do
    enable_current_plugin
    SiteSetting.chat_enabled = true
    SiteSetting.ai_chat_translation_enabled = true
    SiteSetting.content_localization_supported_locales = "fr|en"
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_translation_enabled = true
    allow(AiChatTranslation::TranslationConfiguration).to receive(:ready?).and_return(true)
    allow(DiscourseAi::Translation).to receive(:locales).and_return(%w[fr en])
    allow(DiscourseAi::Translation).to receive(:credits_available_for_agent_ids?).and_return(true)
  end

  it "detects locale, localizes missing targets, and publishes a compact update" do
    allow(AiChatTranslation::ChatMessageLocaleDetector).to receive(:detect_locale).and_return("en")
    allow(AiChatTranslation::ChatMessageLocalizer).to receive(:localize).and_return(
      instance_double(AiChatMessageLocalization),
    )
    allow(AiChatTranslation::LocalizationUpdatePublisher).to receive(:publish!)

    described_class.new.execute(chat_message_id: message.id)

    expect(AiChatTranslation::ChatMessageLocaleDetector).to have_received(:detect_locale).with(
      a_kind_of(Chat::Message),
    )
    expect(AiChatTranslation::ChatMessageLocalizer).to have_received(:localize).with(
      a_kind_of(Chat::Message),
      "fr",
    )
    expect(AiChatTranslation::LocalizationUpdatePublisher).to have_received(:publish!).with(
      a_kind_of(Chat::Message),
    )
  end

  it "skips when credits are unavailable" do
    allow(DiscourseAi::Translation).to receive(:credits_available_for_agent_ids?).and_return(false)
    allow(AiChatTranslation::ChatMessageLocaleDetector).to receive(:detect_locale)

    described_class.new.execute(chat_message_id: message.id)

    expect(AiChatTranslation::ChatMessageLocaleDetector).not_to have_received(:detect_locale)
  end

  it "checks the detection and Chat models, not the post model, and stops if Chat has no credits" do
    detector_model = Fabricate(:fake_model)
    chat_model = Fabricate(:fake_model)
    post_model = Fabricate(:fake_model)
    AiAgent.find(SiteSetting.ai_translation_locale_detector_agent).update!(default_llm: detector_model)
    chat_agent = Fabricate(:ai_agent, enabled: true, default_llm: chat_model)
    post_agent = Fabricate(:ai_agent, enabled: true, default_llm: post_model)
    SiteSetting.ai_chat_translation_translator_agent = chat_agent.id.to_s
    SiteSetting.ai_translation_post_raw_translator_agent = post_agent.id.to_s
    allow(DiscourseAi::Translation).to receive(:credits_available_for_agent_ids?).and_call_original
    allow(LlmCreditAllocation).to receive(:credits_available?) { |model| model != post_model }
    allow(AiChatTranslation::ChatMessageLocaleDetector).to receive(:detect_locale).and_return("en")
    allow(AiChatTranslation::ChatMessageLocalizer).to receive(:localize).and_return(
      instance_double(AiChatMessageLocalization),
    )
    allow(AiChatTranslation::LocalizationUpdatePublisher).to receive(:publish!)

    described_class.new.execute(chat_message_id: message.id)
    expect(AiChatTranslation::ChatMessageLocalizer).to have_received(:localize).with(
      a_kind_of(Chat::Message),
      "fr",
    )
    expect(LlmCreditAllocation).not_to have_received(:credits_available?).with(post_model)

    allow(LlmCreditAllocation).to receive(:credits_available?) { |model| model != chat_model }
    allow(AiChatTranslation::ChatMessageLocalizer).to receive(:localize).and_call_original
    described_class.new.execute(chat_message_id: message.id)
    expect(AiChatMessageLocalization.count).to eq(0)
  end

  it "uses the selected agent for both live and forced edit translation" do
    agent = Fabricate(:ai_agent, enabled: true)
    SiteSetting.ai_chat_translation_translator_agent = agent.id.to_s
    allow(AiChatTranslation::ChatMessageLocaleDetector).to receive(:detect_locale).and_return("en")
    allow(AiChatTranslation::ChatMessageLocalizer).to receive(:localize)

    described_class.new.execute(chat_message_id: message.id)
    described_class.new.execute(chat_message_id: message.id, force: true)

    expect(DiscourseAi::Translation).to have_received(:credits_available_for_agent_ids?).with(
      [SiteSetting.ai_translation_locale_detector_agent, agent.id.to_s],
    ).twice
  end
end
