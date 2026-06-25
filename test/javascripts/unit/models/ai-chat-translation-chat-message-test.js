import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";
import aiChatTranslationInitializer from "discourse/plugins/ai-chat-translation/discourse/initializers/ai-chat-translation";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

module("Unit | AI chat translation | chat-message", function (hooks) {
  setupTest(hooks);

  test("selects exact/base locale translations and exposes message actions", function (assert) {
    logIn(getOwner(this));

    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.chat_enabled = true;
    siteSettings.discourse_ai_enabled = true;
    siteSettings.ai_translation_enabled = true;
    siteSettings.ai_chat_translation_enabled = true;
    siteSettings.content_localization_enabled = true;

    aiChatTranslationInitializer.initialize(getOwner(this));

    const oldLocale = I18n.locale;
    I18n.locale = "fr_CA";

    const channel = new ChatFabricators(getOwner(this)).channel({ id: 1 });
    const message = ChatMessage.create(channel, {
      id: 10,
      cooked: "<p>Hello</p>",
      ai_chat_localizations: [
        { locale: "fr", cooked: "<p>Bonjour</p>", source_hash: "hash" },
      ],
      can_translate_chat_message: true,
    });

    assert.strictEqual(message.cooked, "<p>Bonjour</p>");

    message.toggleAiChatTranslation();
    assert.strictEqual(message.cooked, "<p>Hello</p>");

    const interactor = new ChatMessageInteractor(getOwner(this), message);
    assert.true(
      interactor.secondaryActions.some((action) => action.id === "aiChatTranslate")
    );
    assert.true(
      interactor.secondaryActions.some(
        (action) => action.id === "aiChatToggleTranslation"
      )
    );

    I18n.locale = oldLocale;
  });
});
