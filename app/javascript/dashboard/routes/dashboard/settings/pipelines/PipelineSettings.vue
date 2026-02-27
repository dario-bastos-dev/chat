<template>
  <div class="column content-box">
    <div class="row">
      <div class="small-8 columns">
        <ul class="tabs settings-tabs">
          <li class="tabs-title is-active">
            <a href="#">{{ $t('CRM.PIPELINES.TITLE') }}</a>
          </li>
        </ul>
      </div>
      <div class="small-4 columns text-right">
        <woot-button
          icon="add"
          color-scheme="success"
          @click="openAddPipelineModal"
        >
          {{ $t('CRM.PIPELINES.CREATE') }}
        </woot-button>
      </div>
    </div>

    <div class="row">
      <div class="small-12 columns">
        <div v-if="isLoading" class="text-center p-4">
          <spinner size="medium" />
        </div>

        <div v-else-if="pipelines.length === 0" class="empty-state">
          <p>{{ $t('CRM.PIPELINES.EMPTY.DESCRIPTION') }}</p>
        </div>

        <div v-else class="pipelines-list">
          <table class="woot-table">
            <thead>
              <tr>
                <th>{{ $t('CRM.PIPELINES.FORM.NAME') }}</th>
                <th>{{ $t('CRM.STAGES.TITLE') }}</th>
                <th>{{ $t('CRM.DEALS.TITLE') }}</th>
                <th>{{ $t('CRM.PIPELINES.DEFAULT') }}</th>
                <th>{{ $t('CRM.SETTINGS') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="pipeline in pipelines" :key="pipeline.id">
                <td>{{ pipeline.name }}</td>
                <td>{{ pipeline.stages ? pipeline.stages.length : 0 }}</td>
                <td>{{ pipeline.deals_count || 0 }}</td>
                <td>
                  <span v-if="pipeline.is_default" class="label success">
                    {{ $t('CRM.PIPELINES.DEFAULT') }}
                  </span>
                </td>
                <td>
                  <div class="button-group">
                    <woot-button
                      variant="smooth"
                      size="small"
                      icon="edit"
                      @click="editPipeline(pipeline)"
                    >
                      {{ $t('CRM.UPDATE') }}
                    </woot-button>
                    <woot-button
                      v-if="!pipeline.is_default"
                      variant="smooth"
                      color-scheme="alert"
                      size="small"
                      icon="delete"
                      @click="deletePipeline(pipeline)"
                    >
                      {{ $t('CRM.DELETE') }}
                    </woot-button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Add/Edit Pipeline Modal -->
    <woot-modal v-model:show="showModal" :on-close="closeModal">
      <div class="modal-header">
        <h3 class="modal-title">
          {{
            isEditing
              ? $t('CRM.PIPELINES.EDIT_TITLE')
              : $t('CRM.PIPELINES.CREATE')
          }}
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
                  <span
                    class="drag-handle i-ph-dots-six-vertical size-4"
                  ></span>
                  <div class="stage-inputs">
                    <input
                      v-model="stage.name"
                      type="text"
                      class="stage-name-input"
                      :placeholder="$t('CRM.STAGES.FORM.NAME')"
                      required
                    />
                    <div class="stage-meta-inputs">
                      <label
                        class="rotting-days-label"
                        :title="$t('CRM.STAGES.FORM.ROTTING_DAYS')"
                      >
                        <span class="i-ph-clock size-4 text-n-slate-10" />
                        <input
                          v-model.number="stage.rotting_days"
                          type="number"
                          class="rotting-days-input"
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
  </div>
</template>

<script>
import { mapGetters, mapActions } from 'vuex';
import Spinner from 'shared/components/Spinner.vue';
import Draggable from 'vuedraggable';

export default {
  components: {
    Spinner,
    Draggable,
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
      },
      isEditing: false,
    };
  },
  computed: {
    ...mapGetters({
      pipelines: 'pipelines/getPipelines',
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
          { name: 'New', position: 1 },
          { name: 'Qualified', position: 2 },
          { name: 'Won', position: 3 },
          { name: 'Lost', position: 4 },
        ],
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
      this.currentPipeline = { name: '', is_default: false, stages: [] };
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
.stages-section {
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

  .rotting-days-label {
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

  .rotting-days-input {
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
