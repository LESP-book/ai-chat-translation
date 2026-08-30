import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { makeArray } from "discourse/lib/helpers";
import { splitString } from "discourse/lib/utilities";
import ListSetting from "discourse/select-kit/components/list-setting";

const OPTIONS_KEY_BY_SETTING = {
  ai_chat_translation_allowed_channel_ids: "channel_options",
  ai_chat_translation_allowed_direct_message_channel_ids:
    "direct_message_channel_options",
};

const TOKEN_SEPARATOR = "|";

export default class AiChatTranslationChannelList extends Component {
  @tracked rawOptions = [];
  #optionsRequest;

  constructor() {
    super(...arguments);
    this.fetchOptions().catch(() => {});
  }

  get optionsKey() {
    return OPTIONS_KEY_BY_SETTING[this.args.definition.key];
  }

  get selectedIds() {
    const value = this.args.field.value;
    return Array.isArray(value)
      ? value.map(String)
      : splitString(value, TOKEN_SEPARATOR);
  }

  get choices() {
    return this.rawOptions.map((option) => ({
      name: `${option.title} #${option.id}`,
      id: String(option.id),
    }));
  }

  async fetchOptions() {
    this.#optionsRequest ||= ajax(
      "/admin/plugins/ai-chat-translation/translation-scopes.json"
    )
      .then((response) => {
        this.rawOptions = response[this.optionsKey] || [];
        return this.rawOptions;
      })
      .catch((error) => {
        this.#optionsRequest = null;
        throw error;
      });

    return this.#optionsRequest;
  }

  @action
  onChange(values) {
    this.args.field.set(makeArray(values).join(TOKEN_SEPARATOR));
  }

  <template>
    <@field.Control>
      <ListSetting
        @value={{this.selectedIds}}
        @choices={{this.choices}}
        @settingName={{@definition.key}}
        @nameProperty="name"
        @valueProperty="id"
        @onChange={{this.onChange}}
        @options={{hash allowAny=false disabled=@field.disabled}}
      />
    </@field.Control>
  </template>
}
