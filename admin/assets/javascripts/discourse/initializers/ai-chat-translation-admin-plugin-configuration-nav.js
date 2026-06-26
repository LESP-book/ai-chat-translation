import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "ai-chat-translation";

export default {
  name: "ai-chat-translation-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "language");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "ai_chat_translation.admin.nav.dashboard",
          route: "adminPlugins.show.ai-chat-translation-dashboard",
          description: "ai_chat_translation.admin.nav.dashboard_description",
        },
      ]);
    });
  },
};
