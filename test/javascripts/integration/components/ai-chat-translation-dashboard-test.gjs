import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AiChatTranslationDashboard from "discourse/plugins/ai-chat-translation/admin/components/ai-chat-translation-dashboard";

const PROGRESS_URL =
  "/admin/plugins/ai-chat-translation/dashboard/progress.json";

module(
  "Integration | Component | AI chat translation dashboard",
  function (hooks) {
    setupRenderingTest(hooks);

    test("does not mark undetected messages as fully translated", async function (assert) {
      pretender.get(PROGRESS_URL, () =>
        response({
          translation_progress: [{ locale: "fr", done: 0, total: 0 }],
          total: 2,
          messages_with_detected_locale: 0,
        }),
      );

      await render(
        <template>
          <AiChatTranslationDashboard />
        </template>,
      );

      assert
        .dom(
          ".ai-chat-translation-dashboard__stat-card:nth-child(4) .ai-chat-translation-dashboard__stat-value",
        )
        .hasText("0%");
      assert
        .dom(
          ".ai-chat-translation-dashboard__stat-card:nth-child(3) .ai-chat-translation-dashboard__badge.--success",
        )
        .doesNotExist();
    });

    test("does not report complete while locale detection is still pending", async function (assert) {
      pretender.get(PROGRESS_URL, () =>
        response({
          translation_progress: [{ locale: "fr", done: 1, total: 1 }],
          total: 2,
          messages_with_detected_locale: 1,
        }),
      );

      await render(
        <template>
          <AiChatTranslationDashboard />
        </template>,
      );

      assert
        .dom(
          ".ai-chat-translation-dashboard__stat-card:nth-child(4) .ai-chat-translation-dashboard__stat-value",
        )
        .hasText("99%");
      assert
        .dom(
          ".ai-chat-translation-dashboard__stat-card:nth-child(3) .ai-chat-translation-dashboard__badge.--success",
        )
        .doesNotExist();
    });

    test("reports complete when all detected translation work is done", async function (assert) {
      pretender.get(PROGRESS_URL, () =>
        response({
          translation_progress: [{ locale: "fr", done: 1, total: 1 }],
          total: 1,
          messages_with_detected_locale: 1,
        }),
      );

      await render(
        <template>
          <AiChatTranslationDashboard />
        </template>,
      );

      assert
        .dom(
          ".ai-chat-translation-dashboard__stat-card:nth-child(4) .ai-chat-translation-dashboard__stat-value",
        )
        .hasText("100%");
      assert
        .dom(
          ".ai-chat-translation-dashboard__stat-card:nth-child(3) .ai-chat-translation-dashboard__badge.--success",
        )
        .exists();
    });
  },
);
