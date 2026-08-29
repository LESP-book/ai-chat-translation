# frozen_string_literal: true

describe Jobs::DetectTranslateChatMessage do
  fab!(:user)
  fab!(:message) { Fabricate(:chat_message, user:, message: "Hello world") }

  before do
    enable_current_plugin
    SiteSetting.chat_enabled = true
    SiteSetting.ai_chat_translation_enabled = true
    SiteSetting.content_localization_supported_locales = "fr|en"
    allow(DiscourseAi::Translation).to receive(:enabled?).and_return(true)
    allow(DiscourseAi::Translation).to receive(:locales).and_return(%w[fr en])
    allow(DiscourseAi::Translation).to receive(:credits_available_for_post_detection?).and_return(true)
  end

  it "detects locale, localizes missing targets, and publishes refresh" do
    allow(AiChatTranslation::ChatMessageLocaleDetector).to receive(:detect_locale).and_return("en")
    allow(AiChatTranslation::ChatMessageLocalizer).to receive(:localize).and_return(
      instance_double(AiChatMessageLocalization),
    )
    allow(Chat::Publisher).to receive(:publish_refresh!)

    described_class.new.execute(chat_message_id: message.id)

    expect(AiChatTranslation::ChatMessageLocaleDetector).to have_received(:detect_locale).with(
      a_kind_of(Chat::Message),
    )
    expect(AiChatTranslation::ChatMessageLocalizer).to have_received(:localize).with(
      a_kind_of(Chat::Message),
      "fr",
    )
    expect(Chat::Publisher).to have_received(:publish_refresh!)
  end

  it "skips when credits are unavailable" do
    allow(DiscourseAi::Translation).to receive(:credits_available_for_post_detection?).and_return(false)
    allow(AiChatTranslation::ChatMessageLocaleDetector).to receive(:detect_locale)

    described_class.new.execute(chat_message_id: message.id)

    expect(AiChatTranslation::ChatMessageLocaleDetector).not_to have_received(:detect_locale)
  end
end
