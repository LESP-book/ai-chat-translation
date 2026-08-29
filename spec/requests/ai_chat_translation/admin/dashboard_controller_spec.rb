# frozen_string_literal: true

describe AiChatTranslation::Admin::DashboardController do
  fab!(:admin)
  fab!(:user)
  fab!(:category)
  fab!(:channel) { Fabricate(:category_channel, chatable: category) }
  fab!(:message) { Fabricate(:chat_message, user:, chat_channel: channel, message: "Hello world") }

  before do
    enable_current_plugin
    sign_in(admin)
    SiteSetting.chat_enabled = true
    SiteSetting.ai_chat_translation_enabled = true
    SiteSetting.ai_chat_translation_backfill_hourly_rate = 60
    SiteSetting.ai_chat_translation_backfill_max_age_days = 30
    SiteSetting.ai_chat_translation_allowed_channel_ids = channel.id.to_s
    SiteSetting.ai_translation_category_scope = "public"
    SiteSetting.ai_translation_categories = ""
    SiteSetting.ai_translation_personal_messages = "none"
    SiteSetting.content_localization_supported_locales = "fr|en"
    allow(DiscourseAi::Translation).to receive(:enabled?).and_return(true)
    allow(DiscourseAi::Translation).to receive(:locales).and_return(%w[fr en])
  end

  it "returns dashboard configuration and channel options" do
    get "/admin/plugins/ai-chat-translation/dashboard.json"

    expect(response.status).to eq(200)
    json = response.parsed_body

    expect(json["enabled"]).to eq(true)
    expect(json["backfill_enabled"]).to eq(true)
    expect(json["hourly_rate"]).to eq(60)
    expect(json["backfill_max_age_days"]).to eq(30)
    expect(json["allowed_channel_ids"]).to contain_exactly(channel.id)
    expect(json["channel_options"]).to include(
      include("id" => channel.id, "title" => channel.title(admin)),
    )
  end

  it "returns empty progress when chat backfill is disabled" do
    SiteSetting.ai_chat_translation_backfill_hourly_rate = 0

    get "/admin/plugins/ai-chat-translation/dashboard/progress.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq(
      "translation_progress" => [],
      "total" => 0,
      "messages_with_detected_locale" => 0,
    )
  end

  it "returns chat translation progress" do
    message.update!(locale: "en")

    get "/admin/plugins/ai-chat-translation/dashboard/progress.json"

    expect(response.status).to eq(200)
    json = response.parsed_body

    expect(json["total"]).to eq(1)
    expect(json["messages_with_detected_locale"]).to eq(1)
    expect(json["translation_progress"]).to include(
      include("locale" => "fr", "done" => 0, "total" => 1),
    )
  end
end
