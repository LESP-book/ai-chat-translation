# ai-chat-translation

Translate eligible Discourse Chat messages using Discourse AI. Forum posts keep their own translation configuration.

## Configure a dedicated Chat translation agent

1. Enable Chat, Discourse AI, official AI translation, and this plugin; configure the supported target locales and the existing Chat channel / group direct-message scope settings.
2. In the Discourse AI admin, create and enable an agent for fast Chat translation. Explicitly select the fast, low-cost LLM in the agent's model setting. Without an explicit model, Discourse AI resolves the default model (or the last available model) instead.
3. The translator receives a **JSON string** containing `content` (the message text) and `target_locale` (the requested locale). Instruct the agent to translate `content` into `target_locale`, preserve Chat formatting and links, and return **only the translation**. If configuring structured output, expose the translated text in the `output` field, as expected by Discourse AI's `BaseTranslator`.
4. In the Chat translation plugin settings, choose the agent under **Chat message translation agent** (`ai_chat_translation_translator_agent`). The default, **Follow official post translation agent**, uses `ai_translation_post_raw_translator_agent`. Detection still uses `ai_translation_locale_detector_agent`.

An explicitly selected agent that is deleted or has no resolvable model stops Chat translation; it does not fall back to the forum post agent or another model. Discourse AI's agent `enabled` switch controls AI Bot availability, not the official translation execution path, so a translation-only agent need not be enabled as a conversational bot. If its model has no credits, Chat translation pauses until credits are restored. The same selection applies to live messages, edits, manual translation, and backfill. It does not change the official post setting or existing translations: switching agents does **not** delete, retranslate, or rehash historical messages. Future translation runs use the current selection.
