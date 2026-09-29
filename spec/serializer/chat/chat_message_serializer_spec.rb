# frozen_string_literal: true

describe Chat::MessageSerializer do
  fab!(:user)
  fab!(:message) { Fabricate(:chat_message, user:, message: "Hello world") }
  let(:guardian) { Guardian.new(user) }

  before do
    enable_current_plugin
    SiteSetting.chat_enabled = true
    SiteSetting.ai_chat_translation_enabled = true
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = "fr|en"
    allow(AiChatTranslation::TranslationConfiguration).to receive(:ready?).and_return(true)
    allow(guardian).to receive(:can_localize_content?).and_return(true)
  end

  it "serializes only current source hash localizations" do
    current_hash = AiChatTranslation::ChatMessageLocalizer.source_hash(message)
    AiChatMessageLocalization.create!(
      chat_message: message,
      locale: "fr",
      raw: "Bonjour",
      cooked: "<p>Bonjour</p>",
      source_hash: current_hash,
    )
    AiChatMessageLocalization.create!(
      chat_message: message,
      locale: "ja",
      raw: "古い",
      cooked: "<p>古い</p>",
      source_hash: "old",
    )

    json = described_class.new(message.reload, scope: guardian, root: false).as_json

    expect(json[:ai_chat_localizations]).to contain_exactly(
      { locale: "fr", cooked: "<p>Bonjour</p>", source_hash: current_hash },
    )
  end

  it "marks translations outdated when no localization matches the current source hash" do
    AiChatMessageLocalization.create!(
      chat_message: message,
      locale: "fr",
      raw: "Bonjour",
      cooked: "<p>Bonjour</p>",
      source_hash: "old",
    )

    json = described_class.new(message.reload, scope: guardian, root: false).as_json

    expect(json[:ai_chat_translation_outdated]).to eq(true)
    expect(json[:ai_chat_localizations]).to eq([])
  end
end
