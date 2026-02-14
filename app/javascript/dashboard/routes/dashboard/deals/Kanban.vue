<template>
  <div class="kanban-page">
    <div class="kanban-header">
      <div class="header-left">
        <woot-button variant="clear" icon="arrow-left" @click="goBack" />
        <h1 class="pipeline-title">
          {{ currentPipeline?.name || $t('CRM.LOADING') }}
        </h1>
      </div>
      <div class="header-actions">
        <woot-button
          color-scheme="success"
          icon="add"
          @click="openCreateDealModal"
        >
          {{ $t('CRM.DEALS.CREATE') }}
        </woot-button>
        <woot-button variant="smooth" icon="settings" @click="openSettings">
          {{ $t('CRM.SETTINGS') }}
        </woot-button>
      </div>
    </div>

    <div class="kanban-stats">
      <div class="stat-item">
        <span class="stat-label">{{ $t('CRM.TOTAL_DEALS') }}:</span>
        <span class="stat-value">{{ totalDeals }}</span>
      </div>
      <div class="stat-item">
        <span class="stat-label">{{ $t('CRM.TOTAL_VALUE') }}:</span>
        <span class="stat-value">{{ formatCurrency(totalValue) }}</span>
      </div>
    </div>

    <KanbanSkeleton v-if="isLoading" />

    <div v-else class="kanban-board">
      <div v-for="stage in stages" :key="stage.id" class="kanban-column">
        <div class="column-header">
          <div class="column-header-left">
            <h3 class="column-title">{{ stage.name }}</h3>
            <span class="column-count">{{
              getDealsForStage(stage.id).length
            }}</span>
          </div>
          <div class="column-value">
            {{ formatCurrency(stage.total_value || 0) }}
          </div>
        </div>

        <div class="column-progress">
          <div
            class="progress-bar"
            :style="{ width: `${stage.win_probability || 0}%` }"
          />
        </div>

        <draggable
          :list="getDealsForStage(stage.id)"
          :group="{ name: 'deals' }"
          item-key="id"
          class="column-content"
          ghost-class="deal-ghost"
          @end="onDragEnd($event, stage.id)"
        >
          <template #item="{ element: deal }">
            <div
              class="deal-card"
              :class="{ 'is-rotting': deal.is_rotting }"
              tabindex="0"
              role="button"
              :aria-label="`${deal.title} - ${formatCurrency(deal.value || 0)}`"
              @click="openDealDrawer(deal)"
              @keydown.enter="openDealDrawer(deal)"
              @keydown.space.prevent="openDealDrawer(deal)"
            >
              <div class="deal-header">
                <span class="deal-title">{{ deal.title }}</span>
                <span class="deal-value">{{
                  formatCurrency(deal.value || 0)
                }}</span>
              </div>
              <div class="deal-contact">
                <Avatar
                  :src="deal.contact?.avatar_url"
                  :name="deal.contact?.name"
                  :size="20"
                />
                <span class="contact-name">{{ deal.contact?.name }}</span>
              </div>
              <div class="deal-footer">
                <span v-if="deal.assignee" class="assignee">
                  <Avatar
                    :src="deal.assignee?.avatar_url"
                    :name="deal.assignee?.name"
                    :size="16"
                  />
                </span>
                <span v-if="deal.last_activity_at" class="last-activity">
                  {{ formatDate(deal.last_activity_at) }}
                </span>
              </div>
            </div>
          </template>
        </draggable>

        <button
          class="add-deal-btn"
          :aria-label="$t('CRM.DEALS.ADD_TO_STAGE', { stage: stage.name })"
          @click="openCreateDealModal(stage.id)"
        >
          <fluent-icon icon="add" size="16" />
          {{ $t('CRM.DEALS.ADD') }}
        </button>
      </div>
    </div>

    <!-- Create Deal Modal -->
    <woot-modal
      v-model:show="showCreateDealModal"
      :on-close="closeCreateDealModal"
    >
      <deal-form
        :pipeline="currentPipeline"
        :initial-stage-id="selectedStageId"
        @close="closeCreateDealModal"
        @created="onDealCreated"
      />
    </woot-modal>

    <!-- Deal Drawer -->
    <deal-drawer
      v-if="selectedDeal"
      :deal="selectedDeal"
      :is-open="showDealDrawer"
      @close="closeDealDrawer"
      @updated="onDealUpdated"
      @deleted="onDealDeleted"
    />
  </div>
</template>

<script>
import { mapGetters, mapActions } from 'vuex';
import draggable from 'vuedraggable';
import Spinner from 'shared/components/Spinner.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import DealForm from './components/DealForm.vue';
import DealDrawer from './components/DealDrawer.vue';
import KanbanSkeleton from './components/KanbanSkeleton.vue';
import { formatDistanceToNow } from 'date-fns';
import { ptBR } from 'date-fns/locale';

export default {
  name: 'DealsKanban',
  components: {
    draggable,
    Spinner,
    Thumbnail,
    DealForm,
    DealDrawer,
    KanbanSkeleton,
    Avatar,
  },
  data() {
    return {
      showCreateDealModal: false,
      showDealDrawer: false,
      selectedDeal: null,
      selectedStageId: null,
    };
  },
  computed: {
    ...mapGetters({
      currentPipeline: 'pipelines/getCurrentPipeline',
      pipelineUIFlags: 'pipelines/getUIFlags',
      deals: 'deals/getDeals',
      dealsUIFlags: 'deals/getUIFlags',
    }),
    pipelineId() {
      return Number(this.$route.params.pipelineId);
    },
    stages() {
      return this.currentPipeline?.stages || [];
    },
    isLoading() {
      return this.pipelineUIFlags.isFetching || this.dealsUIFlags.isFetching;
    },
    totalDeals() {
      return this.deals.filter(d => d.status === 'open').length;
    },
    totalValue() {
      return this.deals
        .filter(d => d.status === 'open')
        .reduce((sum, d) => sum + parseFloat(d.value || 0), 0);
    },
  },
  mounted() {
    this.loadData();
  },
  methods: {
    ...mapActions({
      fetchPipeline: 'pipelines/show',
      fetchDeals: 'deals/get',
      moveDeal: 'deals/move',
      setCurrentDeal: 'deals/setCurrentDeal',
    }),
    async loadData() {
      await this.fetchPipeline(this.pipelineId);
      await this.fetchDeals({ pipelineId: this.pipelineId, status: 'open' });
    },
    goBack() {
      this.$router.push({
        name: 'deals_index',
        params: { accountId: this.$route.params.accountId },
      });
    },
    openSettings() {
      this.$router.push({
        name: 'pipelines_settings_index',
        params: { accountId: this.$route.params.accountId },
      });
    },
    getDealsForStage(stageId) {
      return this.deals
        .filter(deal => deal.stage_id === stageId || deal.stage?.id === stageId)
        .sort((a, b) => a.position - b.position);
    },
    async onDragEnd(event, newStageId) {
      const dealId = this.deals[event.oldIndex]?.id;
      if (!dealId) return;

      try {
        await this.moveDeal({
          id: dealId,
          stageId: newStageId,
          position: event.newIndex,
        });
      } catch (error) {
        this.$toast.error(this.$t('CRM.DEALS.MOVE_ERROR'));
        // Recarregar deals em caso de erro
        this.fetchDeals({ pipelineId: this.pipelineId, status: 'open' });
      }
    },
    openCreateDealModal(stageId = null) {
      this.selectedStageId = stageId || this.stages[0]?.id;
      this.showCreateDealModal = true;
    },
    closeCreateDealModal() {
      this.showCreateDealModal = false;
      this.selectedStageId = null;
    },
    onDealCreated(deal) {
      this.closeCreateDealModal();
      this.fetchDeals({ pipelineId: this.pipelineId, status: 'open' });
    },
    openDealDrawer(deal) {
      this.selectedDeal = deal;
      this.showDealDrawer = true;
    },
    closeDealDrawer() {
      this.showDealDrawer = false;
      this.selectedDeal = null;
    },
    onDealUpdated() {
      this.fetchDeals({ pipelineId: this.pipelineId, status: 'open' });
    },
    onDealDeleted() {
      this.closeDealDrawer();
      this.fetchDeals({ pipelineId: this.pipelineId, status: 'open' });
    },
    formatCurrency(value) {
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL',
      }).format(value);
    },
    formatDate(date) {
      return formatDistanceToNow(new Date(date), {
        addSuffix: true,
        locale: ptBR,
      });
    },
  },
};
</script>

<style lang="scss" scoped>
.kanban-page {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: var(--s-25);
}

.kanban-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--space-normal);
  background: var(--white);
  border-bottom: 1px solid var(--color-border);
}

.header-left {
  display: flex;
  align-items: center;
  gap: var(--space-small);
}

.pipeline-title {
  font-size: var(--font-size-large);
  font-weight: var(--font-weight-bold);
  color: var(--color-heading);
  margin: 0;
}

.header-actions {
  display: flex;
  gap: var(--space-small);
}

.kanban-stats {
  display: flex;
  gap: var(--space-large);
  padding: var(--space-small) var(--space-normal);
  background: var(--white);
  border-bottom: 1px solid var(--color-border);
}

.stat-item {
  display: flex;
  gap: var(--space-smaller);
  font-size: var(--font-size-small);
}

.stat-label {
  color: var(--color-body);
}

.stat-value {
  font-weight: var(--font-weight-bold);
  color: var(--color-heading);
}

.loading-state {
  display: flex;
  align-items: center;
  justify-content: center;
  flex: 1;
}

.kanban-board {
  display: flex;
  gap: var(--space-normal);
  padding: var(--space-normal);
  overflow-x: auto;
  flex: 1;
}

.kanban-column {
  min-width: 300px;
  max-width: 300px;
  background: var(--white);
  border-radius: var(--border-radius-medium);
  border: 1px solid var(--color-border);
  display: flex;
  flex-direction: column;
}

.column-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--space-small) var(--space-normal);
  border-bottom: 1px solid var(--color-border);
}

.column-header-left {
  display: flex;
  align-items: center;
  gap: var(--space-smaller);
}

.column-title {
  font-size: var(--font-size-small);
  font-weight: var(--font-weight-medium);
  color: var(--color-heading);
  margin: 0;
}

.column-count {
  background: var(--s-100);
  color: var(--s-700);
  font-size: var(--font-size-mini);
  padding: 2px 6px;
  border-radius: 10px;
}

.column-value {
  font-size: var(--font-size-mini);
  color: var(--color-body);
}

.column-progress {
  height: 3px;
  background: var(--s-100);
}

.progress-bar {
  height: 100%;
  background: linear-gradient(90deg, var(--g-400), var(--g-600));
  transition: width 0.3s ease;
}

.column-content {
  flex: 1;
  padding: var(--space-small);
  overflow-y: auto;
  min-height: 200px;
}

.deal-card {
  background: var(--white);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-small);
  padding: var(--space-small);
  margin-bottom: var(--space-smaller);
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    border-color: var(--w-500);
    box-shadow: var(--shadow-small);
  }

  &.is-rotting {
    border-left: 3px solid var(--r-500);
  }
}

.deal-ghost {
  opacity: 0.5;
  background: var(--w-100);
}

.deal-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: var(--space-smaller);
}

.deal-title {
  font-size: var(--font-size-small);
  font-weight: var(--font-weight-medium);
  color: var(--color-heading);
  flex: 1;
  margin-right: var(--space-smaller);
}

.deal-value {
  font-size: var(--font-size-mini);
  font-weight: var(--font-weight-bold);
  color: var(--g-600);
  white-space: nowrap;
}

.deal-contact {
  display: flex;
  align-items: center;
  gap: var(--space-smaller);
  margin-bottom: var(--space-smaller);
}

.contact-name {
  font-size: var(--font-size-mini);
  color: var(--color-body);
}

.deal-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.last-activity {
  font-size: var(--font-size-micro);
  color: var(--s-500);
}

.add-deal-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-smaller);
  width: 100%;
  padding: var(--space-small);
  border: none;
  background: transparent;
  color: var(--color-body);
  font-size: var(--font-size-small);
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    background: var(--s-50);
    color: var(--w-500);
  }
}
</style>
