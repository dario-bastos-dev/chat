<template>
  <div>
    <div class="px-4 pt-3 pb-2">
      <NextButton
        ghost
        xs
        icon="i-lucide-plus"
        :label="$t('CRM.DEALS.SIDEBAR.ADD')"
        :disabled="!contactId || isLoading"
        @click="openCreateDealModal"
      />
    </div>

    <div
      v-if="isLoading"
      class="flex items-center justify-center py-8 text-n-slate-11"
    >
      <Spinner />
    </div>

    <div
      v-else-if="deals.length"
      class="flex flex-col overflow-y-auto max-h-[300px]"
    >
      <button
        v-for="deal in deals"
        :key="deal.id"
        class="flex flex-col w-full gap-1.5 px-4 py-3 text-left transition-colors duration-150 border-b border-n-weak last:border-b-0 hover:bg-n-alpha-1"
        @click="openDealDetails(deal)"
      >
        <div class="flex items-start justify-between w-full gap-2">
          <span
            class="flex-1 min-w-0 text-sm font-medium truncate text-n-slate-12"
          >
            {{ deal.title }}
          </span>
          <span class="text-xs shrink-0 text-n-slate-10">
            {{ formatDateCompact(deal.updated_at || deal.created_at) }}
          </span>
        </div>

        <div class="flex items-center justify-between w-full gap-2">
          <span class="flex items-center min-w-0 gap-1 text-xs text-n-slate-11">
            <span class="size-3 shrink-0 i-lucide-git-branch text-n-slate-10" />
            <span class="truncate">
              {{ deal.stage?.name || deal.pipeline?.name }}
            </span>
          </span>

          <span
            v-if="deal.status !== 'open'"
            class="px-1.5 py-0.5 text-xs font-medium leading-none rounded-md shrink-0"
            :class="
              deal.status === 'won'
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-ruby-3 text-n-ruby-11'
            "
          >
            {{
              deal.status === 'won'
                ? $t('CRM.DEALS.STATUS_WON')
                : $t('CRM.DEALS.STATUS_LOST')
            }}
          </span>
        </div>
      </button>
    </div>

    <p v-else class="px-6 py-6 text-sm leading-6 text-center text-n-slate-11">
      {{ $t('CRM.DEALS.SIDEBAR.EMPTY') }}
    </p>

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
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DealDrawer from 'dashboard/routes/dashboard/deals/components/DealDrawer.vue';
import DealsAPI from 'dashboard/api/deals';
import { formatDistanceToNow } from 'date-fns';
import { ptBR } from 'date-fns/locale';

export default {
  name: 'ContactDeals',
  components: {
    Spinner,
    NextButton,
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
      isCreating: false,
      showStageDropdown: false,
      showAssigneeDropdown: false,
      expandedPipelineId: null,
      newDeal: {
        title: '',
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
        stage_id: null,
        assignee_id: this.currentUser?.id,
      };
      this.showStageDropdown = false;

      // Set default pipeline
      const defaultPipeline =
        this.pipelines.find(p => p.is_default) || this.pipelines[0];
      if (defaultPipeline) {
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
    formatDateCompact(date) {
      if (!date) return '';
      return formatDistanceToNow(new Date(date), {
        addSuffix: false,
        locale: ptBR,
      }).replace('cerca de ', '')
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
        .trim();
    },
  },
};
</script>

<style lang="scss" scoped>
.create-deal-modal {
  min-width: 400px;
}

:deep(.modal-container),
.create-deal-modal,
.create-deal-modal form {
  overflow: visible !important;
}
</style>
