<template>
  <SettingsLayout
    :is-loading="isLoading"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('CRM.PIPELINES.TITLE')"
        :description="$t('CRM.PIPELINES.TITLE')"
        :link-text="$t('CRM.PIPELINES.TITLE')"
      >
        <template v-if="pipelines && pipelines.length" #count>
          <span class="text-body-main text-n-slate-11 truncate min-w-0">
            {{ pipelines.length }}
          </span>
        </template>
        <template #actions>
          <Button
            :label="$t('CRM.PIPELINES.CREATE')"
            size="sm"
            @click="openAddPipelineModal"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div v-if="pipelines.length === 0" class="flex-1 flex items-center justify-center py-20 text-center text-body-main text-n-slate-11">
        {{ $t('CRM.PIPELINES.EMPTY.DESCRIPTION') }}
      </div>

      <div v-else class="flex flex-col divide-y divide-n-weak border-t border-n-weak">
        <div
          v-for="pipeline in pipelines"
          :key="pipeline.id"
          class="flex flex-row justify-between items-start gap-4 py-4"
        >
          <div class="flex items-center gap-4">
            <div class="flex flex-col items-start gap-1">
              <div class="flex gap-2 items-center">
                <span class="block text-heading-3 text-n-slate-12 capitalize">
                  {{ pipeline.name }}
                </span>
                <span v-if="pipeline.is_default" class="text-n-slate-11 text-xs bg-n-alpha-2 px-2 py-0.5 rounded-full">
                  {{ $t('CRM.PIPELINES.DEFAULT') }}
                </span>
              </div>
              <span class="text-body-main text-n-slate-11">
                {{ pipeline.stages ? pipeline.stages.length : 0 }} {{ $t('CRM.STAGES.TITLE') }} - {{ pipeline.deals_count || 0 }} {{ $t('CRM.DEALS.TITLE') }}
              </span>
            </div>
          </div>

          <div class="flex gap-3 justify-end">
            <Button
              v-tooltip.top="$t('CRM.UPDATE')"
              icon="i-lucide-pencil"
              slate
              sm
              @click="editPipeline(pipeline)"
            />
            <Button
              v-if="!pipeline.is_default"
              v-tooltip.top="$t('CRM.DELETE')"
              icon="i-woot-bin"
              slate
              sm
              class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
              @click="deletePipeline(pipeline)"
            />
          </div>
        </div>
      </div>
    </template>
  </SettingsLayout>

  <!-- Add/Edit Pipeline Modal -->
  <woot-modal v-model:show="showModal" :on-close="closeModal">
    <div class="modal-header">
      <h3 class="modal-title">
        {{ isEditing ? $t('CRM.PIPELINES.EDIT_TITLE') : $t('CRM.PIPELINES.CREATE') }}
      </h3>
    </div>

    <div class="modal-body">
      <form @submit.prevent="savePipeline">
        <div class="form-group">
          <label>
            {{ $t('CRM.PIPELINES.FORM.NAME') }}
            <input
              v-model="currentPipeline.name"
              type="text"
              :placeholder="$t('CRM.PIPELINES.FORM.NAME_PLACEHOLDER')"
              required
            />
          </label>
        </div>

        <div class="form-group">
          <label class="checkbox-label">
            <input type="checkbox" v-model="currentPipeline.is_default" />
            {{ $t('CRM.PIPELINES.FORM.IS_DEFAULT') }}
          </label>
        </div>

        <div class="stages-section">
          <h4>{{ $t('CRM.STAGES.TITLE') }}</h4>
          <p class="help-text">{{ $t('CRM.STAGES.HELP_TEXT') }}</p>

          <draggable
            v-model="currentPipeline.stages"
            handle=".drag-handle"
            item-key="id"
          >
            <template #item="{ element: stage, index }">
              <div class="stage-item">
                <span class="drag-handle i-ph-dots-six-vertical size-4"></span>
                <div class="stage-inputs">
                  <input
                    v-model="stage.name"
                    type="text"
                    class="stage-name-input"
                    :placeholder="$t('CRM.STAGES.FORM.NAME')"
                    required
                  />
                  <div class="stage-meta-inputs">
                    <label class="stage-meta-label" :title="$t('CRM.STAGES.FORM.WIN_PROBABILITY')">
                      <span class="i-ph-percent size-4 text-n-slate-10" />
                      <input
                        v-model.number="stage.win_probability"
                        type="number"
                        class="stage-meta-input"
                        min="0"
                        max="100"
                        placeholder="0"
                      />
                    </label>
                    <label class="stage-meta-label" :title="$t('CRM.STAGES.FORM.ROTTING_DAYS')">
                      <span class="i-ph-clock size-4 text-n-slate-10" />
                      <input
                        v-model.number="stage.rotting_days"
                        type="number"
                        class="stage-meta-input"
                        min="0"
                        placeholder="0"
                      />
                      <span class="unit">{{ $t('CRM.REPORTS.DAYS') }}</span>
                    </label>
                  </div>
                </div>
                <div class="stage-actions">
                  <woot-button
                    variant="clear"
                    color-scheme="alert"
                    size="tiny"
                    icon="dismiss"
                    @click="removeStage(index)"
                  />
                </div>
              </div>
            </template>
          </draggable>

          <woot-button
            variant="smooth"
            size="small"
            icon="add"
            class="add-stage-btn"
            @click="addStage"
          >
            {{ $t('CRM.STAGES.CREATE') }}
          </woot-button>
        </div>

        <div class="settings-section">
          <h4>{{ $t('CRM.PIPELINES.FORM.LOST_REASONS_TITLE') }}</h4>
          <p class="help-text">{{ $t('CRM.PIPELINES.FORM.LOST_REASONS_HELP') }}</p>
          <div
            v-for="(reason, idx) in currentPipeline.lost_reasons"
            :key="idx"
            class="lost-reason-item"
          >
            <input
              v-model="currentPipeline.lost_reasons[idx]"
              type="text"
              class="lost-reason-input"
              :placeholder="$t('CRM.PIPELINES.FORM.LOST_REASON_PLACEHOLDER')"
            />
            <woot-button
              variant="clear"
              color-scheme="alert"
              size="tiny"
              icon="dismiss"
              @click="removeLostReason(idx)"
            />
          </div>
          <woot-button
            variant="smooth"
            size="small"
            icon="add"
            class="add-stage-btn"
            @click="addLostReason"
          >
            {{ $t('CRM.PIPELINES.FORM.ADD_LOST_REASON') }}
          </woot-button>
        </div>

        <div class="settings-section">
          <h4>{{ $t('CRM.PIPELINES.FORM.VISIBILITY_TITLE') }}</h4>
          <p class="help-text">{{ $t('CRM.PIPELINES.FORM.VISIBILITY_HELP') }}</p>
          <div class="form-group">
            <select v-model="currentPipeline.visibility" class="visibility-select">
              <option value="public">{{ $t('CRM.PIPELINES.FORM.VISIBILITY_PUBLIC') }}</option>
              <option value="restricted">{{ $t('CRM.PIPELINES.FORM.VISIBILITY_RESTRICTED') }}</option>
            </select>
          </div>
          <div v-if="currentPipeline.visibility === 'restricted'" class="form-group">
            <label>{{ $t('CRM.PIPELINES.FORM.ALLOWED_TEAMS') }}</label>
            <div class="teams-checkboxes">
              <label
                v-for="team in teams"
                :key="team.id"
                class="checkbox-label"
              >
                <input
                  type="checkbox"
                  :value="team.id"
                  :checked="currentPipeline.allowed_team_ids.includes(team.id)"
                  @change="toggleTeam(team.id)"
                />
                {{ team.name }}
              </label>
            </div>
          </div>
        </div>

        <div class="modal-footer">
          <woot-button variant="clear" @click.prevent="closeModal">
            {{ $t('CRM.CANCEL') }}
          </woot-button>
          <woot-button type="submit" :is-loading="isSaving">
            {{ isEditing ? $t('CRM.UPDATE') : $t('CRM.CREATE') }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>

<script>
import { mapGetters, mapActions } from 'vuex';
import Spinner from 'shared/components/Spinner.vue';
import Draggable from 'vuedraggable';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    Spinner,
    Draggable,
    SettingsLayout,
    BaseSettingsHeader,
    Button,
  },
  data() {
    return {
      isLoading: false,
      isSaving: false,
      showModal: false,
      currentPipeline: {
        name: '',
        is_default: false,
        stages: [],
        lost_reasons: [],
        visibility: 'public',
        allowed_team_ids: [],
      },
      isEditing: false,
    };
  },
  computed: {
    ...mapGetters({
      pipelines: 'pipelines/getPipelines',
      teams: 'teams/getTeams',
    }),
  },
  mounted() {
    this.fetchPipelines();
  },
  methods: {
    ...mapActions({
      fetchPipelinesAction: 'pipelines/get',
      createPipeline: 'pipelines/create',
      updatePipeline: 'pipelines/update',
      deletePipelineAction: 'pipelines/delete',
    }),
    async fetchPipelines() {
      this.isLoading = true;
      try {
        await this.fetchPipelinesAction();
      } catch (error) {
        this.$toast.error(this.$t('CRM.PIPELINES.FETCH_ERROR'));
      } finally {
        this.isLoading = false;
      }
    },
    openAddPipelineModal() {
      this.isEditing = false;
      this.currentPipeline = {
        name: '',
        is_default: false,
        stages: [
          { name: 'New', position: 1, win_probability: 10 },
          { name: 'Qualified', position: 2, win_probability: 30 },
          { name: 'Won', position: 3, win_probability: 100 },
          { name: 'Lost', position: 4, win_probability: 0 },
        ],
        lost_reasons: [],
        visibility: 'public',
        allowed_team_ids: [],
      };
      this.showModal = true;
    },
    editPipeline(pipeline) {
      this.isEditing = true;
      this.currentPipeline = JSON.parse(JSON.stringify(pipeline));
      // Ensure stages are ordered by position
      if (this.currentPipeline.stages) {
        this.currentPipeline.stages.sort((a, b) => a.position - b.position);
      }
      this.showModal = true;
    },
    closeModal() {
      this.showModal = false;
      this.currentPipeline = {
        name: '', is_default: false, stages: [],
        lost_reasons: [], visibility: 'public', allowed_team_ids: [],
      };
    },
    addLostReason() {
      this.currentPipeline.lost_reasons.push('');
    },
    removeLostReason(index) {
      this.currentPipeline.lost_reasons.splice(index, 1);
    },
    toggleTeam(teamId) {
      const idx = this.currentPipeline.allowed_team_ids.indexOf(teamId);
      if (idx > -1) {
        this.currentPipeline.allowed_team_ids.splice(idx, 1);
      } else {
        this.currentPipeline.allowed_team_ids.push(teamId);
      }
    },
    addStage() {
      this.currentPipeline.stages.push({
        name: '',
        position: this.currentPipeline.stages.length + 1,
      });
    },
    removeStage(index) {
      this.currentPipeline.stages.splice(index, 1);
    },
    async savePipeline() {
      this.isSaving = true;

      // Update positions based on current order
      this.currentPipeline.stages.forEach((stage, index) => {
        stage.position = index + 1;
      });

      try {
        if (this.isEditing) {
          await this.updatePipeline(this.currentPipeline);
          this.$toast.success(this.$t('CRM.PIPELINES.UPDATE_SUCCESS'));
        } else {
          await this.createPipeline(this.currentPipeline);
          this.$toast.success(this.$t('CRM.PIPELINES.CREATE_SUCCESS'));
        }
        this.closeModal();
        this.fetchPipelines();
      } catch (error) {
        this.$toast.error(error.message || this.$t('CRM.PIPELINES.SAVE_ERROR'));
      } finally {
        this.isSaving = false;
      }
    },
    async deletePipeline(pipeline) {
      const result = await this.$confirm({
        title: this.$t('CRM.PIPELINES.DELETE_CONFIRM_TITLE'),
        message: this.$t('CRM.PIPELINES.DELETE_CONFIRM_MESSAGE'),
      });

      if (result) {
        try {
          await this.deletePipelineAction(pipeline.id);
          this.$toast.success(this.$t('CRM.PIPELINES.DELETE_SUCCESS'));
          this.fetchPipelines();
        } catch (error) {
          this.$toast.error(this.$t('CRM.PIPELINES.DELETE_ERROR'));
        }
      }
    },
  },
};
</script>

<style lang="scss" scoped>
.stages-section,
.settings-section {
  margin-top: var(--space-normal);
  padding-top: var(--space-normal);
  border-top: 1px solid var(--color-border);

  h4 {
    font-size: var(--font-size-small);
    font-weight: var(--font-weight-bold);
    margin-bottom: var(--space-smaller);
  }

  .help-text {
    font-size: var(--font-size-micro);
    color: var(--color-light-gray);
    margin-bottom: var(--space-small);
  }
}

.stage-item {
  display: flex;
  align-items: center;
  gap: var(--space-small);
  margin-bottom: var(--space-smaller);
  padding: var(--space-smaller);
  background: var(--color-background-light);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-small);

  .drag-handle {
    cursor: move;
    color: var(--color-gray);
  }

  .stage-inputs {
    flex: 1;
    display: flex;
    align-items: center;
    gap: var(--space-small);
  }

  .stage-name-input {
    flex: 1;
    margin-bottom: 0;
    border: none;
    background: transparent;
    font-weight: var(--font-weight-medium);

    &:focus {
      outline: none;
      background: var(--white);
    }
  }

  .stage-meta-inputs {
    display: flex;
    align-items: center;
    gap: var(--space-small);
  }

  .stage-meta-label {
    display: flex;
    align-items: center;
    gap: var(--space-demi);
    padding: var(--space-smaller) var(--space-small);
    background: var(--white);
    border: 1px solid var(--color-border);
    border-radius: var(--border-radius-small);
    margin: 0;

    .unit {
      color: var(--color-gray);
      font-size: var(--font-size-micro);
    }
  }

  .stage-meta-input {
    width: 40px;
    margin: 0;
    border: none;
    padding: 0;
    text-align: right;
    font-size: var(--font-size-small);

    &:focus {
      outline: none;
    }

    &::-webkit-inner-spin-button,
    &::-webkit-outer-spin-button {
      -webkit-appearance: none;
      margin: 0;
    }
  }
}

.lost-reason-item {
  display: flex;
  align-items: center;
  gap: var(--space-small);
  margin-bottom: var(--space-smaller);

  .lost-reason-input {
    flex: 1;
    margin-bottom: 0;
  }
}

.visibility-select {
  width: 100%;
  margin-bottom: 0;
}

.teams-checkboxes {
  display: flex;
  flex-direction: column;
  gap: var(--space-smaller);
  margin-top: var(--space-smaller);
}

.add-stage-btn {
  margin-top: var(--space-small);
  width: 100%;
}

.pipelines-list {
  background: var(--white);
  border-radius: var(--border-radius-medium);
  box-shadow: var(--shadow-small);
  padding: var(--space-medium);
}

.empty-state {
  display: flex;
  justify-content: center;
  padding: var(--space-large);
  color: var(--color-gray);
}

.button-group {
  display: flex;
  gap: var(--space-smaller);
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: var(--space-smaller);
  cursor: pointer;
}
</style>
