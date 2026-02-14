<template>
  <div class="contact-deals">
    <div v-if="isLoading" class="loading-state">
      <spinner size="small" />
    </div>

    <div v-else-if="deals.length === 0" class="empty-state">
      <p>{{ $t('CRM.DEALS.SIDEBAR.EMPTY') }}</p>
      <woot-button
        variant="smooth"
        size="small"
        icon="add"
        @click="openCreateDealModal"
      >
        {{ $t('CRM.DEALS.SIDEBAR.CREATE') }}
      </woot-button>
    </div>

    <div v-else class="deals-list">
      <div
        v-for="deal in deals"
        :key="deal.id"
        class="deal-item"
        :class="{
          'is-won': deal.status === 'won',
          'is-lost': deal.status === 'lost',
          'is-rotting': deal.is_rotting,
        }"
        @click="openDealDetails(deal)"
      >
        <div class="deal-header">
          <span class="deal-title">{{ deal.title }}</span>
          <span class="deal-value">{{ formatCurrency(deal.value) }}</span>
        </div>
        <div class="deal-meta">
          <span class="deal-stage">
            <fluent-icon icon="board" size="12" />
            {{ deal.stage?.name || deal.pipeline?.name }}
          </span>
          <span v-if="deal.status !== 'open'" class="deal-status">
            <fluent-icon
              :icon="
                deal.status === 'won' ? 'checkmark-circle' : 'dismiss-circle'
              "
              size="12"
            />
            {{
              deal.status === 'won'
                ? $t('CRM.DEALS.STATUS_WON')
                : $t('CRM.DEALS.STATUS_LOST')
            }}
          </span>
        </div>
      </div>

      <woot-button
        variant="clear"
        size="small"
        icon="add"
        class="add-deal-btn"
        @click="openCreateDealModal"
      >
        {{ $t('CRM.DEALS.SIDEBAR.ADD') }}
      </woot-button>
    </div>

    <!-- Create Deal Modal -->
    <woot-modal v-model:show="showCreateModal" :on-close="closeCreateModal">
      <div class="create-deal-modal">
        <woot-modal-header :header-title="$t('CRM.DEALS.CREATE')" />
        <form @submit.prevent="createDeal">
          <div class="form-field">
            <label>{{ $t('CRM.DEALS.FORM.TITLE') }} *</label>
            <input
              v-model="newDeal.title"
              type="text"
              :placeholder="$t('CRM.DEALS.FORM.TITLE_PLACEHOLDER')"
              required
            />
          </div>

          <div class="form-row">
            <div class="form-field">
              <label>{{ $t('CRM.DEALS.FORM.VALUE') }}</label>
              <input
                v-model.number="newDeal.value"
                type="number"
                step="0.01"
                min="0"
                :placeholder="$t('CRM.DEALS.FORM.VALUE_PLACEHOLDER')"
              />
            </div>
            <div class="form-field">
              <label>{{ $t('CRM.DEALS.FORM.CURRENCY') }}</label>
              <select v-model="newDeal.currency">
                <option value="BRL">BRL</option>
                <option value="USD">USD</option>
                <option value="EUR">EUR</option>
              </select>
            </div>
          </div>

          <div class="form-field">
            <label>{{ $t('CRM.DEALS.FORM.PIPELINE') }} *</label>
            <select
              v-model="selectedPipelineId"
              required
              @change="onPipelineChange"
            >
              <option
                v-for="pipeline in pipelines"
                :key="pipeline.id"
                :value="pipeline.id"
              >
                {{ pipeline.name }}
              </option>
            </select>
          </div>

          <div class="form-field">
            <label>{{ $t('CRM.DEALS.FORM.STAGE') }} *</label>
            <select v-model="newDeal.stage_id" required>
              <option
                v-for="stage in currentStages"
                :key="stage.id"
                :value="stage.id"
              >
                {{ stage.name }}
              </option>
            </select>
          </div>

          <div class="form-field">
            <label>{{ $t('CRM.DEALS.FORM.ASSIGNEE') }}</label>
            <select v-model="newDeal.assignee_id">
              <option :value="null">
                {{ $t('CRM.DEALS.FORM.UNASSIGNED') }}
              </option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name }}
              </option>
            </select>
          </div>

          <div class="modal-footer">
            <woot-button variant="clear" @click.prevent="closeCreateModal">
              {{ $t('CRM.CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              color-scheme="primary"
              :is-loading="isCreating"
            >
              {{ $t('CRM.CREATE') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Deal Details Modal -->
    <woot-modal v-model:show="showDetailsModal" :on-close="closeDetailsModal">
      <div v-if="selectedDeal" class="deal-details-modal">
        <woot-modal-header :header-title="selectedDeal.title" />
        <div class="deal-details-content">
          <div class="detail-row">
            <span class="detail-label">{{ $t('CRM.DEALS.VALUE') }}</span>
            <span class="detail-value highlight">{{
              formatCurrency(selectedDeal.value)
            }}</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">{{ $t('CRM.DEALS.STAGE') }}</span>
            <span class="detail-value">{{ selectedDeal.stage?.name }}</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">{{ $t('CRM.DEALS.PIPELINE') }}</span>
            <span class="detail-value">{{ selectedDeal.pipeline?.name }}</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">{{ $t('CRM.DEALS.ASSIGNEE') }}</span>
            <span class="detail-value">{{
              selectedDeal.assignee?.name || $t('CRM.DEALS.UNASSIGNED')
            }}</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">{{ $t('CRM.DEALS.CREATED') }}</span>
            <span class="detail-value">{{
              formatDate(selectedDeal.created_at)
            }}</span>
          </div>
        </div>

        <div v-if="selectedDeal.status === 'open'" class="deal-actions">
          <woot-button
            color-scheme="success"
            size="small"
            icon="checkmark-circle"
            @click="markAsWon(selectedDeal)"
          >
            {{ $t('CRM.DEALS.MARK_WON') }}
          </woot-button>
          <woot-button
            color-scheme="alert"
            variant="smooth"
            size="small"
            icon="dismiss-circle"
            @click="markAsLost(selectedDeal)"
          >
            {{ $t('CRM.DEALS.MARK_LOST') }}
          </woot-button>
        </div>

        <div class="modal-footer">
          <woot-button variant="smooth" size="small" @click="goToKanban">
            {{ $t('CRM.DEALS.SIDEBAR.VIEW_IN_KANBAN') }}
          </woot-button>
          <woot-button variant="clear" @click="closeDetailsModal">
            {{ $t('CRM.CANCEL') }}
          </woot-button>
        </div>
      </div>
    </woot-modal>
  </div>
</template>

<script>
import { mapGetters, mapActions } from 'vuex';
import Spinner from 'shared/components/Spinner.vue';
import DealsAPI from 'dashboard/api/deals';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';

export default {
  name: 'ContactDeals',
  components: {
    Spinner,
  },
  props: {
    contactId: {
      type: [Number, String],
      required: true,
    },
    conversationId: {
      type: [Number, String],
      default: null,
    },
  },
  data() {
    return {
      deals: [],
      isLoading: false,
      showCreateModal: false,
      showDetailsModal: false,
      selectedDeal: null,
      selectedPipelineId: null,
      isCreating: false,
      newDeal: {
        title: '',
        value: null,
        currency: 'BRL',
        stage_id: null,
        assignee_id: null,
      },
    };
  },
  computed: {
    ...mapGetters({
      pipelines: 'pipelines/getPipelines',
      agents: 'agents/getAgents',
      currentUser: 'getCurrentUser',
    }),
    currentStages() {
      const pipeline = this.pipelines.find(
        p => p.id === this.selectedPipelineId
      );
      return pipeline?.stages || [];
    },
  },
  watch: {
    contactId: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          this.fetchDeals();
        }
      },
    },
  },
  mounted() {
    this.fetchPipelines();
    this.fetchAgents();
  },
  methods: {
    ...mapActions({
      fetchPipelines: 'pipelines/get',
      fetchAgents: 'agents/get',
      createDealAction: 'deals/create',
      winDeal: 'deals/win',
      loseDeal: 'deals/lose',
    }),
    async fetchDeals() {
      this.isLoading = true;
      try {
        const response = await DealsAPI.get({ contactId: this.contactId });
        this.deals = response.data.payload || response.data;
      } catch (error) {
        console.error('Error fetching deals:', error);
      } finally {
        this.isLoading = false;
      }
    },
    openCreateDealModal() {
      this.newDeal = {
        title: '',
        value: null,
        currency: 'BRL',
        stage_id: null,
        assignee_id: this.currentUser?.id,
      };

      // Set default pipeline
      const defaultPipeline =
        this.pipelines.find(p => p.is_default) || this.pipelines[0];
      if (defaultPipeline) {
        this.selectedPipelineId = defaultPipeline.id;
        this.newDeal.stage_id = defaultPipeline.stages?.[0]?.id;
      }

      this.showCreateModal = true;
    },
    closeCreateModal() {
      this.showCreateModal = false;
    },
    onPipelineChange() {
      const pipeline = this.pipelines.find(
        p => p.id === this.selectedPipelineId
      );
      this.newDeal.stage_id = pipeline?.stages?.[0]?.id || null;
    },
    async createDeal() {
      this.isCreating = true;
      try {
        const dealData = {
          ...this.newDeal,
          contact_id: this.contactId,
          conversation_id: this.conversationId,
        };

        await this.createDealAction(dealData);
        this.closeCreateModal();
        this.fetchDeals();
        this.$toast.success(this.$t('CRM.DEALS.SIDEBAR.CREATE_SUCCESS'));
      } catch (error) {
        this.$toast.error(error.message || this.$t('CRM.DEALS.FORM.ERROR'));
      } finally {
        this.isCreating = false;
      }
    },
    openDealDetails(deal) {
      this.selectedDeal = deal;
      this.showDetailsModal = true;
    },
    closeDetailsModal() {
      this.showDetailsModal = false;
      this.selectedDeal = null;
    },
    async markAsWon(deal) {
      try {
        await this.winDeal(deal.id);
        this.fetchDeals();
        this.closeDetailsModal();
        this.$toast.success(this.$t('CRM.DEALS.WON_SUCCESS'));
      } catch (error) {
        this.$toast.error(this.$t('CRM.DEALS.WON_ERROR'));
      }
    },
    async markAsLost(deal) {
      const reason = prompt(this.$t('CRM.DEALS.LOST_REASON_PLACEHOLDER'));
      if (reason) {
        try {
          await this.loseDeal({ id: deal.id, lostReason: reason });
          this.fetchDeals();
          this.closeDetailsModal();
          this.$toast.success(this.$t('CRM.DEALS.LOST_SUCCESS'));
        } catch (error) {
          this.$toast.error(this.$t('CRM.DEALS.LOST_ERROR'));
        }
      }
    },
    goToKanban() {
      this.closeDetailsModal();
      this.$router.push({
        name: 'deals_kanban',
        params: {
          accountId: this.$route.params.accountId,
          pipelineId:
            this.selectedDeal.pipeline?.id || this.selectedDeal.pipeline_id,
        },
      });
    },
    formatCurrency(value) {
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL',
      }).format(value || 0);
    },
    formatDate(date) {
      if (!date) return '-';
      return format(new Date(date), 'dd/MM/yyyy', { locale: ptBR });
    },
  },
};
</script>

<style lang="scss" scoped>
.contact-deals {
  padding: var(--space-small);
}

.loading-state,
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--space-normal);
  color: var(--color-body);
  text-align: center;
  gap: var(--space-small);
}

.empty-state p {
  margin: 0;
  font-size: var(--font-size-small);
}

.deals-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-smaller);
}

.deal-item {
  background: var(--white);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-small);
  padding: var(--space-small);
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    border-color: var(--w-500);
    background: var(--s-25);
  }

  &.is-won {
    border-left: 3px solid var(--g-500);
  }

  &.is-lost {
    border-left: 3px solid var(--r-500);
    opacity: 0.7;
  }

  &.is-rotting {
    border-left: 3px solid var(--y-500);
  }
}

.deal-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: var(--space-micro);
}

.deal-title {
  font-size: var(--font-size-small);
  font-weight: var(--font-weight-medium);
  color: var(--color-heading);
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.deal-value {
  font-size: var(--font-size-mini);
  font-weight: var(--font-weight-bold);
  color: var(--g-600);
  white-space: nowrap;
  margin-left: var(--space-smaller);
}

.deal-meta {
  display: flex;
  gap: var(--space-small);
  font-size: var(--font-size-micro);
  color: var(--color-body);
}

.deal-stage,
.deal-status {
  display: flex;
  align-items: center;
  gap: var(--space-micro);
}

.add-deal-btn {
  margin-top: var(--space-smaller);
}

.create-deal-modal,
.deal-details-modal {
  padding: var(--space-normal);
  min-width: 400px;
}

.form-field {
  margin-bottom: var(--space-normal);

  label {
    display: block;
    margin-bottom: var(--space-smaller);
    font-weight: var(--font-weight-medium);
    font-size: var(--font-size-small);
  }

  input,
  select {
    width: 100%;
    padding: var(--space-small);
    border: 1px solid var(--color-border);
    border-radius: var(--border-radius-small);
    font-size: var(--font-size-small);

    &:focus {
      border-color: var(--w-500);
      outline: none;
    }
  }
}

.form-row {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: var(--space-small);
}

.deal-details-content {
  margin-bottom: var(--space-normal);
}

.detail-row {
  display: flex;
  justify-content: space-between;
  padding: var(--space-smaller) 0;
  border-bottom: 1px solid var(--color-border);

  &:last-child {
    border-bottom: none;
  }
}

.detail-label {
  font-size: var(--font-size-small);
  color: var(--color-body);
}

.detail-value {
  font-size: var(--font-size-small);
  color: var(--color-heading);
  font-weight: var(--font-weight-medium);

  &.highlight {
    color: var(--g-600);
    font-size: var(--font-size-medium);
    font-weight: var(--font-weight-bold);
  }
}

.deal-actions {
  display: flex;
  gap: var(--space-small);
  margin-bottom: var(--space-normal);
  padding-top: var(--space-small);
  border-top: 1px solid var(--color-border);
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-small);
  padding-top: var(--space-normal);
  border-top: 1px solid var(--color-border);
}
</style>
