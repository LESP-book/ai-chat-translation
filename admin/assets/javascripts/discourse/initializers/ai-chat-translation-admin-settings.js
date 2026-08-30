import AiChatTranslationChannelList from "discourse/plugins/ai-chat-translation/admin/components/setting-field/ai-chat-translation-channel-list";
import { registerSettingFieldType } from "discourse/lib/setting-field-registry";

const SETTING_FIELD = {
  adminReady: true,
  format: "large",
  labelFormat: "full",
  type: "custom",
  renderer: AiChatTranslationChannelList,
};

export default {
  name: "ai-chat-translation-admin-settings",

  initialize() {
    registerSettingFieldType("ai_chat_translation_channel_list", SETTING_FIELD);
    registerSettingFieldType(
      "ai_chat_translation_direct_message_channel_list",
      SETTING_FIELD
    );
  },
};
