import { ajax } from "discourse/lib/ajax";

const EVENT_TYPE = "ai_chat_localization_updated";
const installedManagers = new WeakSet();
const pendingLocalizations = new Map();

export default class AiChatTranslationLocalizationUpdateAdapter {
  static install(ManagerClass, shouldFetch = () => true) {
    if (installedManagers.has(ManagerClass)) {
      return;
    }

    installedManagers.add(ManagerClass);
    const originalDescriptor = Object.getOwnPropertyDescriptor(
      ManagerClass.prototype,
      "onMessage",
    );

    Object.defineProperty(ManagerClass.prototype, "onMessage", {
      configurable: true,
      get() {
        const originalOnMessage = originalDescriptor.get
          ? originalDescriptor.get.call(this)
          : originalDescriptor.value.bind(this);
        const onMessage = (...args) => {
          const [data] = args;
          const result = originalOnMessage(...args);

          if (data.type === EVENT_TYPE) {
            AiChatTranslationLocalizationUpdateAdapter.handle(
              this,
              data,
              shouldFetch,
            );
          }

          return result;
        };

        Object.defineProperty(this, "onMessage", {
          configurable: true,
          value: onMessage,
        });
        return onMessage;
      },
    });
  }

  static handle(manager, data, shouldFetch = () => true) {
    const message = manager.messagesManager.findMessage(data.chat_message_id);
    if (!message || !shouldFetch(message)) {
      return;
    }

    this.fetch(message, data.source_hash).then((payload) => {
      if (payload.source_hash !== data.source_hash) {
        return;
      }

      const currentMessage = manager.messagesManager.findMessage(
        data.chat_message_id,
      );
      if (!currentMessage) {
        return;
      }

      currentMessage.aiChatLocalization = payload.localization;
      currentMessage.aiChatTranslationOutdated = false;
      currentMessage.aiChatTranslationRequested = false;
      currentMessage.incrementVersion();
    });
  }

  static fetch(message, sourceHash) {
    const key = `${message.id}:${sourceHash}`;
    let request = pendingLocalizations.get(key);

    if (!request) {
      request = ajax(
        `/ai-chat-translation/channels/${message.channel.id}/messages/${message.id}/localization.json`,
      ).finally(() => pendingLocalizations.delete(key));
      pendingLocalizations.set(key, request);
    }

    return request.catch(() => ({}));
  }
}
