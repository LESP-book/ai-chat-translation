import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { automaticallyTranslate } from "discourse/lib/content-localization";
import { withPluginApi } from "discourse/lib/plugin-api";
import I18n, { i18n } from "discourse-i18n";
import AiChatTranslationLocalizationUpdateAdapter from "discourse/plugins/ai-chat-translation/discourse/lib/ai-chat-translation-localization-update-adapter";
import ChatChannelSubscriptionManager from "discourse/plugins/chat/discourse/lib/chat-channel-subscription-manager";
import ChatChannelThreadSubscriptionManager from "discourse/plugins/chat/discourse/lib/chat-channel-thread-subscription-manager";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

function normalizeLocale(locale) {
  return locale?.toString()?.replaceAll("-", "_");
}

function baseLocale(locale) {
  return normalizeLocale(locale)?.split("_")?.[0];
}

function initializeAiChatTranslation(api) {
  const siteSettings = api.container.lookup("service:site-settings");

  if (
    !siteSettings.chat_enabled ||
    !siteSettings.discourse_ai_enabled ||
    !siteSettings.ai_translation_enabled ||
    !siteSettings.ai_chat_translation_enabled
  ) {
    return;
  }

  const currentUser = api.getCurrentUser();
  if (ChatMessage.__aiChatTranslationPatched) {
    return;
  }
  ChatMessage.__aiChatTranslationPatched = true;

  function showOriginalByDefault() {
    return !automaticallyTranslate(currentUser);
  }

  function shouldFetchLocalization(message) {
    return (
      siteSettings.content_localization_enabled &&
      (automaticallyTranslate(currentUser) ||
        message.aiChatTranslationRequested)
    );
  }

  const originalCreate = ChatMessage.create;
  ChatMessage.create = function (channel, args = {}) {
    const message = originalCreate.call(this, channel, args);
    applyAiChatTranslationPayload(message, args);
    return message;
  };

  const cookedDescriptor = Object.getOwnPropertyDescriptor(
    ChatMessage.prototype,
    "cooked",
  );

  Object.defineProperties(ChatMessage.prototype, {
    aiChatCurrentLocalization: {
      get() {
        const currentLocale = normalizeLocale(I18n.locale);
        if (!currentLocale) {
          return null;
        }

        return localizationForCurrentLocale([this.aiChatLocalization]);
      },
    },

    aiChatHasTranslation: {
      get() {
        return !!this.aiChatCurrentLocalization;
      },
    },

    aiChatShowingTranslation: {
      get() {
        // 本地原文/译文切换依赖 incrementVersion() 触发 Glimmer 重新计算 cooked。
        this.version;

        if (!siteSettings.content_localization_enabled) {
          return false;
        }

        if (!this.aiChatCurrentLocalization) {
          return false;
        }

        if (this.aiChatTranslationMode === "original") {
          return false;
        }

        if (this.aiChatTranslationMode === "translation") {
          return true;
        }

        return !showOriginalByDefault();
      },
    },

    cooked: {
      get() {
        if (this.aiChatShowingTranslation) {
          return this.aiChatCurrentLocalization.cooked;
        }

        return cookedDescriptor.get.call(this);
      },
      set(newCooked) {
        cookedDescriptor.set.call(this, newCooked);
      },
    },
  });

  ChatMessage.prototype.toggleAiChatTranslation = function () {
    this.aiChatTranslationMode = this.aiChatShowingTranslation
      ? "original"
      : "translation";
    this.incrementVersion();
  };

  const secondaryActionsDescriptor = Object.getOwnPropertyDescriptor(
    ChatMessageInteractor.prototype,
    "secondaryActions",
  );

  Object.defineProperty(ChatMessageInteractor.prototype, "secondaryActions", {
    get() {
      const buttons = secondaryActionsDescriptor.get.call(this);

      if (!this.message?.canTranslateChatMessage) {
        return buttons;
      }

      buttons.push({
        id: "aiChatTranslate",
        name: this.message.aiChatHasTranslation
          ? i18n("ai_chat_translation.retranslate")
          : i18n("ai_chat_translation.translate"),
        icon: "language",
      });

      if (this.message.aiChatHasTranslation) {
        buttons.push({
          id: "aiChatToggleTranslation",
          name: this.message.aiChatShowingTranslation
            ? i18n("ai_chat_translation.show_original")
            : i18n("ai_chat_translation.show_translation"),
          icon: "arrows-rotate",
        });
      }

      return buttons;
    },
  });

  ChatMessageInteractor.prototype.aiChatToggleTranslation = function () {
    this.message.toggleAiChatTranslation();
  };

  ChatMessageInteractor.prototype.aiChatTranslate = function () {
    this.message.aiChatTranslationRequested = true;

    return ajax(
      `/ai-chat-translation/channels/${this.message.channel.id}/messages/${this.message.id}/translate.json`,
      {
        type: "POST",
      },
    )
      .then(() => {
        this.toasts.success({
          duration: "short",
          data: { message: i18n("ai_chat_translation.scheduled") },
        });
      })
      .catch((error) => {
        this.message.aiChatTranslationRequested = false;
        popupAjaxError(error);
      });
  };

  AiChatTranslationLocalizationUpdateAdapter.install(
    ChatChannelSubscriptionManager,
    shouldFetchLocalization,
  );
  AiChatTranslationLocalizationUpdateAdapter.install(
    ChatChannelThreadSubscriptionManager,
    shouldFetchLocalization,
  );
  patchSubscriptionManager(ChatChannelSubscriptionManager);
  patchSubscriptionManager(ChatChannelThreadSubscriptionManager);
}

export default {
  name: "ai-chat-translation",
  after: "chat-setup",

  initialize() {
    withPluginApi(initializeAiChatTranslation);
  },
};

function localizationForCurrentLocale(localizations) {
  const currentLocale = normalizeLocale(I18n.locale);
  if (!currentLocale) {
    return null;
  }

  return (
    localizations.find(
      (localization) => normalizeLocale(localization?.locale) === currentLocale,
    ) ||
    localizations.find(
      (localization) =>
        baseLocale(localization?.locale) === baseLocale(currentLocale),
    ) ||
    null
  );
}

function applyAiChatTranslationPayload(message, args) {
  message.locale = args.locale;
  message.aiChatLocalization = localizationForCurrentLocale(
    args.aiChatLocalizations ?? args.ai_chat_localizations ?? [],
  );
  message.aiChatTranslationOutdated =
    args.aiChatTranslationOutdated ??
    args.ai_chat_translation_outdated ??
    false;
  message.canTranslateChatMessage =
    args.canTranslateChatMessage ?? args.can_translate_chat_message ?? false;
  message.aiChatTranslationMode = null;
}

function patchSubscriptionManager(ManagerClass) {
  const originalRefresh = ManagerClass.prototype.handleRefreshMessage;
  ManagerClass.prototype.handleRefreshMessage = function (data) {
    originalRefresh.call(this, data);

    const message = this.messagesManager.findMessage(data.chat_message.id);
    if (message) {
      applyAiChatTranslationPayload(message, data.chat_message);
      message.incrementVersion();
    }
  };

  const originalEdit = ManagerClass.prototype.handleEditMessage;
  ManagerClass.prototype.handleEditMessage = function (data) {
    originalEdit.call(this, data);

    const message = this.messagesManager.findMessage(data.chat_message.id);
    if (message) {
      applyAiChatTranslationPayload(message, data.chat_message);
      message.incrementVersion();
    }
  };
}
