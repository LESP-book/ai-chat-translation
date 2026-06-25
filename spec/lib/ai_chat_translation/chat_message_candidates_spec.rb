# frozen_string_literal: true

describe AiChatTranslation::ChatMessageCandidates do
  fab!(:user)
  fab!(:category)
  fab!(:channel) { Fabricate(:category_channel, chatable: category) }
  fab!(:message) { Fabricate(:chat_message, user:, chat_channel: channel, message: "Hello world") }

  before do
    enable_current_plugin
    SiteSetting.chat_enabled = true
    SiteSetting.ai_chat_translation_enabled = true
    SiteSetting.ai_translation_max_post_length = 100
    SiteSetting.ai_translation_personal_messages = "none"
    SiteSetting.ai_translation_excluded_categories = ""
    allow(DiscourseAi::Translation).to receive(:enabled?).and_return(true)
  end

  it "accepts normal category channel messages" do
    expect(described_class.eligible_message?(message)).to eq(true)
  end

  it "rejects excluded category channels" do
    SiteSetting.ai_translation_excluded_categories = category.id.to_s

    expect(described_class.eligible_message?(message)).to eq(false)
  end

  it "rejects messages over the reused AI translation max length" do
    SiteSetting.ai_translation_max_post_length = 5

    expect(described_class.eligible_message?(message)).to eq(false)
  end

  it "does not let forced manual translation bypass bot content policy" do
    system_message =
      Fabricate(:chat_message, user: Discourse.system_user, chat_channel: channel, message: "Hello")
    SiteSetting.ai_translation_include_bot_content = false

    expect(described_class.eligible_message?(system_message, force: true)).to eq(false)
  end

  it "uses existing PM policy for group direct messages" do
    SiteSetting.ai_translation_personal_messages = "group"
    dm = Fabricate(:direct_message_channel, users: [user, Fabricate(:user), Fabricate(:user)])
    dm_message = Fabricate(:chat_message, user:, chat_channel: dm)

    expect(described_class.eligible_message?(dm_message)).to eq(true)
  end

  it "uses existing PM policy to reject non-group direct messages" do
    SiteSetting.ai_translation_personal_messages = "group"
    dm = Fabricate(:direct_message_channel, users: [user, Fabricate(:user)])
    dm_message = Fabricate(:chat_message, user:, chat_channel: dm)

    expect(described_class.eligible_message?(dm_message)).to eq(false)
  end
end
