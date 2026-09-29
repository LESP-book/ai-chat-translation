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
    SiteSetting.ai_chat_translation_backfill_hourly_rate = 60
    SiteSetting.ai_chat_translation_backfill_max_age_days = 30
    SiteSetting.ai_chat_translation_allowed_channel_ids = ""
    SiteSetting.ai_chat_translation_allowed_direct_message_channel_ids = ""
    SiteSetting.ai_translation_category_scope = "public"
    SiteSetting.ai_translation_categories = ""
    SiteSetting.ai_translation_personal_messages = "none"
    SiteSetting.discourse_ai_enabled = true
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = "fr|en"
    allow(AiChatTranslation::TranslationConfiguration).to receive(:ready?).and_return(true)
  end

  it "accepts normal category channel messages" do
    expect(described_class.eligible_message?(message)).to eq(true)
  end

  it "rejects category channels excluded by the current AI category scope" do
    SiteSetting.ai_translation_category_scope = "exclude_strict"
    SiteSetting.ai_translation_categories = category.id.to_s

    expect(described_class.eligible_message?(message)).to eq(false)
  end

  it "rejects category channels outside the chat channel allowlist" do
    other_channel = Fabricate(:category_channel, chatable: Fabricate(:category))
    SiteSetting.ai_chat_translation_allowed_channel_ids = other_channel.id.to_s

    expect(described_class.eligible_message?(message)).to eq(false)
  end

  it "does not impose the removed AI source-length cap" do
    long_message =
      Fabricate(:chat_message, user:, chat_channel: channel, message: "a" * 101)

    expect(described_class.eligible_message?(long_message)).to eq(true)
  end

  it "does not let forced manual translation bypass bot content policy" do
    system_message =
      Fabricate(:chat_message, user: Discourse.system_user, chat_channel: channel, message: "Hello")
    SiteSetting.ai_translation_include_bot_content = false

    expect(described_class.eligible_message?(system_message, force: true)).to eq(false)
  end

  it "allows whitelisted group direct messages without using the global personal-message setting" do
    dm = Fabricate(:direct_message_channel, users: [user, Fabricate(:user), Fabricate(:user)])
    dm_message = Fabricate(:chat_message, user:, chat_channel: dm)
    SiteSetting.ai_chat_translation_allowed_direct_message_channel_ids = dm.id.to_s
    SiteSetting.ai_translation_personal_messages = "none"

    expect(described_class.eligible_message?(dm_message)).to eq(true)
  end

  it "rejects non-group direct messages even when their ID is whitelisted" do
    dm = Fabricate(:direct_message_channel, users: [user, Fabricate(:user)])
    dm_message = Fabricate(:chat_message, user:, chat_channel: dm)
    SiteSetting.ai_chat_translation_allowed_direct_message_channel_ids = dm.id.to_s
    SiteSetting.ai_translation_personal_messages = "all"

    expect(described_class.eligible_message?(dm_message)).to eq(false)
  end

  it "rejects group direct messages missing from the plugin allowlist" do
    SiteSetting.ai_translation_personal_messages = "all"
    dm = Fabricate(:direct_message_channel, users: [user, Fabricate(:user), Fabricate(:user)])
    dm_message = Fabricate(:chat_message, user:, chat_channel: dm)

    expect(described_class.eligible_message?(dm_message)).to eq(false)
  end

  it "uses the chat backfill max age when finding messages needing locale detection" do
    SiteSetting.ai_chat_translation_backfill_max_age_days = 5
    old_message =
      Fabricate(:chat_message, user:, chat_channel: channel, message: "Old", created_at: 10.days.ago)

    expect(described_class.needs_locale_detection(limit: 10)).to include(message)
    expect(described_class.needs_locale_detection(limit: 10)).not_to include(old_message)
  end

  it "uses the current AI category scope for chat backfill" do
    SiteSetting.ai_translation_category_scope = "exclude_strict"
    SiteSetting.ai_translation_categories = category.id.to_s

    expect(described_class.needs_locale_detection(limit: 10)).not_to include(message)
  end

  it "uses the direct-message allowlist for backfill without including direct messages outside it" do
    SiteSetting.ai_translation_personal_messages = "all"
    SiteSetting.ai_chat_translation_allowed_channel_ids = Fabricate(:category_channel).id.to_s
    allowed_dm = Fabricate(:direct_message_channel, users: [user, Fabricate(:user), Fabricate(:user)])
    unallowed_dm = Fabricate(:direct_message_channel, users: [user, Fabricate(:user), Fabricate(:user)])
    personal_dm = Fabricate(:direct_message_channel, users: [user, Fabricate(:user)])
    allowed_message = Fabricate(:chat_message, user:, chat_channel: allowed_dm, message: "Allowed")
    unallowed_message = Fabricate(:chat_message, user:, chat_channel: unallowed_dm, message: "Unallowed")
    personal_message = Fabricate(:chat_message, user:, chat_channel: personal_dm, message: "Personal")
    SiteSetting.ai_chat_translation_allowed_direct_message_channel_ids = allowed_dm.id.to_s

    candidates = described_class.needs_locale_detection(limit: 10)

    expect(candidates).not_to include(message)
    expect(candidates).to include(allowed_message)
    expect(candidates).not_to include(unallowed_message, personal_message)
  end

  it "changes the progress cache key when the direct-message allowlist changes" do
    original_key = described_class.progress_cache_key
    SiteSetting.ai_chat_translation_allowed_direct_message_channel_ids = "1|2"

    expect(described_class.progress_cache_key).not_to eq(original_key)
  end

  it "reports completion for all supported locales" do
    SiteSetting.content_localization_supported_locales = "fr|en"
    allow(DiscourseAi::Translation).to receive(:locales).and_return(%w[fr en])
    message.update!(locale: "en")

    AiChatMessageLocalization.create!(
      chat_message: message,
      locale: "fr",
      raw: "Bonjour le monde",
      cooked: "<p>Bonjour le monde</p>",
      source_hash: AiChatTranslation::ChatMessageLocalizer.source_hash(message),
      localizer_user_id: Discourse.system_user.id,
    )

    result = described_class.completion_all_locales

    expect(result[:total]).to eq(1)
    expect(result[:messages_with_detected_locale]).to eq(1)
    expect(result[:translation_progress]).to contain_exactly(
      { locale: "fr", done: 1, total: 1 },
      { locale: "en", done: 0, total: 0 },
    )
  end
end
