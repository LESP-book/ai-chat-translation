import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

export default class AiChatTranslationDashboard extends Component {
  @service languageNameLookup;

  @tracked data = [];
  @tracked total = 0;
  @tracked messagesWithDetectedLocale = 0;
  @tracked loadingProgress = false;
  @tracked isSavingBackfill = false;
  @tracked isSavingChannels = false;
  @tracked hourlyRate = String(this.args.model?.hourly_rate ?? 0);
  @tracked originalHourlyRate = String(this.args.model?.hourly_rate ?? 0);
  @tracked backfillMaxAgeDays = String(
    this.args.model?.backfill_max_age_days ?? 0
  );
  @tracked originalBackfillMaxAgeDays = String(
    this.args.model?.backfill_max_age_days ?? 0
  );
  @tracked selectedChannelIds = (this.args.model?.allowed_channel_ids || []).map(
    String
  );
  @tracked originalSelectedChannelIds = (
    this.args.model?.allowed_channel_ids || []
  ).map(String);

  constructor() {
    super(...arguments);
    this.loadProgress();
  }

  get formatter() {
    return new Intl.NumberFormat();
  }

  get pendingTranslations() {
    return this.data.reduce((sum, row) => sum + row.total - row.done, 0);
  }

  get stats() {
    return [
      {
        label: i18n("ai_chat_translation.admin.stats.total"),
        value: this.formatter.format(this.total),
      },
      {
        label: i18n("ai_chat_translation.admin.stats.detected"),
        value: this.formatter.format(this.messagesWithDetectedLocale),
      },
      {
        label: i18n("ai_chat_translation.admin.stats.pending"),
        value: this.formatter.format(this.pendingTranslations),
      },
    ];
  }

  get progressRows() {
    return this.data.map((row) => {
      const percentage =
        row.total > 0 ? Math.trunc((row.done / row.total) * 100) : 100;

      return {
        ...row,
        language: this.languageNameLookup.getLanguageName(row.locale),
        percentage,
        style: `width: ${percentage}%`,
        doneLabel: this.formatter.format(row.done),
        totalLabel: this.formatter.format(row.total),
        pendingLabel: this.formatter.format(row.total - row.done),
      };
    });
  }

  get channelOptions() {
    const selected = new Set(this.selectedChannelIds);

    return (this.args.model?.channel_options || []).map((channel) => ({
      ...channel,
      id: String(channel.id),
      selected: selected.has(String(channel.id)),
      messagesCountLabel: this.formatter.format(channel.messages_count),
    }));
  }

  get allChannelsSelected() {
    return this.selectedChannelIds.length === 0;
  }

  get backfillSettingsChanged() {
    return (
      this.hourlyRate !== this.originalHourlyRate ||
      this.backfillMaxAgeDays !== this.originalBackfillMaxAgeDays
    );
  }

  get channelsChanged() {
    return (
      [...this.selectedChannelIds].sort().join("|") !==
      [...this.originalSelectedChannelIds].sort().join("|")
    );
  }

  @action
  async loadProgress() {
    this.loadingProgress = true;

    try {
      const response = await ajax(
        "/admin/plugins/ai-chat-translation/dashboard/progress.json"
      );
      this.data = response.translation_progress;
      this.total = response.total;
      this.messagesWithDetectedLocale = response.messages_with_detected_locale;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingProgress = false;
    }
  }

  @action
  updateHourlyRate(event) {
    this.hourlyRate = event.target.value;
  }

  @action
  updateBackfillMaxAgeDays(event) {
    this.backfillMaxAgeDays = event.target.value;
  }

  @action
  async saveBackfillSettings() {
    this.isSavingBackfill = true;

    try {
      await ajax("/admin/site_settings/ai_chat_translation_backfill_hourly_rate", {
        type: "PUT",
        data: { ai_chat_translation_backfill_hourly_rate: this.hourlyRate },
      });
      await ajax("/admin/site_settings/ai_chat_translation_backfill_max_age_days", {
        type: "PUT",
        data: {
          ai_chat_translation_backfill_max_age_days: this.backfillMaxAgeDays,
        },
      });

      this.originalHourlyRate = this.hourlyRate;
      this.originalBackfillMaxAgeDays = this.backfillMaxAgeDays;
      await this.loadProgress();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSavingBackfill = false;
    }
  }

  @action
  cancelBackfillSettings() {
    this.hourlyRate = this.originalHourlyRate;
    this.backfillMaxAgeDays = this.originalBackfillMaxAgeDays;
  }

  @action
  toggleChannel(channelId, event) {
    if (event.target.checked) {
      this.selectedChannelIds = [
        ...new Set([...this.selectedChannelIds, channelId]),
      ];
    } else {
      this.selectedChannelIds = this.selectedChannelIds.filter(
        (id) => id !== channelId
      );
    }
  }

  @action
  selectAllChannels() {
    this.selectedChannelIds = [];
  }

  @action
  async saveChannels() {
    this.isSavingChannels = true;

    try {
      await ajax("/admin/site_settings/ai_chat_translation_allowed_channel_ids", {
        type: "PUT",
        data: {
          ai_chat_translation_allowed_channel_ids:
            this.selectedChannelIds.join("|"),
        },
      });
      this.originalSelectedChannelIds = [...this.selectedChannelIds];
      await this.loadProgress();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSavingChannels = false;
    }
  }

  @action
  cancelChannels() {
    this.selectedChannelIds = [...this.originalSelectedChannelIds];
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/ai-chat-translation/dashboard"
      @label={{i18n "ai_chat_translation.admin.title"}}
    />

    <div class="ai-chat-translation-dashboard admin-detail">
      <DPageSubheader
        @titleLabel={{i18n "ai_chat_translation.admin.title"}}
        @descriptionLabel={{i18n "ai_chat_translation.admin.description"}}
      />

      <section class="ai-chat-translation-dashboard__stats">
        {{#each this.stats as |stat|}}
          <div class="ai-chat-translation-dashboard__stat">
            <span class="ai-chat-translation-dashboard__stat-value">
              {{stat.value}}
            </span>
            <span class="ai-chat-translation-dashboard__stat-label">
              {{stat.label}}
            </span>
          </div>
        {{/each}}
      </section>

      <section class="ai-chat-translation-dashboard__section">
        <h2>{{i18n "ai_chat_translation.admin.backfill.title"}}</h2>
        <p>{{i18n "ai_chat_translation.admin.backfill.description"}}</p>

        <div class="ai-chat-translation-dashboard__settings-grid">
          <label>
            <span>{{i18n "ai_chat_translation.admin.backfill.hourly_rate"}}</span>
            <input
              type="number"
              min="0"
              value={{this.hourlyRate}}
              {{on "input" this.updateHourlyRate}}
            />
          </label>

          <label>
            <span>{{i18n "ai_chat_translation.admin.backfill.max_age_days"}}</span>
            <input
              type="number"
              min="0"
              value={{this.backfillMaxAgeDays}}
              {{on "input" this.updateBackfillMaxAgeDays}}
            />
          </label>
        </div>

        {{#if this.backfillSettingsChanged}}
          <div class="ai-chat-translation-dashboard__actions">
            <DButton
              @action={{this.saveBackfillSettings}}
              @icon="check"
              @label="ai_chat_translation.admin.save"
              @isLoading={{this.isSavingBackfill}}
              class="btn-primary"
            />
            <DButton
              @action={{this.cancelBackfillSettings}}
              @icon="xmark"
              @label="ai_chat_translation.admin.cancel"
              @isLoading={{this.isSavingBackfill}}
            />
          </div>
        {{/if}}
      </section>

      <section class="ai-chat-translation-dashboard__section">
        <h2>{{i18n "ai_chat_translation.admin.channels.title"}}</h2>
        <p>{{i18n "ai_chat_translation.admin.channels.description"}}</p>

        <label class="ai-chat-translation-dashboard__all-channels">
          <input
            type="checkbox"
            checked={{this.allChannelsSelected}}
            {{on "change" this.selectAllChannels}}
          />
          <span>{{i18n "ai_chat_translation.admin.channels.all_public"}}</span>
        </label>

        <div class="ai-chat-translation-dashboard__channel-list">
          {{#each this.channelOptions as |channel|}}
            <label class="ai-chat-translation-dashboard__channel-row">
              <input
                type="checkbox"
                checked={{channel.selected}}
                {{on "change" (fn this.toggleChannel channel.id)}}
              />
              <span class="ai-chat-translation-dashboard__channel-title">
                {{channel.title}}
              </span>
              <span class="ai-chat-translation-dashboard__channel-count">
                {{i18n
                  "ai_chat_translation.admin.channels.messages"
                  count=channel.messagesCountLabel
                }}
              </span>
            </label>
          {{/each}}
        </div>

        {{#if this.channelsChanged}}
          <div class="ai-chat-translation-dashboard__actions">
            <DButton
              @action={{this.saveChannels}}
              @icon="check"
              @label="ai_chat_translation.admin.save"
              @isLoading={{this.isSavingChannels}}
              class="btn-primary"
            />
            <DButton
              @action={{this.cancelChannels}}
              @icon="xmark"
              @label="ai_chat_translation.admin.cancel"
              @isLoading={{this.isSavingChannels}}
            />
          </div>
        {{/if}}
      </section>

      <section class="ai-chat-translation-dashboard__section">
        <h2>{{i18n "ai_chat_translation.admin.progress.title"}}</h2>

        {{#if this.loadingProgress}}
          <p>{{i18n "ai_chat_translation.admin.progress.loading"}}</p>
        {{else if this.progressRows.length}}
          <div class="ai-chat-translation-dashboard__progress-list">
            {{#each this.progressRows as |row|}}
              <div class="ai-chat-translation-dashboard__progress-row">
                <div class="ai-chat-translation-dashboard__progress-header">
                  <span>{{row.language}}</span>
                  <span>
                    {{i18n
                      "ai_chat_translation.admin.progress.row"
                      done=row.doneLabel
                      total=row.totalLabel
                      pending=row.pendingLabel
                      percent=row.percentage
                    }}
                  </span>
                </div>
                <div class="ai-chat-translation-dashboard__progress-track">
                  <div
                    class="ai-chat-translation-dashboard__progress-bar"
                    style={{row.style}}
                  ></div>
                </div>
              </div>
            {{/each}}
          </div>
        {{else}}
          <p>{{i18n "ai_chat_translation.admin.progress.empty"}}</p>
        {{/if}}
      </section>
    </div>
  </template>
}
