# frozen_string_literal: true

describe AiChatTranslation::TranslationController do
  fab!(:admin)
  fab!(:user)
  fab!(:channel, :category_channel)
  fab!(:message) { Fabricate(:chat_message, user:, chat_channel: channel, message: "Hello world") }

  before do
    enable_current_plugin
    SiteSetting.chat_enabled = true
    SiteSetting.ai_chat_translation_enabled = true
    SiteSetting.ai_chat_translation_allowed_direct_message_channel_ids = ""
    SiteSetting.content_localization_supported_locales = "fr"
    SiteSetting.content_localization_enabled = true
    SiteSetting.allow_user_locale = true
    SiteSetting.content_localization_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
    allow(DiscourseAi::Translation).to receive(:enabled?).and_return(true)
  end

  it "requires login" do
    post "/ai-chat-translation/channels/#{channel.id}/messages/#{message.id}/translate.json"

    expect(response.status).to eq(403)
  end

  it "requires login to read a chat localization" do
    get "/ai-chat-translation/channels/#{channel.id}/messages/#{message.id}/localization.json"

    expect(response.status).to eq(403)
  end

  it "enqueues forced chat translation when permitted" do
    sign_in(admin)

    expect_enqueued_with(
      job: Jobs::DetectTranslateChatMessage,
      args: {
        chat_message_id: message.id,
        force: true,
      },
    ) { post "/ai-chat-translation/channels/#{channel.id}/messages/#{message.id}/translate.json" }

    expect(response.status).to eq(200)
  end

  it "does not let forced translation bypass the group direct-message allowlist" do
    direct_message_channel =
      Fabricate(
        :direct_message_channel,
        users: [admin, user, Fabricate(:user)],
      )
    direct_message =
      Fabricate(:chat_message, user:, chat_channel: direct_message_channel, message: "Hello world")
    SiteSetting.ai_translation_personal_messages = "all"
    sign_in(admin)

    post "/ai-chat-translation/channels/#{direct_message_channel.id}/messages/#{direct_message.id}/translate.json"

    expect(response.status).to eq(422)
  end

  it "returns bad request when AI translation is disabled" do
    sign_in(admin)
    allow(DiscourseAi::Translation).to receive(:enabled?).and_return(false)

    post "/ai-chat-translation/channels/#{channel.id}/messages/#{message.id}/translate.json"

    expect(response.status).to eq(400)
  end

  it "returns bad request when the translation integration is unavailable" do
    hide_const("AiChatTranslation::ChatMessageCandidates")
    sign_in(admin)

    post "/ai-chat-translation/channels/#{channel.id}/messages/#{message.id}/translate.json"

    expect(response.status).to eq(400)
  end

  it "lets a chat viewer read one current-locale localization without raw content" do
    source_hash = AiChatTranslation::ChatMessageLocalizer.source_hash(message)
    AiChatMessageLocalization.create!(
      chat_message: message,
      locale: "fr",
      raw: "Bonjour",
      cooked: "<p>Bonjour</p>",
      source_hash:,
    )
    user.update!(locale: "fr_CA")
    sign_in(user)

    get "/ai-chat-translation/channels/#{channel.id}/messages/#{message.id}/localization.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq(
      "source_hash" => source_hash,
      "localization" => {
        "locale" => "fr",
        "cooked" => "<p>Bonjour</p>",
        "source_hash" => source_hash,
      },
    )
  end

  it "does not apply the manual translation command rate limit to localization reads" do
    sign_in(admin)

    4.times do
      get "/ai-chat-translation/channels/#{channel.id}/messages/#{message.id}/localization.json"
      expect(response.status).to eq(200)
    end
  end
end
