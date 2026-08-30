import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class AiChatTranslationDashboard extends Component {
  @service languageNameLookup;
  @service router;

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

  get formattedTotal() {
    return this.formatter.format(this.total);
  }

  get formattedDetected() {
    return this.formatter.format(this.messagesWithDetectedLocale);
  }

  get detectionRate() {
    if (this.total === 0) {
      return 0;
    }
    return Math.min(
      100,
      Math.round((this.messagesWithDetectedLocale / this.total) * 100)
    );
  }

  get detectionBarStyle() {
    return trustHTML(`width: ${this.detectionRate}%`);
  }

  get totalTranslations() {
    return this.data.reduce(
      (sum, row) => sum + (Number(row.total) || 0),
      0
    );
  }

  get completedTranslations() {
    return this.data.reduce(
      (sum, row) => sum + (Number(row.done) || 0),
      0
    );
  }

  get pendingTranslations() {
    return this.data.reduce(
      (sum, row) =>
        sum + Math.max(0, (Number(row.total) || 0) - (Number(row.done) || 0)),
      0
    );
  }

  get formattedTotalTranslations() {
    return this.formatter.format(this.totalTranslations);
  }

  get formattedCompleted() {
    return this.formatter.format(this.completedTranslations);
  }

  get formattedPending() {
    return this.formatter.format(this.pendingTranslations);
  }

  get overallPercentage() {
    if (this.totalTranslations > 0) {
      return Math.min(
        100,
        Math.round((this.completedTranslations / this.totalTranslations) * 100)
      );
    }
    return this.total > 0 ? 100 : 0;
  }

  get overallBarStyle() {
    return trustHTML(`width: ${this.overallPercentage}%`);
  }

  get progressRows() {
    return this.data.map((row) => {
      const done = Number(row.done) || 0;
      const total = Number(row.total) || 0;
      const pending = Math.max(0, total - done);
      const percentage =
        total > 0 ? Math.min(100, Math.round((done / total) * 100)) : 100;
      const isComplete = total > 0 && done === total;

      return {
        locale: row.locale,
        language:
          this.languageNameLookup.getLanguageName(row.locale) || row.locale,
        done,
        total,
        pending,
        percentage,
        isComplete,
        progressStyle: trustHTML(`width: ${percentage}%`),
        doneFormatted: this.formatter.format(done),
        totalFormatted: this.formatter.format(total),
        pendingFormatted: this.formatter.format(pending),
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
      this.data = response.translation_progress || [];
      this.total = response.total || 0;
      this.messagesWithDetectedLocale =
        response.messages_with_detected_locale || 0;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingProgress = false;
    }
  }

  @action
  navigateToSettings() {
    this.router.transitionTo("adminPlugins.show", "ai-chat-translation");
  }

  <template>
    <DBreadcrumbsItem
      @route="adminPlugins.show.ai-chat-translation-dashboard"
      @label={{i18n "ai_chat_translation.admin.nav.dashboard"}}
    />

    <div class="ai-chat-translation-dashboard admin-detail">
      <DPageSubheader
        @titleLabel={{i18n "ai_chat_translation.admin.title"}}
        @descriptionLabel={{i18n "ai_chat_translation.admin.description"}}
      >
        <:actions as |actions|>
          <DButton
            @icon="rotate"
            @action={{this.loadProgress}}
            @isLoading={{this.loadingProgress}}
            @label="ai_chat_translation.admin.progress.refresh"
            class="btn-default ai-chat-translation-dashboard__refresh-btn"
          />
          <actions.Default
            @label="ai_chat_translation.admin.nav.settings"
            @icon="gear"
            @route="adminPlugins.show"
            @routeModels="ai-chat-translation"
            class="btn-default"
          />
        </:actions>
      </DPageSubheader>

      <section class="ai-chat-translation-dashboard__stats">
        <div class="ai-chat-translation-dashboard__stat-card">
          <div class="ai-chat-translation-dashboard__stat-card-header">
            <div class="ai-chat-translation-dashboard__stat-icon --messages">
              {{dIcon "comments"}}
            </div>
          </div>
          <div class="ai-chat-translation-dashboard__stat-value">
            {{this.formattedTotal}}
          </div>
          <div class="ai-chat-translation-dashboard__stat-label">
            {{i18n "ai_chat_translation.admin.stats.total"}}
          </div>
          <div class="ai-chat-translation-dashboard__stat-desc">
            {{i18n "ai_chat_translation.admin.stats.total_desc"}}
          </div>
        </div>

        <div class="ai-chat-translation-dashboard__stat-card">
          <div class="ai-chat-translation-dashboard__stat-card-header">
            <div class="ai-chat-translation-dashboard__stat-icon --detection">
              {{dIcon "language"}}
            </div>
            <span class="ai-chat-translation-dashboard__badge --info">
              {{this.detectionRate}}%
            </span>
          </div>
          <div class="ai-chat-translation-dashboard__stat-value">
            {{this.formattedDetected}}
          </div>
          <div class="ai-chat-translation-dashboard__stat-label">
            {{i18n "ai_chat_translation.admin.stats.detected"}}
          </div>
          <div class="ai-chat-translation-dashboard__stat-desc">
            {{i18n "ai_chat_translation.admin.stats.detected_desc"}}
          </div>
          <div class="ai-chat-translation-dashboard__mini-track">
            <div
              class="ai-chat-translation-dashboard__mini-bar --info"
              style={{this.detectionBarStyle}}
            ></div>
          </div>
        </div>

        <div class="ai-chat-translation-dashboard__stat-card">
          <div class="ai-chat-translation-dashboard__stat-card-header">
            <div class="ai-chat-translation-dashboard__stat-icon --pending">
              {{dIcon "clock"}}
            </div>
            {{#if (eq this.pendingTranslations 0)}}
              <span class="ai-chat-translation-dashboard__badge --success">
                {{dIcon "check"}}
                {{i18n "ai_chat_translation.admin.stats.all_completed"}}
              </span>
            {{else}}
              <span class="ai-chat-translation-dashboard__badge --warning">
                {{i18n "ai_chat_translation.admin.stats.waiting"}}
              </span>
            {{/if}}
          </div>
          <div class="ai-chat-translation-dashboard__stat-value">
            {{this.formattedPending}}
          </div>
          <div class="ai-chat-translation-dashboard__stat-label">
            {{i18n "ai_chat_translation.admin.stats.pending"}}
          </div>
          <div class="ai-chat-translation-dashboard__stat-desc">
            {{i18n "ai_chat_translation.admin.stats.pending_desc"}}
          </div>
        </div>

        <div class="ai-chat-translation-dashboard__stat-card">
          <div class="ai-chat-translation-dashboard__stat-card-header">
            <div class="ai-chat-translation-dashboard__stat-icon --completed">
              {{dIcon "circle-check"}}
            </div>
            <span class="ai-chat-translation-dashboard__badge --success">
              {{this.formattedCompleted}}
              /
              {{this.formattedTotalTranslations}}
            </span>
          </div>
          <div class="ai-chat-translation-dashboard__stat-value">
            {{this.overallPercentage}}%
          </div>
          <div class="ai-chat-translation-dashboard__stat-label">
            {{i18n "ai_chat_translation.admin.stats.overall"}}
          </div>
          <div class="ai-chat-translation-dashboard__stat-desc">
            {{i18n "ai_chat_translation.admin.stats.overall_desc"}}
          </div>
          <div class="ai-chat-translation-dashboard__mini-track">
            <div
              class="ai-chat-translation-dashboard__mini-bar --success"
              style={{this.overallBarStyle}}
            ></div>
          </div>
        </div>
      </section>

      <section class="ai-chat-translation-dashboard__section">
        <div class="ai-chat-translation-dashboard__section-header">
          <div>
            <h2>{{i18n "ai_chat_translation.admin.progress.title"}}</h2>
            <p>{{i18n "ai_chat_translation.admin.progress.subtitle"}}</p>
          </div>
          {{#if this.progressRows.length}}
            <span class="ai-chat-translation-dashboard__section-count">
              {{this.progressRows.length}}
              {{i18n "ai_chat_translation.admin.progress.stat_total"}}
            </span>
          {{/if}}
        </div>

        {{#if this.loadingProgress}}
          <div class="ai-chat-translation-dashboard__skeleton-grid">
            <div class="ai-chat-translation-dashboard__skeleton-card"></div>
            <div class="ai-chat-translation-dashboard__skeleton-card"></div>
          </div>
        {{else if this.progressRows.length}}
          <div class="ai-chat-translation-dashboard__language-grid">
            {{#each this.progressRows as |row|}}
              <div class="ai-chat-translation-dashboard__lang-card">
                <div class="ai-chat-translation-dashboard__lang-header">
                  <div class="ai-chat-translation-dashboard__lang-identity">
                    <span class="ai-chat-translation-dashboard__lang-name">
                      {{row.language}}
                    </span>
                    <span class="ai-chat-translation-dashboard__lang-code">
                      {{row.locale}}
                    </span>
                  </div>
                  {{#if row.isComplete}}
                    <span class="ai-chat-translation-dashboard__badge --success">
                      {{dIcon "check"}}
                      {{row.percentage}}%
                      {{i18n
                        "ai_chat_translation.admin.progress.completed_badge"
                      }}
                    </span>
                  {{else}}
                    <span class="ai-chat-translation-dashboard__badge --primary">
                      {{row.percentage}}%
                    </span>
                  {{/if}}
                </div>

                <div class="ai-chat-translation-dashboard__progress-track">
                  <div
                    class="ai-chat-translation-dashboard__progress-bar
                      {{if row.isComplete '--complete'}}"
                    style={{row.progressStyle}}
                  ></div>
                </div>

                <div class="ai-chat-translation-dashboard__lang-metrics">
                  <div class="ai-chat-translation-dashboard__metric-item">
                    <span class="ai-chat-translation-dashboard__metric-label">
                      {{i18n "ai_chat_translation.admin.progress.stat_done"}}
                    </span>
                    <span
                      class="ai-chat-translation-dashboard__metric-val --done"
                    >
                      {{row.doneFormatted}}
                    </span>
                  </div>
                  <div class="ai-chat-translation-dashboard__metric-item">
                    <span class="ai-chat-translation-dashboard__metric-label">
                      {{i18n "ai_chat_translation.admin.progress.stat_pending"}}
                    </span>
                    <span
                      class="ai-chat-translation-dashboard__metric-val --pending"
                    >
                      {{row.pendingFormatted}}
                    </span>
                  </div>
                  <div class="ai-chat-translation-dashboard__metric-item">
                    <span class="ai-chat-translation-dashboard__metric-label">
                      {{i18n "ai_chat_translation.admin.progress.stat_total"}}
                    </span>
                    <span
                      class="ai-chat-translation-dashboard__metric-val --total"
                    >
                      {{row.totalFormatted}}
                    </span>
                  </div>
                </div>
              </div>
            {{/each}}
          </div>
        {{else}}
          <div class="ai-chat-translation-dashboard__empty-state">
            <div class="ai-chat-translation-dashboard__empty-icon">
              {{dIcon "language"}}
            </div>
            <h3>{{i18n "ai_chat_translation.admin.progress.empty_title"}}</h3>
            <p>{{i18n "ai_chat_translation.admin.progress.empty"}}</p>
            <DButton
              @icon="gear"
              @action={{this.navigateToSettings}}
              @label="ai_chat_translation.admin.progress.configure_settings"
              class="btn-primary"
            />
          </div>
        {{/if}}
      </section>
    </div>
  </template>
}
