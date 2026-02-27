<template>
  <div class="contact-deals-section">
    <div class="section-header">
      <h4 class="section-title">
        <span class="i-ph-handshake size-5" />
        {{ $t('CRM.DEALS.TITLE') }}
      </h4>
      <woot-button
        variant="smooth"
        size="tiny"
        icon="add"
        @click="openCreateDealModal"
      >
        {{ $t('CRM.DEALS.CREATE') }}
      </woot-button>
    </div>

    <div v-if="isLoading" class="loading-section">
      <spinner size="small" />
    </div>

    <div v-else-if="deals.length === 0" class="empty-section">
      <div class="empty-icon">
        <span class="i-ph-chart-pie-slice size-12 text-n-slate-8" />
      </div>
      <p class="empty-text">{{ $t('CRM.DEALS.SIDEBAR.EMPTY') }}</p>
    </div>

    <div v-else class="deals-grid">
      <div
        v-for="deal in deals"
        :key="deal.id"
        class="deal-card"
        :class="getStatusClass(deal)"
        @click="goToDealDetails(deal)"
      >
        <div class="deal-card-header">
          <h5 class="deal-title">{{ deal.title }}</h5>
          <span
            v-if="deal.status !== 'open'"
            class="deal-badge"
            :class="deal.status"
          >
            {{
              deal.status === 'won'
                ? $t('CRM.DEALS.STATUS_WON')
                : $t('CRM.DEALS.STATUS_LOST')
            }}
          </span>
        </div>
        <div class="deal-value">
          {{ formatCurrency(deal.value, deal.currency) }}
        </div>
        <div class="deal-meta">
          <span class="meta-item">
            <span class="i-ph-funnel size-3" />
            {{ deal.pipeline?.name }}
          </span>
          <span class="meta-item">
            <span class="i-ph-git-branch size-3" />
            {{ deal.stage?.name }}
          </span>
        </div>
        <div v-if="deal.assignee" class="deal-assignee">
          <Avatar
            :src="deal.assignee.thumbnail"
            :name="deal.assignee.name"
            :size="20"
          />
          <span class="assignee-name">{{ deal.assignee.name }}</span>
        </div>
        <div v-if="deal.expected_close_date" class="deal-close-date">
          <span class="i-ph-calendar size-3" />
          {{ formatDate(deal.expected_close_date) }}
        </div>
      </div>
    </div>

    <!-- Create Deal Modal -->
    <woot-modal v-model:show="showCreateModal" :on-close="closeCreateModal">
      <div class="create-deal-modal-content">
        <woot-modal-header :header-title="$t('CRM.DEALS.CREATE')" />
        <form class="modal-form" @submit.prevent="createDeal">
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
            <div class="form-field currency-field">
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
            <label>{{ $t('CRM.DEALS.FORM.EXPECTED_CLOSE') }}</label>
            <input v-model="newDeal.expected_close_date" type="date" />
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

          <div class="modal-actions">
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
  </div>
</template>

<script>
import { mapGetters, mapActions } from 'vuex';
import Spinner from 'shared/components/Spinner.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import DealsAPI from 'dashboard/api/deals';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';

export default {
  name: 'ContactDealsSection',
  components: {
    Spinner,
    Avatar,
  },
  props: {
    contactId: {
      type: [Number, String],
      required: true,
    },
  },
  data() {
    return {
      deals: [],
      isLoading: false,
      showCreateModal: false,
      isCreating: false,
      selectedPipelineId: null,
      newDeal: {
        title: '',
        value: null,
        currency: 'BRL',
        stage_id: null,
        assignee_id: null,
        expected_close_date: null,
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
    }),
    async fetchDeals() {
      this.isLoading = true;
      try {
        const response = await DealsAPI.get({ contactId: this.contactId });
        this.deals = response.data.payload || response.data || [];
      } catch (error) {
        console.error('Error fetching deals:', error);
        this.deals = [];
      } finally {
        this.isLoading = false;
      }
    },
    getStatusClass(deal) {
      const classes = [];
      if (deal.status === 'won') classes.push('is-won');
      if (deal.status === 'lost') classes.push('is-lost');
      if (deal.is_rotting) classes.push('is-rotting');
      return classes;
    },
    openCreateDealModal() {
      this.newDeal = {
        title: '',
        value: null,
        currency: 'BRL',
        stage_id: null,
        assignee_id: this.currentUser?.id,
        expected_close_date: null,
      };

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
    goToDealDetails(deal) {
      this.$router.push({
        name: 'deals_kanban',
        params: {
          accountId: this.$route.params.accountId,
          pipelineId: deal.pipeline?.id || deal.pipeline_id,
        },
      });
    },
    formatCurrency(value, currency = 'BRL') {
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: currency,
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
.contact-deals-section {
  padding: var(--space-normal);
  border-top: 1px solid var(--color-border);
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--space-normal);
}

.section-title {
  display: flex;
  align-items: center;
  gap: var(--space-smaller);
  font-size: var(--font-size-default);
  font-weight: var(--font-weight-medium);
  color: var(--color-heading);
  margin: 0;
}

.loading-section,
.empty-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--space-large);
  text-align: center;
}

.empty-icon {
  margin-bottom: var(--space-small);
  opacity: 0.5;
}

.empty-text {
  font-size: var(--font-size-small);
  color: var(--color-body);
  margin: 0;
}

.deals-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: var(--space-normal);
}

.deal-card {
  background: var(--white);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-medium);
  padding: var(--space-slab);
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    border-color: var(--w-500);
    box-shadow: var(--shadow-small);
  }

  &.is-won {
    border-left: 4px solid var(--g-500);
    background: var(--g-25);
  }

  &.is-lost {
    border-left: 4px solid var(--r-500);
    opacity: 0.7;
  }

  &.is-rotting {
    border-left: 4px solid var(--y-500);
  }
}

.deal-card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: var(--space-smaller);
}

.deal-title {
  font-size: var(--font-size-small);
  font-weight: var(--font-weight-medium);
  color: var(--color-heading);
  margin: 0;
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.deal-badge {
  font-size: var(--font-size-micro);
  padding: 2px 6px;
  border-radius: var(--border-radius-small);
  font-weight: var(--font-weight-medium);

  &.won {
    background: var(--g-100);
    color: var(--g-700);
  }

  &.lost {
    background: var(--r-100);
    color: var(--r-700);
  }
}

.deal-value {
  font-size: var(--font-size-medium);
  font-weight: var(--font-weight-bold);
  color: var(--g-600);
  margin-bottom: var(--space-smaller);
}

.deal-meta {
  display: flex;
  gap: var(--space-small);
  flex-wrap: wrap;
  margin-bottom: var(--space-smaller);
}

.meta-item {
  display: flex;
  align-items: center;
  gap: var(--space-micro);
  font-size: var(--font-size-mini);
  color: var(--color-body);
}

.deal-assignee {
  display: flex;
  align-items: center;
  gap: var(--space-smaller);
  margin-top: var(--space-smaller);
}

.assignee-name {
  font-size: var(--font-size-mini);
  color: var(--color-body);
}

.deal-close-date {
  display: flex;
  align-items: center;
  gap: var(--space-micro);
  font-size: var(--font-size-micro);
  color: var(--color-body);
  margin-top: var(--space-smaller);
}

.create-deal-modal-content {
  padding: var(--space-normal);
  min-width: 450px;
}

.modal-form {
  display: flex;
  flex-direction: column;
  gap: var(--space-normal);
}

.form-field {
  display: flex;
  flex-direction: column;
  gap: var(--space-smaller);

  label {
    font-weight: var(--font-weight-medium);
    font-size: var(--font-size-small);
    color: var(--color-heading);
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

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-small);
  padding-top: var(--space-normal);
  border-top: 1px solid var(--color-border);
}
</style>
