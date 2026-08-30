# frozen_string_literal: true

describe AiChatTranslation::LocalizationPayloadQuery do
  fab!(:user)
  fab!(:message) { Fabricate(:chat_message, user:, message: "Hello world", locale: "en") }

  before do
    enable_current_plugin
    allow(DiscourseAi::Translation).to receive(:locales).and_return(%w[fr fr_CA])
  end

  def create_localization(locale:, source_hash: AiChatTranslation::ChatMessageLocalizer.source_hash(message))
    AiChatMessageLocalization.create!(
      chat_message: message,
      locale:,
      raw: "Bonjour",
      cooked: "<p>Bonjour</p>",
      source_hash:,
    )
  end

  it "prefers an exact locale and returns no raw content" do
    create_localization(locale: "fr")
    create_localization(locale: "fr_CA")

    result = described_class.call(message:, locale: "fr_CA")

    expect(result).to eq(
      source_hash: AiChatTranslation::ChatMessageLocalizer.source_hash(message),
      localization: {
        locale: "fr_CA",
        cooked: "<p>Bonjour</p>",
        source_hash: AiChatTranslation::ChatMessageLocalizer.source_hash(message),
      },
    )
  end

  it "falls back to a localization with the same base locale" do
    create_localization(locale: "fr")

    expect(described_class.call(message:, locale: "fr_CA").dig(:localization, :locale)).to eq("fr")
  end

  it "excludes localizations for an outdated source" do
    create_localization(locale: "fr", source_hash: "old")

    expect(described_class.call(message:, locale: "fr").fetch(:localization)).to eq(nil)
  end
end
