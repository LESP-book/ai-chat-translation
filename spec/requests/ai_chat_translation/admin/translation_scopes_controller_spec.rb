# frozen_string_literal: true

describe AiChatTranslation::Admin::TranslationScopesController do
  fab!(:admin)
  fab!(:user)
  fab!(:category)
  fab!(:channel) { Fabricate(:category_channel, chatable: category) }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "returns public-channel and group-direct-message options separately" do
    named_group_dm =
      Fabricate(
        :direct_message_channel,
        users: [user, Fabricate(:user), Fabricate(:user)],
        name: "Translation group",
      )
    unnamed_group_dm =
      Fabricate(:direct_message_channel, users: [user, Fabricate(:user), Fabricate(:user)])
    Fabricate(:direct_message_channel, users: [user, Fabricate(:user)])

    get "/admin/plugins/ai-chat-translation/translation-scopes.json"

    expect(response.status).to eq(200)
    json = response.parsed_body
    expect(json.fetch("channel_options")).to include(
      include("id" => channel.id, "title" => channel.title(admin)),
    )
    expect(json.fetch("channel_options")).to all(
      satisfy { |option| option.keys == %w[id title] },
    )
    expect(json.fetch("direct_message_channel_options")).to contain_exactly(
      { "id" => named_group_dm.id, "title" => "Translation group" },
      {
        "id" => unnamed_group_dm.id,
        "title" => I18n.t("ai_chat_translation.admin.group_direct_messages.unnamed", id: unnamed_group_dm.id),
      },
    )
    expect(json.fetch("direct_message_channel_options")).to all(
      satisfy { |option| option.keys == %w[id title] },
    )
  end
end
