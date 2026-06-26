import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AiChatTranslationDashboardRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/plugins/ai-chat-translation/dashboard.json");
  }
}
