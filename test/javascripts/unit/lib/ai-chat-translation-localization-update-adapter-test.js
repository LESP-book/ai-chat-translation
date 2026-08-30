import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";
import AiChatTranslationLocalizationUpdateAdapter from "discourse/plugins/ai-chat-translation/discourse/lib/ai-chat-translation-localization-update-adapter";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

class TestSubscriptionManager {
  constructor(messagesManager) {
    this.messagesManager = messagesManager;
  }

  onMessage(_data, _globalId, lastMessageBusId) {
    this.lastMessageBusId = lastMessageBusId;
  }
}

class DisabledTestSubscriptionManager {
  constructor(messagesManager) {
    this.messagesManager = messagesManager;
  }

  onMessage(_data, _globalId, lastMessageBusId) {
    this.lastMessageBusId = lastMessageBusId;
  }
}

module(
  "Unit | AI chat translation | localization update adapter",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.fabricators = new ChatFabricators(getOwner(this));
    });

    test("loads one localization only for a message already managed by the channel", async function (assert) {
      AiChatTranslationLocalizationUpdateAdapter.install(
        TestSubscriptionManager,
        () => true,
      );

      const channel = this.fabricators.channel({ id: 1 });
      const message = this.fabricators.message({ id: 10, channel });
      channel.messagesManager.addMessages([message]);
      const manager = new TestSubscriptionManager(channel.messagesManager);

      pretender.get(
        "/ai-chat-translation/channels/1/messages/10/localization.json",
        () => [
          200,
          { "Content-Type": "application/json" },
          JSON.stringify({
            source_hash: "current",
            localization: {
              locale: "fr",
              cooked: "<p>Bonjour</p>",
              source_hash: "current",
            },
          }),
        ],
      );

      manager.onMessage(
        {
          type: "ai_chat_localization_updated",
          chat_message_id: message.id,
          source_hash: "current",
        },
        null,
        1,
      );
      await settled();

      assert.strictEqual(manager.lastMessageBusId, 1);
      assert.deepEqual(message.aiChatLocalization, {
        locale: "fr",
        cooked: "<p>Bonjour</p>",
        source_hash: "current",
      });
    });

    test("skips the fetch when the viewer is not automatically translating", async function (assert) {
      AiChatTranslationLocalizationUpdateAdapter.install(
        DisabledTestSubscriptionManager,
        () => false,
      );

      const channel = this.fabricators.channel({ id: 2 });
      const message = this.fabricators.message({ id: 20, channel });
      channel.messagesManager.addMessages([message]);
      const manager = new DisabledTestSubscriptionManager(
        channel.messagesManager,
      );
      let requests = 0;
      pretender.get(
        "/ai-chat-translation/channels/2/messages/20/localization.json",
        () => {
          requests++;
          return [200, { "Content-Type": "application/json" }, "{}"];
        },
      );

      manager.onMessage(
        {
          type: "ai_chat_localization_updated",
          chat_message_id: message.id,
          source_hash: "current",
        },
        null,
        1,
      );
      await settled();

      assert.strictEqual(manager.lastMessageBusId, 1);
      assert.strictEqual(requests, 0);
      assert.strictEqual(message.aiChatLocalization, undefined);
    });
  },
);
