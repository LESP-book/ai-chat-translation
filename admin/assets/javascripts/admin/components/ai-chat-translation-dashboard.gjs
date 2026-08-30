import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

export default class AiChatTranslationDashboard extends Component {
  @service languageNameLookup;

  @tracked data = [];
  @tracked total = 0;
  @tracked messagesWithDetectedLocale = 0;
  @tracked loadingProgress = false;

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

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/ai-chat-translation/dashboard"
      @label={{i18n "ai_chat_translation.admin.nav.dashboard"}}
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
