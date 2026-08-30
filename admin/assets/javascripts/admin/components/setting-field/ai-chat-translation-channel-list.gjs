import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DMultiSelect from "discourse/ui-kit/d-multi-select";

const OPTIONS_KEY_BY_SETTING = {
  ai_chat_translation_allowed_channel_ids: "channel_options",
  ai_chat_translation_allowed_direct_message_channel_ids:
    "direct_message_channel_options",
};

export default class AiChatTranslationChannelList extends Component {
  @tracked options = [];
  #optionsRequest;

  constructor() {
    super(...arguments);
    this.fetchOptions().catch(() => {});
  }

  get optionsKey() {
    return OPTIONS_KEY_BY_SETTING[this.args.definition.key];
  }

  get selectedOptions() {
    const selectedIds = new Set(
      this.args.field.value.toString().split("|").filter(Boolean)
    );

    return this.options.filter((option) => selectedIds.has(String(option.id)));
  }

  async fetchOptions() {
    this.#optionsRequest ||= ajax(
      "/admin/plugins/ai-chat-translation/translation-scopes.json"
    )
      .then((response) => {
        this.options = response[this.optionsKey] || [];
        return this.options;
      })
      .catch((error) => {
        this.#optionsRequest = null;
        throw error;
      });

    return this.#optionsRequest;
  }

  @action
  async loadOptions(filter = "") {
    const options = await this.fetchOptions();
    const normalizedFilter = filter.toLowerCase();

    return options.filter((option) =>
      `${option.title} ${option.id}`.toLowerCase().includes(normalizedFilter)
    );
  }

  @action
  updateSelection(selection) {
    this.args.field.set(selection.map((option) => option.id).join("|"));
  }

  <template>
    <@field.Control>
      <DMultiSelect
        @loadFn={{this.loadOptions}}
        @selection={{this.selectedOptions}}
        @onChange={{this.updateSelection}}
        @label={{@definition.label}}
        class="ai-chat-translation-setting-multi-select"
      >
        <:selection as |option|>{{option.title}}</:selection>
        <:result as |option|>
          <span class="ai-chat-translation-setting-multi-select__title">
            {{option.title}}
          </span>
          <span class="ai-chat-translation-setting-multi-select__id">
            #{{option.id}}
          </span>
        </:result>
      </DMultiSelect>
    </@field.Control>
  </template>
}
