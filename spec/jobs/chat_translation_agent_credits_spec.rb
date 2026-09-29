# frozen_string_literal: true

describe "Chat translation credit gates" do
  before do
    enable_current_plugin
    agent = Fabricate(:ai_agent, enabled: true)
    SiteSetting.ai_chat_translation_translator_agent = agent.id.to_s
    @agent_id = agent.id.to_s
    allow(AiChatTranslation).to receive(:enabled?).and_return(true)
    allow(AiChatTranslation).to receive(:backfill_enabled?).and_return(true)
    allow(DiscourseAi::Translation).to receive(:credits_available_for_agent_ids?).and_return(false)
  end

  it "checks only the Chat agent for queued localization" do
    Jobs::LocalizeChatMessages.new.execute(pairs: [[123, "fr"]])

    expect(DiscourseAi::Translation).to have_received(:credits_available_for_agent_ids?).with(
      [@agent_id],
    )
  end

  it "checks only the Chat agent for localization backfill" do
    allow(Discourse.redis).to receive(:get).with(Jobs::ChatMessageLocalizationBackfill::REDIS_KEY).and_return(nil)
    Jobs::ChatMessageLocalizationBackfill.new.execute({})

    expect(DiscourseAi::Translation).to have_received(:credits_available_for_agent_ids?).with(
      [@agent_id],
    )
  end

  it "checks both detection and Chat agents for detection backfill" do
    Jobs::ChatMessagesLocaleDetectionBackfill.new.execute({})

    expect(DiscourseAi::Translation).to have_received(:credits_available_for_agent_ids?).with(
      [SiteSetting.ai_translation_locale_detector_agent, @agent_id],
    )
  end
end
