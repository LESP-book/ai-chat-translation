import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AiChatTranslationChannelList from "discourse/plugins/ai-chat-translation/admin/components/setting-field/ai-chat-translation-channel-list";

module("Integration | Component | AI chat translation channel list", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get(
      "/admin/plugins/ai-chat-translation/translation-scopes.json",
      () =>
        response(200, {
          channel_options: [
            { id: 1, title: "General" },
            { id: 2, title: "Support" },
          ],
          direct_message_channel_options: [
            { id: 3, title: "Translation team" },
          ],
        })
    );
  });

  test("shows public channel options", async function (assert) {
    await render(
      <template>
        <Form @data={{hash ai_chat_translation_allowed_channel_ids=""}} as |form|>
          <form.Field @name="ai_chat_translation_allowed_channel_ids" as |field|>
            <AiChatTranslationChannelList
              @field={{field}}
              @definition={{hash key="ai_chat_translation_allowed_channel_ids"}}
            />
          </form.Field>
        </Form>
      </template>
    );

    const selector = selectKit(".list-setting");
    await selector.expand();

    assert.strictEqual(selector.rows().length, 2);
    assert.strictEqual(selector.rowByValue("1").name(), "General #1");
    assert.strictEqual(selector.rowByValue("2").name(), "Support #2");
  });

  test("shows only group direct-message options", async function (assert) {
    await render(
      <template>
        <Form
          @data={{hash ai_chat_translation_allowed_direct_message_channel_ids=""}}
          as |form|
        >
          <form.Field
            @name="ai_chat_translation_allowed_direct_message_channel_ids"
            as |field|
          >
            <AiChatTranslationChannelList
              @field={{field}}
              @definition={{hash
                key="ai_chat_translation_allowed_direct_message_channel_ids"
              }}
            />
          </form.Field>
        </Form>
      </template>
    );

    const selector = selectKit(".list-setting");
    await selector.expand();

    assert.strictEqual(selector.rows().length, 1);
    assert.strictEqual(selector.rowByValue("3").name(), "Translation team #3");
  });
});
