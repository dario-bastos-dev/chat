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

    <div v-else class="flex flex-col gap-2">
      <div class="flex flex-col border border-n-weak rounded-lg bg-n-solid-2 overflow-hidden [&>.deal-card:last-child]:border-b-0">
        <div
          v-for="deal in deals"
          :key="deal.id"
          class="deal-card p-3 border-b border-n-weak/30 hover:bg-n-alpha-1 cursor-pointer transition-all duration-150 flex flex-col gap-1 relative"
          :class="{
            'border-l-2 !border-l-n-green-9': deal.status === 'won',
            'border-l-2 !border-l-n-ruby-9': deal.status === 'lost',
          }"
          @click="openDealDetails(deal)"
        >
          <!-- Linha Superior: Nome do Negócio à esquerda, data/hora compacta à direita -->
          <div class="flex items-start justify-between">
            <span class="text-xs font-semibold text-n-slate-12 truncate flex-1 min-w-0 mr-2">
              {{ deal.title }}
            </span>
            <span class="text-[10px] text-n-slate-11 shrink-0">
              {{ formatDateCompact(deal.updated_at || deal.created_at) }}
            </span>
          </div>
          
          <!-- Linha Inferior: Pipeline/Etapa e Status Badge -->
          <div class="flex items-center justify-between text-[11px] text-n-slate-11">
            <span class="flex items-center gap-1 min-w-0">
              <fluent-icon icon="board" size="11" class="shrink-0 text-n-slate-10" />
              <span class="truncate">{{ deal.stage?.name || deal.pipeline?.name }}</span>
            </span>
            
            <!-- Badge Won/Lost se não estiver aberto -->
            <span
              v-if="deal.status !== 'open'"
              class="inline-flex items-center gap-0.5 px-1 py-0.2 rounded text-[8px] font-bold uppercase shrink-0"
              :class="deal.status === 'won' ? 'bg-n-green-3 text-n-green-11' : 'bg-n-red-3 text-n-red-11'"
            >
              {{ deal.status === 'won' ? 'Ganho' : 'Perdido' }}
            </span>
          </div>
        </div>
      </div>

      <button
        class="mt-1 flex items-center justify-center gap-1.5 w-full py-2 text-xs font-semibold text-n-slate-11 hover:text-n-brand bg-n-alpha-1 hover:bg-n-alpha-2 border border-n-weak hover:border-n-brand rounded-lg transition-all duration-150 cursor-pointer shadow-sm"
        @click="openCreateDealModal"
      >
        <fluent-icon icon="add" size="12" />
        {{ $t('CRM.DEALS.SIDEBAR.ADD') }}
      </button>
    </div>

    <!-- Create Deal Modal -->
    <woot-modal v-model:show="showCreateModal" :on-close="closeCreateModal">
      <div class="create-deal-modal bg-n-surface-2 p-6 rounded-2xl border border-n-weak shadow-2xl">
        <woot-modal-header :header-title="$t('CRM.DEALS.CREATE')" />
        <form @submit.prevent="createDeal">
          <!-- Container de campos com espaçamento perfeito de space-y-5 e overflow visible para acomodar os dropdowns suspensos por cima -->
          <div class="space-y-5 pr-1">
            <!-- Título -->
            <div class="flex flex-col gap-1.5">
              <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.DEALS.FORM.TITLE') }} *</label>
              <input
                v-model="newDeal.title"
                type="text"
                class="w-full text-xs md:text-sm text-n-slate-12 bg-n-alpha-1 hover:bg-n-alpha-2 focus:bg-n-alpha-2 border border-n-weak focus:border-n-brand rounded-xl h-10 px-3 transition-all duration-150 outline-none placeholder:text-n-slate-9 focus:ring-2 focus:ring-n-brand/20"
                :placeholder="$t('CRM.DEALS.FORM.TITLE_PLACEHOLDER')"
                required
              />
            </div>

            <!-- Etapa -->
            <div class="flex flex-col gap-1.5 relative" ref="stageSelectorContainer">
              <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.DEALS.FORM.STAGE') }} *</label>
              <div class="relative w-full">
                <button
                  type="button"
                  class="flex items-center justify-between w-full text-left text-xs md:text-sm font-medium text-n-slate-12 hover:text-n-brand px-3 py-2 bg-n-alpha-1 hover:bg-n-alpha-2 border border-n-weak hover:border-n-brand rounded-xl transition-all duration-150 cursor-pointer h-10"
                  @click="toggleStageDropdown"
                >
                  <span class="truncate">{{ selectedStageName }}</span>
                  <fluent-icon
                    icon="chevron-down"
                    size="14"
                    class="transition-transform duration-200 text-n-slate-11 shrink-0 ml-2"
                    :class="{ 'rotate-180': showStageDropdown }"
                  />
                </button>

                <!-- Dropdown Menu de Pipelines e Etapas -->
                <div
                  v-if="showStageDropdown"
                  class="absolute left-0 top-full mt-1.5 z-[100] w-64 max-h-[26rem] overflow-y-auto bg-n-solid-3 border border-n-weak rounded-xl shadow-xl p-2 flex flex-col gap-1.5 text-left"
                  style="background-color: var(--bg-n-solid-3, #1c1d1f);"
                >
                  <div
                    v-for="pipeline in pipelines"
                    :key="pipeline.id"
                    class="flex flex-col border border-n-weak/50 rounded-lg overflow-hidden bg-n-solid-2"
                  >
                    <!-- Nome do Pipeline (Acordeão Header) -->
                    <button
                      type="button"
                      class="flex items-center justify-between w-full px-3 py-2 text-xs font-bold uppercase tracking-wider bg-n-solid-2 text-n-slate-11 hover:text-n-brand transition-colors cursor-pointer border-0"
                      @click="togglePipelineStages(pipeline.id)"
                    >
                      <span class="truncate">{{ pipeline.name }}</span>
                      <fluent-icon
                        icon="chevron-down"
                        size="12"
                        class="transition-transform duration-200 text-n-slate-10 shrink-0 ml-2"
                        :class="{ 'rotate-180': expandedPipelineId === pipeline.id }"
                      />
                    </button>

                    <!-- Lista de Etapas (Acordeão Content) -->
                    <div
                      v-show="expandedPipelineId === pipeline.id"
                      class="flex flex-col gap-[5px] p-[5px] pb-[10px] bg-n-surface-1"
                    >
                      <button
                        type="button"
                        v-for="stage in pipeline.stages"
                        :key="stage.id"
                        class="flex items-center justify-between w-full px-3.5 py-2 text-xs text-left transition-all duration-150 cursor-pointer border-l-4 hover:brightness-95 active:brightness-90 text-n-slate-12 font-medium rounded-md border-0"
                        :style="{
                          backgroundColor: stage.color ? `${stage.color}15` : '#1f93ff15',
                          borderLeftColor: stage.color || '#1f93ff'
                        }"
                        @click="selectStageForNewDeal(stage.id)"
                      >
                        <span :class="{ 'font-semibold text-n-brand': newDeal.stage_id === stage.id }">
                          {{ stage.name }}
                        </span>
                        <span
                          v-if="newDeal.stage_id === stage.id"
                          class="text-n-brand flex shrink-0"
                        >
                          <fluent-icon icon="checkmark" size="12" />
                        </span>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Responsável -->
            <div class="flex flex-col gap-1.5 relative" ref="assigneeSelectorContainer">
              <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.DEALS.FORM.ASSIGNEE') }}</label>
              <div class="relative w-full">
                <button
                  type="button"
                  class="flex items-center justify-between w-full text-left text-xs md:text-sm font-medium text-n-slate-12 hover:text-n-brand px-3 py-2 bg-n-alpha-1 hover:bg-n-alpha-2 border border-n-weak hover:border-n-brand rounded-xl transition-all duration-150 cursor-pointer h-10"
                  @click="toggleAssigneeDropdown"
                >
                  <span class="truncate">{{ selectedAssigneeName }}</span>
                  <fluent-icon
                    icon="chevron-down"
                    size="14"
                    class="transition-transform duration-200 text-n-slate-11 shrink-0 ml-2"
                    :class="{ 'rotate-180': showAssigneeDropdown }"
                  />
                </button>

                <!-- Dropdown Menu de Responsáveis -->
                <div
                  v-if="showAssigneeDropdown"
                  class="absolute left-0 top-full mt-1.5 z-[100] w-64 max-h-48 overflow-y-auto bg-n-solid-3 border border-n-weak rounded-xl shadow-xl p-1.5 flex flex-col gap-0.5 text-left"
                  style="background-color: var(--bg-n-solid-3, #1c1d1f);"
                >
                  <button
                    type="button"
                    class="flex items-center gap-2.5 w-full px-3 py-2 text-xs font-medium text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-1 rounded-lg transition-colors cursor-pointer border-0 bg-transparent"
                    @click="selectAssigneeForNewDeal(null)"
                  >
                    <div class="w-5 h-5 rounded-full border border-dashed border-n-weak bg-n-alpha-1 flex items-center justify-center text-n-slate-10 shrink-0">
                      <fluent-icon icon="person-delete" size="10" />
                    </div>
                    <span>Não atribuído</span>
                  </button>
                  <div class="h-[1px] bg-n-weak/30 my-1" />

                  <button
                    type="button"
                    v-for="agent in agents"
                    :key="agent.id"
                    class="flex items-center justify-between w-full px-3 py-2 text-xs text-left transition-all duration-150 cursor-pointer hover:bg-n-alpha-1 rounded-lg border-0 bg-transparent text-n-slate-12 font-medium"
                    @click="selectAssigneeForNewDeal(agent.id)"
                  >
                    <div class="flex items-center gap-2.5 min-w-0">
                      <Avatar
                        :src="agent.avatar_url"
                        :name="agent.name"
                        :size="20"
                        class="shrink-0"
                      />
                      <span class="truncate" :class="{ 'font-semibold text-n-brand': newDeal.assignee_id === agent.id }">
                        {{ agent.name }}
                      </span>
                    </div>
                    <span
                      v-if="newDeal.assignee_id === agent.id"
                      class="text-n-brand flex shrink-0 ml-2"
                    >
                      <fluent-icon icon="checkmark" size="12" />
                    </span>
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- Footer -->
          <div class="flex justify-end gap-3 mt-6 pt-5 border-t border-n-weak">
            <button
              type="button"
              class="px-4.5 py-2 text-xs font-semibold rounded-xl border border-n-weak bg-n-alpha-1 text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 active:bg-n-alpha-3 transition-all duration-150 cursor-pointer shadow-sm"
              @click.prevent="closeCreateModal"
            >
              {{ $t('CRM.CANCEL') }}
            </button>
            <button
              type="submit"
              class="px-5.5 py-2 text-xs font-semibold rounded-xl text-white bg-n-brand hover:brightness-110 active:brightness-95 transition-all duration-150 cursor-pointer shadow-md border-0 flex items-center justify-center gap-1.5 disabled:opacity-50"
              :disabled="isCreating"
            >
              <woot-spinner v-if="isCreating" size="tiny" class="mr-1" />
              {{ $t('CRM.CREATE') }}
            </button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Deal Details Drawer (gaveta padrão do pipeline) -->
    <deal-drawer
      v-if="selectedDeal"
      :initial-deal="selectedDeal"
      :is-open="showDetailsModal"
      @close="closeDetailsModal"
      @updated="onDealUpdated"
      @deleted="onDealDeleted"
    />
  </div>
</template>

<script>
import { mapGetters, mapActions } from 'vuex';
import Spinner from 'shared/components/Spinner.vue';
import DealDrawer from 'dashboard/routes/dashboard/deals/components/DealDrawer.vue';
import DealsAPI from 'dashboard/api/deals';
import { format, formatDistanceToNow } from 'date-fns';
import { ptBR } from 'date-fns/locale';

export default {
  name: 'ContactDeals',
  components: {
    Spinner,
    DealDrawer,
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
      showStageDropdown: false,
      showAssigneeDropdown: false,
      expandedPipelineId: null,
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
    selectedStageName() {
      if (!this.newDeal.stage_id) return 'Selecionar etapa...';
      for (const pipeline of this.pipelines) {
        const stage = pipeline.stages?.find(s => s.id === this.newDeal.stage_id);
        if (stage) return stage.name;
      }
      return 'Selecionar etapa...';
    },
    selectedAssigneeName() {
      if (!this.newDeal.assignee_id) return 'Não atribuído';
      const agent = this.agents.find(a => a.id === this.newDeal.assignee_id);
      return agent ? agent.name : 'Não atribuído';
    },
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
    document.addEventListener('click', this.handleClickOutside);
  },
  beforeUnmount() {
    document.removeEventListener('click', this.handleClickOutside);
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
        this.deals = response.data.data || response.data.payload || response.data;
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
      this.showStageDropdown = false;

      // Set default pipeline
      const defaultPipeline =
        this.pipelines.find(p => p.is_default) || this.pipelines[0];
      if (defaultPipeline) {
        this.selectedPipelineId = defaultPipeline.id;
        this.newDeal.stage_id = defaultPipeline.stages?.[0]?.id;
        this.expandedPipelineId = defaultPipeline.id;
      }

      this.showCreateModal = true;
    },
    closeCreateModal() {
      this.showCreateModal = false;
      this.showStageDropdown = false;
      this.showAssigneeDropdown = false;
    },
    toggleStageDropdown() {
      this.showStageDropdown = !this.showStageDropdown;
      if (this.showStageDropdown) {
        this.showAssigneeDropdown = false;
      }
    },
    toggleAssigneeDropdown() {
      this.showAssigneeDropdown = !this.showAssigneeDropdown;
      if (this.showAssigneeDropdown) {
        this.showStageDropdown = false;
      }
    },
    togglePipelineStages(pipelineId) {
      if (this.expandedPipelineId === pipelineId) {
        this.expandedPipelineId = null;
      } else {
        this.expandedPipelineId = pipelineId;
      }
    },
    selectStageForNewDeal(stageId) {
      this.newDeal.stage_id = stageId;
      this.showStageDropdown = false;
    },
    selectAssigneeForNewDeal(agentId) {
      this.newDeal.assignee_id = agentId;
      this.showAssigneeDropdown = false;
    },
    handleClickOutside(event) {
      const stageContainer = this.$refs.stageSelectorContainer;
      if (stageContainer && !stageContainer.contains(event.target)) {
        this.showStageDropdown = false;
      }
      const assigneeContainer = this.$refs.assigneeSelectorContainer;
      if (assigneeContainer && !assigneeContainer.contains(event.target)) {
        this.showAssigneeDropdown = false;
      }
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
      setTimeout(() => {
        if (!this.showDetailsModal) {
          this.selectedDeal = null;
        }
      }, 250);
    },
    onDealUpdated() {
      this.fetchDeals();
    },
    onDealDeleted() {
      this.closeDetailsModal();
      this.fetchDeals();
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
    formatDateCompact(date) {
      if (!date) return '';
      return formatDistanceToNow(new Date(date), {
        addSuffix: false,
        locale: ptBR,
      }).replace('cerca de ', '')
        .replace('há ', '')
        .replace('atrás', '')
        .replace('segundos', 'seg')
        .replace('minutos', 'min')
        .replace('minuto', 'min')
        .replace('horas', 'h')
        .replace('hora', 'h')
        .replace('dias', 'd')
        .replace('dia', 'd')
        .replace('meses', 'mes')
        .replace('mês', 'mes')
        .replace('anos', 'ano')
        .replace('ano', 'ano')
        .trim();
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

:deep(.modal-container),
.create-deal-modal,
.create-deal-modal form {
  overflow: visible !important;
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
