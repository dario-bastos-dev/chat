<template>
  <div class="flex flex-col flex-1 h-full">
    <!-- Header -->
    <div
      class="flex items-center justify-between px-4 py-3 border-b border-n-weak bg-n-solid-2 gap-4 shrink-0"
    >
      <div class="flex items-center gap-3 shrink-0">
        <!-- Pipeline selector dropdown -->
        <div class="relative" ref="pipelineDropdown">
          <button
            class="flex items-center gap-1.5 text-lg font-semibold text-n-slate-12 hover:text-n-brand transition-colors duration-150 cursor-pointer"
            @click="togglePipelineDropdown"
          >
            {{ currentPipeline?.name || $t('CRM.LOADING') }}
            <fluent-icon
              icon="chevron-down"
              size="16"
              class="transition-transform duration-200"
              :class="{ 'rotate-180': showPipelineDropdown }"
            />
          </button>
          <div
            v-if="showPipelineDropdown"
            class="absolute left-0 top-full mt-1 z-50 min-w-[220px] bg-n-solid-2 border border-n-weak rounded-lg shadow-lg overflow-hidden"
          >
            <button
              v-for="pipeline in allPipelines"
              :key="pipeline.id"
              class="flex items-center justify-between w-full px-3 py-2.5 text-sm text-left transition-colors duration-150"
              :class="
                pipeline.id === pipelineId
                  ? 'bg-n-brand/10 text-n-brand font-medium'
                  : 'text-n-slate-12 hover:bg-n-alpha-1'
              "
              @click="switchPipeline(pipeline)"
            >
              <span class="truncate">{{ pipeline.name }}</span>
              <span
                v-if="pipeline.is_default"
                class="text-[10px] text-n-amber-11 bg-n-amber-3 px-1.5 py-0.5 rounded-full ml-2 shrink-0"
              >
                {{ $t('CRM.PIPELINES.DEFAULT') }}
              </span>
            </button>
          </div>
        </div>
      </div>

      <!-- Search Input and Filters Toggle in the center -->
      <div class="flex flex-1 items-center gap-3 max-w-xl justify-center">
        <!-- Integrated Search & Filter Dropdown container -->
        <div class="flex flex-1 items-center gap-2 max-w-md w-full" ref="filtersDropdownContainer">
          <!-- Wrapper relative of search input so the dropdown has the exact same width -->
          <div class="relative flex-1 min-w-[240px]">
            <!-- Search bar with icon and text side-by-side -->
            <div class="flex items-center gap-2 bg-n-alpha-1 border border-n-weak rounded-lg px-3 focus-within:border-n-brand focus-within:ring-1 focus-within:ring-n-brand transition-colors duration-150 h-9">
              <fluent-icon icon="search" size="16" class="text-n-slate-11 shrink-0" />
              <input
                v-model="searchQuery"
                type="text"
                placeholder="Pesquisar por nome do lead..."
                class="w-full !py-1 text-sm !bg-transparent !border-0 !border-none !outline-none !focus:outline-none !focus:ring-0 !focus:border-none !focus-visible:outline-none !shadow-none text-n-slate-12 placeholder-n-slate-11 !h-full !p-0 !m-0 no-margin"
              />
            </div>

            <!-- Dropdown logo abaixo, da mesma largura da barra de pesquisa -->
            <transition
              enter-active-class="transition duration-150 ease-out"
              enter-from-class="opacity-0 translate-y-1"
              leave-active-class="transition duration-100 ease-in"
              leave-to-class="opacity-0 translate-y-1"
            >
              <div
                v-if="showFilters"
                class="absolute left-0 right-0 top-full mt-2 z-50 bg-n-solid-2 border border-n-weak rounded-xl shadow-xl p-4 flex flex-col gap-4 text-left"
              >
                <!-- Dropdown Header -->
                <div class="flex items-center justify-between border-b border-n-weak pb-2">
                  <span class="text-xs font-bold text-n-slate-12">Filtros do Kanban</span>
                  <button
                    v-if="activeFilterCount > 0"
                    class="text-[11px] font-semibold text-n-ruby-9 hover:text-n-ruby-10 cursor-pointer"
                    @click="clearAllFilters"
                  >
                    Limpar Filtros
                  </button>
                </div>

                <!-- Filter by Stage -->
                <div class="flex flex-col gap-1.5">
                  <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">Filtrar por Etapa</label>
                  <select
                    v-model="filterStageId"
                    class="w-full px-3 py-1.5 text-xs bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-12 focus:border-n-brand focus:ring-1 focus:ring-n-brand transition-colors duration-150 h-8"
                  >
                    <option :value="null">Todas as Etapas</option>
                    <option v-for="stage in stages" :key="stage.id" :value="stage.id">
                      {{ stage.name }}
                    </option>
                  </select>
                </div>

                <!-- Filter by Tags -->
                <div class="flex flex-col gap-1.5">
                  <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">Filtrar por Tag/Etiqueta</label>
                  <select
                    v-model="filterTag"
                    class="w-full px-3 py-1.5 text-xs bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-12 focus:border-n-brand focus:ring-1 focus:ring-n-brand transition-colors duration-150 h-8"
                  >
                    <option :value="null">Todas as Tags</option>
                    <option v-for="tag in allLabels" :key="tag.id" :value="tag.title">
                      {{ tag.title }}
                    </option>
                  </select>
                </div>

                <!-- Filter by Custom Fields -->
                <div class="flex flex-col gap-1.5" v-if="availableCustomFields.length > 0">
                  <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">Campo Personalizado</label>
                  <div class="flex gap-2">
                    <select
                      v-model="filterCustomFieldKey"
                      class="flex-1 px-3 py-1.5 text-xs bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-12 focus:border-n-brand focus:ring-1 focus:ring-n-brand transition-colors duration-150 h-8"
                      @change="filterCustomFieldValue = ''"
                    >
                      <option :value="null">Nenhum campo</option>
                      <option v-for="field in availableCustomFields" :key="field" :value="field">
                        {{ field }}
                      </option>
                    </select>
                    <input
                      v-if="filterCustomFieldKey"
                      v-model="filterCustomFieldValue"
                      type="text"
                      placeholder="Valor..."
                      class="flex-1 px-3 py-1.5 text-xs bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-12 placeholder-n-slate-11 focus:border-n-brand focus:ring-1 focus:ring-n-brand transition-colors duration-150 h-8"
                    />
                  </div>
                </div>
              </div>
            </transition>
          </div>

          <!-- Botão de filtro do mesmo tamanho da barra de pesquisa (h-9) -->
          <button
            class="flex items-center justify-center px-4 bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-11 hover:text-n-brand cursor-pointer hover:bg-n-alpha-2 transition-colors duration-150 h-9 shrink-0 gap-2 font-medium text-sm"
            :class="{ 'text-n-brand border-n-brand bg-n-brand/10': showFilters }"
            @click="showFilters = !showFilters"
          >
            <fluent-icon icon="filter" size="14" />
            <span>Filtros</span>
            <span v-if="activeFilterCount > 0" class="flex items-center justify-center w-4 h-4 text-[9px] font-bold text-white bg-n-brand rounded-full shrink-0">
              {{ activeFilterCount }}
            </span>
          </button>
        </div>

        <!-- Clear Filters Link (outside input) -->
        <button
          v-if="activeFilterCount > 0 || searchQuery"
          class="flex items-center gap-1 px-2 text-xs font-semibold text-n-ruby-9 hover:text-n-ruby-10 cursor-pointer shrink-0"
          @click="clearAllFilters"
        >
          Limpar
        </button>
      </div>

      <!-- Right side: Create Deal Button -->
      <div class="flex items-center gap-2 shrink-0">
        <button
          class="flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white bg-woot-500 hover:bg-woot-600 active:bg-woot-800 rounded-lg transition-colors duration-200"
          @click="openCreateDealModal"
        >
          <fluent-icon icon="add" size="14" />
          {{ $t('CRM.DEALS.CREATE') }}
        </button>
      </div>
    </div>

    <!-- Stats bar -->
    <div
      class="flex items-center justify-between px-4 py-2 border-b border-n-weak bg-n-solid-2 shrink-0 gap-4"
    >
      <div class="flex items-center gap-6">
        <div class="flex items-center gap-1.5 text-sm">
          <span class="text-n-slate-11">{{ $t('CRM.TOTAL_DEALS') }}:</span>
          <span class="font-semibold text-n-slate-12">{{ totalDeals }}</span>
        </div>
        <div class="flex items-center gap-1.5 text-sm">
          <span class="text-n-slate-11">{{ $t('CRM.TOTAL_VALUE') }}:</span>
          <span class="font-semibold text-n-slate-12">{{
            formatCurrency(totalValue)
          }}</span>
        </div>
      </div>

      <!-- Bulk Actions / Selection Controls -->
      <div class="flex items-center gap-4 text-sm shrink-0">
        <!-- Select All Checkbox -->
        <label class="flex items-center gap-2 text-xs font-medium text-n-slate-11 cursor-pointer select-none">
          <input
            type="checkbox"
            :checked="isAllFilteredDealsSelected"
            @change="toggleSelectAllFiltered"
            class="w-3.5 h-3.5 rounded border-n-weak text-n-brand focus:ring-n-brand cursor-pointer"
            :disabled="filteredDeals.length === 0"
          />
          <span>Selecionar todos</span>
        </label>

        <!-- Bulk delete button & count if selected -->
        <transition
          enter-active-class="transition duration-150 ease-out"
          enter-from-class="opacity-0 scale-95"
          leave-active-class="transition duration-100 ease-in"
          leave-to-class="opacity-0 scale-95"
        >
          <div v-if="selectedDealIds.length > 0" class="flex items-center gap-3">
            <span class="text-xs text-n-slate-12 font-medium bg-n-brand/10 text-n-brand px-2 py-0.5 rounded-full">
              {{ selectedDealIds.length }} selecionado(s)
            </span>
            <button
              @click="deleteSelectedDeals"
              class="flex items-center gap-1.5 px-3 py-1 text-xs font-semibold text-white bg-n-ruby-9 hover:bg-n-ruby-10 active:bg-n-ruby-11 rounded-lg transition-colors duration-150 cursor-pointer"
            >
              <fluent-icon icon="delete" size="12" />
              <span>Deletar</span>
            </button>
            <button
              @click="clearSelection"
              class="text-xs text-n-slate-11 hover:text-n-slate-12 cursor-pointer font-medium"
            >
              Cancelar
            </button>
          </div>
        </transition>
      </div>
    </div>

    <!-- Loading -->
    <KanbanSkeleton v-if="isLoading" />

    <!-- Kanban Board — fills all remaining space -->
    <div v-else class="flex flex-1 gap-4 p-4 overflow-x-auto min-h-0">
      <div
        v-for="stage in stages"
        :key="stage.id"
        class="flex flex-col min-w-[280px] max-w-[320px] flex-1 rounded-xl border border-n-weak bg-n-solid-2 overflow-hidden"
      >
        <!-- Stage Color Accent Bar -->
        <div
          class="h-1 w-full"
          :style="{ backgroundColor: stage.color || '#1f93ff' }"
        />

        <!-- Column header -->
        <div
          class="flex items-center justify-between px-3 py-2.5 border-b border-n-weak"
        >
          <div class="flex items-center gap-2">
            <h3 class="text-sm font-medium text-n-slate-12 m-0">
              {{ stage.name }}
            </h3>
            <span
              class="text-xs font-medium text-n-slate-11 bg-n-alpha-1 px-1.5 py-0.5 rounded-full"
            >
              {{ getDealsForStage(stage.id).length }}
            </span>
          </div>
          <span class="text-xs text-n-slate-11">
            {{ formatCurrency(stage.total_value || 0) }}
          </span>
        </div>

        <!-- Progress bar -->
        <div class="h-0.5 bg-n-alpha-1">
          <div
            class="h-full transition-all duration-300"
            :style="{ width: `${stage.win_probability || 0}%`, backgroundColor: stage.color || '#1f93ff' }"
          />
        </div>

        <!-- Draggable cards area — stretches to fill column -->
        <draggable
          :list="getDealsForStage(stage.id)"
          :group="{ name: 'deals' }"
          item-key="id"
          class="flex-1 p-2 space-y-2 overflow-y-auto"
          ghost-class="opacity-50"
          @end="onDragEnd($event, stage.id)"
        >
          <template #item="{ element: deal }">
            <div
              class="bg-n-solid-3 border border-n-weak rounded-lg p-3 cursor-pointer transition-all duration-200 hover:border-n-brand hover:shadow-md relative"
              :class="{
                'border-l-2 !border-l-n-ruby-9': deal.is_rotting,
              }"
              tabindex="0"
              role="button"
              :aria-label="`${cleanTitle(deal.title)} - ${formatCurrency(deal.value || 0)}`"
              @click="openDealDrawer(deal)"
              @keydown.enter="openDealDrawer(deal)"
              @keydown.space.prevent="openDealDrawer(deal)"
            >
              <!-- Checkbox de seleção individual -->
              <div class="absolute top-3.5 left-3.5" @click.stop>
                <input
                  type="checkbox"
                  :value="deal.id"
                  v-model="selectedDealIds"
                  class="w-3.5 h-3.5 rounded border-n-weak text-n-brand focus:ring-n-brand cursor-pointer"
                />
              </div>

              <!-- Conteúdo deslocado para não sobrepor o checkbox -->
              <div class="pl-6">
                <div class="flex items-start justify-between mb-1.5">
                  <span
                    class="text-sm font-medium text-n-slate-12 flex-1 mr-2"
                  >
                    {{ cleanTitle(deal.title) }}
                  </span>
                  <span
                    class="text-xs font-semibold text-n-teal-11 whitespace-nowrap"
                  >
                    {{ formatCurrency(deal.value || 0) }}
                  </span>
                </div>
                <div class="flex items-center gap-1.5 mb-1.5">
                  <Avatar
                    :src="deal.contact?.avatar_url"
                    :name="deal.contact?.name"
                    :size="20"
                  />
                  <span class="text-xs text-n-slate-11 truncate">
                    {{ deal.contact?.name }}
                  </span>
                </div>
                <div class="flex items-center justify-between">
                  <span v-if="deal.assignee">
                    <Avatar
                      :src="deal.assignee?.avatar_url"
                      :name="deal.assignee?.name"
                      :size="16"
                    />
                  </span>
                  <span
                    v-if="deal.last_activity_at"
                    class="text-[10px] text-n-slate-10"
                  >
                    {{ formatDate(deal.last_activity_at) }}
                  </span>
                </div>
              </div>
            </div>
          </template>
        </draggable>

        <!-- Add deal button -->
        <button
          class="flex items-center justify-center gap-1.5 w-full py-2.5 text-sm font-medium text-white bg-woot-500 hover:bg-woot-600 active:bg-woot-800 transition-colors duration-200 border-t border-n-weak rounded-b-xl"
          :aria-label="$t('CRM.DEALS.ADD_TO_STAGE', { stage: stage.name })"
          @click="openCreateDealModal(stage.id)"
        >
          <fluent-icon icon="add" size="14" />
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
    DealForm,
    DealDrawer,
    KanbanSkeleton,
    Avatar,
  },
  data() {
    return {
      showCreateDealModal: false,
      showDealDrawer: false,
      showPipelineDropdown: false,
      selectedDeal: null,
      selectedStageId: null,
      searchQuery: '',
      showFilters: false,
      filterStageId: null,
      filterTag: null,
      filterCustomFieldKey: null,
      filterCustomFieldValue: '',
      selectedDealIds: [],
    };
  },
  computed: {
    ...mapGetters({
      currentPipeline: 'pipelines/getCurrentPipeline',
      allPipelines: 'pipelines/getPipelines',
      pipelineUIFlags: 'pipelines/getUIFlags',
      deals: 'deals/getDeals',
      dealsUIFlags: 'deals/getUIFlags',
      allLabels: 'labels/getLabels',
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
    availableCustomFields() {
      const fields = new Set();
      this.deals.forEach(deal => {
        if (deal.custom_attributes) {
          Object.keys(deal.custom_attributes).forEach(key => fields.add(key));
        }
      });
      return Array.from(fields);
    },
    activeFilterCount() {
      let count = 0;
      if (this.filterStageId) count++;
      if (this.filterTag) count++;
      if (this.filterCustomFieldKey && this.filterCustomFieldValue) count++;
      return count;
    },
    filteredDeals() {
      return this.deals
        .filter(deal => deal.status === 'open')
        .filter(deal => {
          // Search by contact name (lead name)
          if (this.searchQuery) {
            const query = this.searchQuery.toLowerCase();
            const contactName = (deal.contact?.name || '').toLowerCase();
            if (!contactName.includes(query)) return false;
          }

          // Filter by Stage
          if (this.filterStageId && deal.stage_id !== this.filterStageId && deal.stage?.id !== this.filterStageId) {
            return false;
          }

          // Filter by Tags (labels)
          if (this.filterTag) {
            const contactLabels = deal.contact?.labels || [];
            if (!contactLabels.includes(this.filterTag)) return false;
          }

          // Filter by Custom Fields
          if (this.filterCustomFieldKey && this.filterCustomFieldValue) {
            const customVal = String(deal.custom_attributes?.[this.filterCustomFieldKey] || '').toLowerCase();
            const filterVal = this.filterCustomFieldValue.toLowerCase();
            if (!customVal.includes(filterVal)) return false;
          }

          return true;
        });
    },
    isAllFilteredDealsSelected() {
      if (this.filteredDeals.length === 0) return false;
      return this.filteredDeals.every(deal => this.selectedDealIds.includes(deal.id));
    },
  },
  mounted() {
    this.loadData();
    document.addEventListener('click', this.handleClickOutside);
  },
  beforeUnmount() {
    document.removeEventListener('click', this.handleClickOutside);
  },
  methods: {
    ...mapActions({
      fetchPipeline: 'pipelines/show',
      fetchPipelines: 'pipelines/get',
      fetchDeals: 'deals/get',
      moveDeal: 'deals/move',
      fetchLabels: 'labels/get',
      deleteDeal: 'deals/delete',
    }),
    async loadData() {
      await Promise.all([
        this.fetchPipeline(this.pipelineId),
        this.fetchPipelines(),
        this.fetchLabels(),
      ]);
      await this.fetchDeals({ pipelineId: this.pipelineId, status: 'open' });
    },
    goBack() {
      this.$router.push({
        name: 'deals_index',
        params: { accountId: this.$route.params.accountId },
      });
    },
    togglePipelineDropdown() {
      this.showPipelineDropdown = !this.showPipelineDropdown;
    },
    handleClickOutside(event) {
      const dropdown = this.$refs.pipelineDropdown;
      if (dropdown && !dropdown.contains(event.target)) {
        this.showPipelineDropdown = false;
      }
    },
    switchPipeline(pipeline) {
      this.showPipelineDropdown = false;
      if (pipeline.id === this.pipelineId) return;
      this.$router.push({
        name: 'deals_kanban',
        params: {
          accountId: this.$route.params.accountId,
          pipelineId: pipeline.id,
        },
      });
    },
    getDealsForStage(stageId) {
      return this.filteredDeals
        .filter(deal => deal.stage_id === stageId || deal.stage?.id === stageId)
        .sort((a, b) => a.position - b.position);
    },
    toggleSelectAllFiltered() {
      if (this.isAllFilteredDealsSelected) {
        // Deselect only the currently filtered/displayed deals
        const filteredIds = this.filteredDeals.map(deal => deal.id);
        this.selectedDealIds = this.selectedDealIds.filter(id => !filteredIds.includes(id));
      } else {
        // Select all currently filtered/displayed deals (union with existing selection)
        const filteredIds = this.filteredDeals.map(deal => deal.id);
        const union = new Set([...this.selectedDealIds, ...filteredIds]);
        this.selectedDealIds = Array.from(union);
      }
    },
    async deleteSelectedDeals() {
      const ok = confirm(`Tem certeza que deseja deletar os ${this.selectedDealIds.length} negócio(s) selecionado(s)?`);
      if (!ok) return;

      try {
        await Promise.all(this.selectedDealIds.map(id => this.deleteDeal(id)));
        this.$toast.success('Negócio(s) deletado(s) com sucesso!');
        this.selectedDealIds = [];
        this.fetchDeals({ pipelineId: this.pipelineId, status: 'open' });
      } catch (error) {
        this.$toast.error('Ocorreu um erro ao deletar os negócios.');
      }
    },
    clearSelection() {
      this.selectedDealIds = [];
    },
    clearAllFilters() {
      this.searchQuery = '';
      this.filterStageId = null;
      this.filterTag = null;
      this.filterCustomFieldKey = null;
      this.filterCustomFieldValue = '';
      this.selectedDealIds = [];
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
        // Reload deals on error
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
    onDealCreated() {
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
    cleanTitle(title) {
      if (!title) return '';
      return title.replace(/\s*-\s*\d+$/, '');
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
