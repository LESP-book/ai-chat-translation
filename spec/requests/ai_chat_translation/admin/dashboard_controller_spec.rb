# frozen_string_literal: true

describe AiChatTranslation::Admin::DashboardController do
  fab!(:admin)

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "serves the dashboard page when its URL is loaded directly" do
    get "/admin/plugins/ai-chat-translation/dashboard"

    expect(response.status).to eq(200)
  end

  it "returns empty progress when chat backfill is disabled" do
    get "/admin/plugins/ai-chat-translation/dashboard/progress.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq(empty_progress)
  end

  it "returns empty progress when the translation integration is unavailable" do
    hide_const("AiChatTranslation::ChatMessageCandidates")

    get "/admin/plugins/ai-chat-translation/dashboard/progress.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq(empty_progress)
  end

  def empty_progress
    {
      "translation_progress" => [],
      "total" => 0,
      "messages_with_detected_locale" => 0,
      "completed" => 0,
      "pending" => 0,
      "percentage" => 0,
    }
  end
end
