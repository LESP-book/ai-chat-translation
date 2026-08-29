# frozen_string_literal: true

describe AiChatTranslation::ChatMessageLocalizer do
  fab!(:user)
  fab!(:message) { Fabricate(:chat_message, user:, message: "Hello world") }

  before do
    enable_current_plugin
  end

  def stub_translation(raw)
    translator = instance_double(AiChatTranslation::ChatRawTranslator)
    allow(AiChatTranslation::ChatRawTranslator).to receive(:new).and_return(translator)
    allow(translator).to receive(:translate).and_return(raw)
  end

  it "creates a localization with source hash and cooked chat HTML" do
    stub_translation("Bonjour le monde")

    localization = described_class.localize(message, "fr")

    expect(localization).to have_attributes(
      chat_message_id: message.id,
      locale: "fr",
      raw: "Bonjour le monde",
      cooked: "<p>Bonjour le monde</p>",
      source_hash: described_class.source_hash(message),
      localizer_user_id: Discourse.system_user.id,
    )
  end

  it "updates the unique localization for the same message and locale" do
    stub_translation("Bonjour")
    existing = described_class.localize(message, "fr")

    stub_translation("Salut")

    expect { described_class.localize(message, "fr") }.not_to change {
      AiChatMessageLocalization.count
    }
    expect(existing.reload.raw).to eq("Salut")
  end

  it "skips same source and target locale" do
    message.update!(locale: "en")

    expect(described_class.localize(message, "en")).to eq(nil)
  end
end
