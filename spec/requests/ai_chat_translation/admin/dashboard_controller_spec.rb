# frozen_string_literal: true

describe AiChatTranslation::Admin::DashboardController do
  fab!(:admin)

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "returns empty progress when chat backfill is disabled" do
    get "/admin/plugins/ai-chat-translation/dashboard/progress.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq(
      "translation_progress" => [],
      "total" => 0,
      "messages_with_detected_locale" => 0,
    )
  end
end
