# frozen_string_literal: true

describe AiChatTranslation::LocalizationUpdatePublisher do
  fab!(:user)
  fab!(:channel, :category_channel)
  fab!(:message) { Fabricate(:chat_message, user:, chat_channel: channel, message: "Hello world") }

  it "publishes a compact update through Chat's existing targets and permissions" do
    targets = ["/chat/#{channel.id}"]
    allow(Chat::Publisher).to receive(:calculate_publish_targets).and_return(targets)
    allow(Chat::Publisher).to receive(:publish_to_targets!)

    described_class.publish!(message)

    expect(Chat::Publisher).to have_received(:calculate_publish_targets).with(channel, message)
    expect(Chat::Publisher).to have_received(:publish_to_targets!).with(
      targets,
      channel,
      {
        type: "ai_chat_localization_updated",
        chat_message_id: message.id,
        source_hash: AiChatTranslation::ChatMessageLocalizer.source_hash(message),
      },
    )
  end
end
