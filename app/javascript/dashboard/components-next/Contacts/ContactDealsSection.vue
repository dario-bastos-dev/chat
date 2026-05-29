<template>
  <div class="flex flex-col w-full h-full">
    <!-- Header elegante: Título e Botão de Criar -->
    <div class="flex items-center justify-between px-6 py-4 border-b border-n-strong">
      <h4 class="flex items-center gap-1.5 text-sm font-semibold text-n-slate-12 m-0">
        <span class="i-ph-handshake size-5 text-n-slate-10" />
        {{ $t('CRM.DEALS.TITLE') }}
      </h4>
      <woot-button
        variant="smooth"
        size="tiny"
        icon="add"
        class="!py-1 !px-2.5"
        @click="openCreateDealModal"
      >
        {{ $t('CRM.DEALS.CREATE') }}
      </woot-button>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="flex items-center justify-center py-10 text-n-slate-11">
      <spinner size="small" />
    </div>

    <!-- Listagem de Negócios (semelhante ao histórico de conversas) -->
    <div
      v-else-if="deals.length > 0"
      class="px-6 py-4 divide-y divide-n-strong [&>*:hover]:!border-y-transparent [&>*:hover+*]:!border-t-transparent"
    >
      <div
        v-for="deal in deals"
        :key="deal.id"
        class="flex flex-col gap-2 p-4 cursor-pointer transition-all duration-200 rounded-none hover:rounded-xl hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3"
        @click="goToDealDetails(deal)"
      >
        <!-- Linha superior: Título e Status -->
        <div class="flex items-start justify-between w-full gap-2">
          <h5 class="text-sm font-semibold text-n-slate-12 truncate flex-1 m-0">
            {{ deal.title }}
          </h5>
          <span
            v-if="deal.status !== 'open'"
            class="text-[10px] font-semibold px-2 py-0.5 rounded leading-none"
            :class="deal.status === 'won' ? 'bg-g-100 text-g-700 dark:bg-g-900/30 dark:text-g-400' : 'bg-r-100 text-r-700 dark:bg-r-900/30 dark:text-r-400'"
          >
            {{ deal.status === 'won' ? $t('CRM.DEALS.STATUS_WON') : $t('CRM.DEALS.STATUS_LOST') }}
          </span>
        </div>

        <!-- Linha do Meio: Valor -->
        <div class="text-sm font-bold text-g-600 dark:text-g-400">
          {{ formatCurrency(deal.value, deal.currency) }}
        </div>

        <!-- Linha de Metadados: Pipeline & Estágio -->
        <div class="flex flex-wrap items-center gap-3 text-xs text-n-slate-11">
          <span class="inline-flex items-center gap-1">
            <span class="i-ph-funnel text-n-slate-9 size-3.5" />
            {{ deal.pipeline?.name }}
          </span>
          <span class="inline-flex items-center gap-1">
            <span class="i-ph-git-branch text-n-slate-9 size-3.5" />
            {{ deal.stage?.name }}
          </span>
        </div>

        <!-- Responsável e Data se existirem -->
        <div class="flex items-center justify-between w-full mt-1 text-xs text-n-slate-10">
          <div v-if="deal.assignee" class="flex items-center gap-1.5">
            <Avatar
              :src="deal.assignee.thumbnail"
              :name="deal.assignee.name"
              :size="18"
            />
            <span>{{ deal.assignee.name }}</span>
          </div>
          <div v-if="deal.expected_close_date" class="flex items-center gap-1">
            <span class="i-ph-calendar size-3.5" />
            <span>{{ formatDate(deal.expected_close_date) }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Create Deal Modal -->
    <woot-modal v-model:show="showCreateModal" :on-close="closeCreateModal">
      <div class="p-6 min-w-[28.125rem]">
        <woot-modal-header :header-title="$t('CRM.DEALS.CREATE')" />
        <form class="flex flex-col gap-4 mt-4" @submit.prevent="createDeal">
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-medium text-n-slate-12">{{ $t('CRM.DEALS.FORM.TITLE') }} *</label>
            <input
              v-model="newDeal.title"
              type="text"
              class="w-full p-2.5 border border-n-strong rounded bg-n-surface-2 text-n-slate-12 focus:border-w-500 focus:outline-none text-sm"
              :placeholder="$t('CRM.DEALS.FORM.TITLE_PLACEHOLDER')"
              required
            />
          </div>

          <div class="grid grid-cols-3 gap-3">
            <div class="flex flex-col col-span-2 gap-1.5">
              <label class="text-sm font-medium text-n-slate-12">{{ $t('CRM.DEALS.FORM.VALUE') }}</label>
              <input
                v-model.number="newDeal.value"
                type="number"
                step="0.01"
                min="0"
                class="w-full p-2.5 border border-n-strong rounded bg-n-surface-2 text-n-slate-12 focus:border-w-500 focus:outline-none text-sm"
                :placeholder="$t('CRM.DEALS.FORM.VALUE_PLACEHOLDER')"
              />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-medium text-n-slate-12">{{ $t('CRM.DEALS.FORM.CURRENCY') }}</label>
              <select
                v-model="newDeal.currency"
                class="w-full p-2.5 border border-n-strong rounded bg-n-surface-2 text-n-slate-12 focus:border-w-500 focus:outline-none text-sm"
              >
                <option value="BRL">BRL</option>
                <option value="USD">USD</option>
                <option value="EUR">EUR</option>
              </select>
            </div>
          </div>

          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-medium text-n-slate-12">{{ $t('CRM.DEALS.FORM.PIPELINE') }} *</label>
            <select
              v-model="selectedPipelineId"
              class="w-full p-2.5 border border-n-strong rounded bg-n-surface-2 text-n-slate-12 focus:border-w-500 focus:outline-none text-sm"
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

          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-medium text-n-slate-12">{{ $t('CRM.DEALS.FORM.STAGE') }} *</label>
            <select
              v-model="newDeal.stage_id"
              class="w-full p-2.5 border border-n-strong rounded bg-n-surface-2 text-n-slate-12 focus:border-w-500 focus:outline-none text-sm"
              required
            >
              <option
                v-for="stage in currentStages"
                :key="stage.id"
                :value="stage.id"
              >
                {{ stage.name }}
              </option>
            </select>
          </div>

          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-medium text-n-slate-12">{{ $t('CRM.DEALS.FORM.EXPECTED_CLOSE') }}</label>
            <input
              v-model="newDeal.expected_close_date"
              type="date"
              class="w-full p-2.5 border border-n-strong rounded bg-n-surface-2 text-n-slate-12 focus:border-w-500 focus:outline-none text-sm"
            />
          </div>

          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-medium text-n-slate-12">{{ $t('CRM.DEALS.FORM.ASSIGNEE') }}</label>
            <select
              v-model="newDeal.assignee_id"
              class="w-full p-2.5 border border-n-strong rounded bg-n-surface-2 text-n-slate-12 focus:border-w-500 focus:outline-none text-sm"
            >
              <option :value="null">
                {{ $t('CRM.DEALS.FORM.UNASSIGNED') }}
              </option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name }}
              </option>
            </select>
          </div>

          <div class="flex justify-end gap-3.5 pt-4 border-t border-n-strong">
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
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
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
