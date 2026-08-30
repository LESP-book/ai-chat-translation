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

  test("selects exact/base locale translations and respects current translation preferences", function (assert) {
    const owner = getOwner(this);
    logIn(owner);

    const currentUser = owner.lookup("service:current-user");
    currentUser.user_option.automatically_translate = true;
    currentUser.user_option.show_original_content = true;

    const siteSettings = owner.lookup("service:site-settings");
    siteSettings.chat_enabled = true;
    siteSettings.discourse_ai_enabled = true;
    siteSettings.ai_translation_enabled = true;
    siteSettings.ai_chat_translation_enabled = true;
    siteSettings.content_localization_enabled = true;

    aiChatTranslationInitializer.initialize(owner);

    const oldLocale = I18n.locale;
    I18n.locale = "fr_CA";

    const channel = new ChatFabricators(owner).channel({ id: 1 });
    const message = ChatMessage.create(channel, {
      id: 10,
      cooked: "<p>Hello</p>",
      ai_chat_localizations: [
        { locale: "fr", cooked: "<p>Bonjour</p>", source_hash: "hash" },
      ],
      can_translate_chat_message: true,
    });

    assert.deepEqual(message.aiChatLocalization, {
      locale: "fr",
      cooked: "<p>Bonjour</p>",
      source_hash: "hash",
    });
    assert.strictEqual(message.aiChatLocalizations, undefined);
    assert.strictEqual(message.cooked, "<p>Bonjour</p>");

    message.toggleAiChatTranslation();
    assert.strictEqual(message.cooked, "<p>Hello</p>");

    const interactor = new ChatMessageInteractor(owner, message);
    assert.true(
      interactor.secondaryActions.some(
        (action) => action.id === "aiChatTranslate",
      ),
    );
    assert.true(
      interactor.secondaryActions.some(
        (action) => action.id === "aiChatToggleTranslation",
      ),
    );

    I18n.locale = oldLocale;
  });
});
