<template>
  <div class="flex flex-col flex-1 h-full w-full max-w-full overflow-hidden min-w-0">
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

                <!-- Filter by Value Range -->
                <div class="flex flex-col gap-1.5">
                  <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">
                    {{ $t('CRM.DEALS.FILTER_VALUE_RANGE') }}
                  </label>
                  <div class="flex gap-2">
                    <input
                      v-model.number="filterMinValue"
                      type="number"
                      min="0"
                      :placeholder="$t('CRM.DEALS.FILTER_MIN')"
                      class="flex-1 px-3 py-1.5 text-xs bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-12 placeholder-n-slate-11 focus:border-n-brand focus:ring-1 focus:ring-n-brand transition-colors duration-150 h-8"
                    />
                    <input
                      v-model.number="filterMaxValue"
                      type="number"
                      min="0"
                      :placeholder="$t('CRM.DEALS.FILTER_MAX')"
                      class="flex-1 px-3 py-1.5 text-xs bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-12 placeholder-n-slate-11 focus:border-n-brand focus:ring-1 focus:ring-n-brand transition-colors duration-150 h-8"
                    />
                  </div>
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
          <span class="font-semibold text-n-slate-12">
            {{ currencyValue(boardValue) }}
          </span>
        </div>
        <div
          class="flex items-center gap-1.5 text-sm"
          :title="$t('CRM.DEALS.WEIGHTED_VALUE_HELP')"
        >
          <span class="text-n-slate-11">
            {{ $t('CRM.DEALS.WEIGHTED_VALUE') }}:
          </span>
          <span class="font-semibold text-n-teal-11">
            {{ currencyValue(weightedForecast) }}
          </span>
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
            :disabled="loadedDeals.length === 0"
          />
          <span>Selecionar todos</span>
        </label>

        <!-- Botão Ações (Dropdown) -->
        <div class="relative" ref="bulkActionsDropdown">
          <button
            class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-n-slate-12 bg-n-alpha-1 hover:bg-n-alpha-2 border border-n-weak rounded-lg transition-colors duration-150 cursor-pointer h-8"
            @click="toggleBulkActionsDropdown"
          >
            <span>Ações</span>
            <fluent-icon icon="chevron-down" size="10" />
          </button>
          
          <div
            v-if="showBulkActionsDropdown"
            class="absolute right-0 top-full mt-1.5 z-50 min-w-[160px] bg-n-solid-2 border border-n-weak rounded-xl shadow-xl p-1.5 flex flex-col gap-0.5 text-left"
          >
            <!-- Opção Mover (Etapa e Pipeline) -->
            <button
              class="flex items-center gap-2 w-full px-2.5 py-2 text-xs font-medium text-n-slate-12 hover:bg-n-alpha-1 rounded-lg transition-colors cursor-pointer border-0 bg-transparent disabled:opacity-50 disabled:cursor-not-allowed"
              :disabled="selectedDealIds.length === 0"
              @click="openBulkMoveModal"
            >
              <fluent-icon icon="arrow-swap" size="12" class="text-n-slate-11" />
              <span>Mover Etapa</span>
            </button>

            <!-- Opção Exportar -->
            <button
              class="flex items-center gap-2 w-full px-2.5 py-2 text-xs font-medium text-n-slate-12 hover:bg-n-alpha-1 rounded-lg transition-colors cursor-pointer border-0 bg-transparent disabled:opacity-50 disabled:cursor-not-allowed"
              :disabled="selectedDealIds.length === 0"
              @click="exportDeals"
            >
              <fluent-icon icon="share" size="12" class="text-n-slate-11" />
              <span>Exportar</span>
            </button>

            <!-- Opção Importar -->
            <button
              class="flex items-center gap-2 w-full px-2.5 py-2 text-xs font-medium text-n-slate-12 hover:bg-n-alpha-1 rounded-lg transition-colors cursor-pointer border-0 bg-transparent"
              @click="importDeals"
            >
              <fluent-icon icon="arrow-right-import" size="12" class="text-n-slate-11" />
              <span>Importar</span>
            </button>

            <!-- Divisor -->
            <div class="h-[1px] bg-n-weak/30 my-1" />

            <!-- Opção Deletar -->
            <button
              class="flex items-center gap-2 w-full px-2.5 py-2 text-xs font-bold text-n-ruby-9 hover:bg-n-ruby-9/10 rounded-lg transition-colors cursor-pointer border-0 bg-transparent disabled:opacity-50 disabled:cursor-not-allowed"
              :disabled="selectedDealIds.length === 0"
              @click="deleteSelectedDeals"
            >
              <fluent-icon icon="delete" size="12" class="text-n-ruby-9" />
              <span>Deletar</span>
            </button>
          </div>
        </div>

        <!-- Oculto Import Input -->
        <input
          type="file"
          ref="importFileInput"
          accept=".csv"
          class="hidden"
          @change="handleCSVImport"
        />

        <span v-if="selectedDealIds.length > 0" class="text-xs text-n-brand font-medium bg-n-brand/10 px-2 py-0.5 rounded-full">
          {{ selectedDealIds.length }} selecionado(s)
        </span>
        <button
          v-if="selectedDealIds.length > 0"
          @click="clearSelection"
          class="text-xs text-n-slate-11 hover:text-n-slate-12 cursor-pointer font-medium border-0 bg-transparent"
        >
          Cancelar
        </button>
      </div>
    </div>

    <!-- Loading -->
    <KanbanSkeleton v-if="isLoading && !showDealDrawer" />

    <!-- Kanban Board — fills all remaining space -->
    <div v-else class="flex flex-1 gap-4 p-4 overflow-x-auto min-h-0 w-full max-w-full">
      <div
        v-for="stage in boardStages"
        :key="stage.id"
        class="flex flex-col shrink-0 rounded-xl border border-n-weak bg-n-solid-2 overflow-hidden"
        style="min-width: 280px; width: 280px;"
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
              {{ stage.total_count }}
            </span>
          </div>
          <span
            v-if="Number(stage.total_value) > 0"
            class="text-xs font-semibold text-n-slate-11 shrink-0"
          >
            {{ compactValue(stage.total_value) }}
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
          v-model="stage.deals"
          :group="{ name: 'deals' }"
          item-key="id"
          :data-stage-id="stage.id"
          class="flex-1 p-2 space-y-2 overflow-y-auto"
          ghost-class="opacity-50"
          @end="onDragEnd"
          @scroll.passive="onStageScroll($event, stage)"
        >
          <template #item="{ element: deal }">
            <div
              :data-deal-id="deal.id"
              class="bg-n-solid-3 border border-n-weak rounded-lg p-3 cursor-pointer transition-all duration-200 hover:border-n-brand hover:shadow-md relative"
              :class="{
                'border-l-2 !border-l-n-ruby-9': deal.is_rotting,
              }"
              tabindex="0"
              role="button"
              :aria-label="deal.title"
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

              <!-- Avatar do Responsável na Extrema Direita -->
              <div v-if="deal.assignee" class="absolute right-3 top-[calc(50%-10px)] z-10">
                <Avatar
                  :src="deal.assignee?.avatar_url"
                  :name="deal.assignee?.name"
                  :size="20"
                />
              </div>

              <!-- Conteúdo deslocado para não sobrepor o checkbox e o responsável -->
              <div class="pl-6 pr-7">
                <!-- Tags do Negócio no topo -->
                <div v-if="deal.labels && deal.labels.length" class="flex flex-wrap gap-1 mb-1.5">
                  <span
                    v-for="label in deal.labels"
                    :key="label"
                    class="text-[9px] font-medium px-1.5 py-0.5 rounded"
                    :style="{
                      backgroundColor: `${getTagColor(label)}15`,
                      color: getTagColor(label),
                      border: `1px solid ${getTagColor(label)}30`
                    }"
                  >
                    {{ label }}
                  </span>
                </div>

                <div class="flex items-start justify-between mb-1.5">
                  <span
                    class="text-sm font-medium text-n-slate-12 flex-1 mr-2 truncate"
                  >
                    {{ deal.title }}
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
                <div class="flex items-center justify-between gap-2">
                  <span
                    v-if="Number(deal.value) > 0"
                    class="text-xs font-semibold text-n-slate-12"
                  >
                    {{ currencyValue(deal.value) }}
                  </span>
                  <span v-else />
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

        <!-- Carregar mais: o total vem do banco, entao a coluna sabe quantos
             negocios ainda faltam mesmo sem te-los carregado -->
        <button
          v-if="stage.deals.length < stage.total_count"
          class="w-full py-2 text-xs font-medium text-n-slate-11 hover:text-n-brand border-t border-n-weak transition-colors duration-150 cursor-pointer disabled:opacity-50"
          :disabled="isStageLoading(stage.id)"
          @click="loadMore(stage)"
        >
          {{
            isStageLoading(stage.id)
              ? $t('CRM.DEALS.LOADING_MORE')
              : $t('CRM.DEALS.LOAD_MORE', {
                  count: stage.total_count - stage.deals.length,
                })
          }}
        </button>

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
      :initial-deal="selectedDeal"
      :is-open="showDealDrawer"
      @close="closeDealDrawer"
      @updated="onDealUpdated"
      @deleted="onDealDeleted"
    />

    <!-- Delete Deal Modal -->
    <woot-delete-modal
      v-if="showDeleteModal"
      v-model:show="showDeleteModal"
      :title="isBulkDelete ? 'Excluir Negócios' : 'Excluir Negócio'"
      :message="isBulkDelete ? `Tem certeza que deseja excluir os ${selectedDealIds.length} negócio(s) selecionado(s)? Esta ação não pode ser desfeita.` : 'Tem certeza que deseja excluir este negócio? Esta ação não pode ser desfeita.'"
      :confirm-text="$t('CRM.DELETE') || 'Excluir'"
      :reject-text="$t('CRM.CANCEL') || 'Cancelar'"
      :on-confirm="confirmDeleteDeal"
      :on-close="closeDeleteModal"
    />

    <!-- Bulk Move Stage Modal -->
    <woot-modal
      v-model:show="showBulkMoveModal"
      :on-close="closeBulkMoveModal"
    >
      <div class="p-6 min-w-[400px] flex flex-col gap-4 bg-n-surface-2 text-n-slate-12">
        <woot-modal-header header-title="Mover Negócios em Lote" />
        
        <p class="text-xs text-n-slate-11 m-0">
          Selecione a nova etapa e o pipeline para mover os <strong>{{ selectedDealIds.length }}</strong> negócio(s) selecionado(s):
        </p>

        <!-- Dropdown / Acordeão de Pipelines e Etapas -->
        <div class="border border-n-weak rounded-xl overflow-hidden p-2 bg-n-solid-2 max-h-72 overflow-y-auto flex flex-col gap-1.5">
          <div
            v-for="pipeline in allPipelines"
            :key="pipeline.id"
            class="flex flex-col border border-n-weak/50 rounded-lg overflow-hidden bg-n-solid-3"
            style="background-color: var(--bg-n-solid-3, #1c1d1f);"
          >
            <!-- Nome do Pipeline (Acordeão Header) -->
            <button
              class="flex items-center justify-between w-full px-3 py-2 text-xs font-bold uppercase tracking-wider bg-n-solid-2 text-n-slate-11 hover:text-n-brand transition-colors cursor-pointer border-0 bg-transparent"
              @click="toggleBulkMovePipeline(pipeline.id)"
            >
              <span class="truncate">{{ pipeline.name }}</span>
              <fluent-icon
                icon="chevron-down"
                size="12"
                class="transition-transform duration-200 text-n-slate-10 shrink-0 ml-2"
                :class="{ 'rotate-180': bulkMoveExpandedPipelineId === pipeline.id }"
              />
            </button>

            <!-- Lista de Etapas (Acordeão Content) -->
            <div
              v-show="bulkMoveExpandedPipelineId === pipeline.id"
              class="flex flex-col gap-[5px] p-[5px] pb-[10px] bg-n-surface-1"
            >
              <button
                v-for="stage in pipeline.stages"
                :key="stage.id"
                class="flex items-center justify-between w-full px-3.5 py-2 text-xs text-left transition-all duration-150 cursor-pointer border-l-4 hover:brightness-95 active:brightness-90 text-n-slate-12 font-medium border-0 rounded-md"
                :style="{
                  backgroundColor: stage.color ? `${stage.color}15` : '#1f93ff15',
                  borderLeftColor: stage.color || '#1f93ff'
                }"
                @click="executeBulkMove(stage.id)"
              >
                <span>{{ stage.name }}</span>
                <span class="text-n-brand flex shrink-0 ml-2">
                  <fluent-icon icon="checkmark" size="12" />
                </span>
              </button>
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-3 mt-4 border-t border-n-weak pt-4">
          <woot-button variant="clear" @click="closeBulkMoveModal">
            {{ $t('CRM.CANCEL') }}
          </woot-button>
        </div>
      </div>
    </woot-modal>
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
import {
  formatDealValue,
  formatDealValueCompact,
} from 'dashboard/helper/crmCurrency';

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
      filterMinValue: null,
      filterMaxValue: null,
      selectedDealIds: [],
      showBulkActionsDropdown: false,
      showBulkMoveModal: false,
      bulkMoveExpandedPipelineId: null,
      showDeleteModal: false,
      isBulkDelete: false,
      filterDebounce: null,
    };
  },
  computed: {
    ...mapGetters({
      currentPipeline: 'pipelines/getCurrentPipeline',
      allPipelines: 'pipelines/getPipelines',
      pipelineUIFlags: 'pipelines/getUIFlags',
      boardStages: 'deals/getBoardStages',
      boardTotal: 'deals/getBoardTotal',
      boardValue: 'deals/getBoardValue',
      boardCurrency: 'deals/getBoardCurrency',
      weightedForecast: 'deals/getWeightedForecast',
      isStageLoading: 'deals/isStageLoading',
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
      return (
        !this.showDealDrawer &&
        this.dealsUIFlags.isFetching &&
        this.boardStages.length === 0
      );
    },
    totalDeals() {
      return this.boardTotal;
    },
    // Todos os negocios ja carregados no board, para selecao e exportacao.
    loadedDeals() {
      return this.boardStages.flatMap(stage => stage.deals);
    },
    // Os filtros rodam no backend; as chaves vem dos negocios ja carregados
    // apenas para popular o seletor.
    availableCustomFields() {
      const fields = new Set();
      this.loadedDeals.forEach(deal => {
        Object.keys(deal.custom_attributes || {}).forEach(key =>
          fields.add(key)
        );
      });
      return Array.from(fields);
    },
    activeFilterCount() {
      let count = 0;
      if (this.filterStageId) count++;
      if (this.filterTag) count++;
      if (this.filterCustomFieldKey && this.filterCustomFieldValue) count++;
      if (this.filterMinValue || this.filterMaxValue) count++;
      return count;
    },
    boardFilters() {
      return {
        q: this.searchQuery || undefined,
        stage_id: this.filterStageId || undefined,
        label: this.filterTag || undefined,
        custom_field_key: this.filterCustomFieldKey || undefined,
        custom_field_value: this.filterCustomFieldValue || undefined,
        min_value: this.filterMinValue || undefined,
        max_value: this.filterMaxValue || undefined,
      };
    },
    isAllFilteredDealsSelected() {
      if (this.loadedDeals.length === 0) return false;
      return this.loadedDeals.every(deal =>
        this.selectedDealIds.includes(deal.id)
      );
    },
  },
  watch: {
    pipelineId(newId, oldId) {
      if (newId && newId !== oldId) {
        this.clearAllFilters();
        this.showPipelineDropdown = false;
        this.showFilters = false;
        this.loadData();
      }
    },
    // Filtros rodam no backend: qualquer mudanca recarrega o board. O debounce
    // evita uma requisicao por tecla digitada.
    boardFilters: {
      deep: true,
      handler() {
        clearTimeout(this.filterDebounce);
        this.filterDebounce = setTimeout(() => this.fetchBoardData(), 300);
      },
    },
  },
  mounted() {
    this.loadData();
    document.addEventListener('click', this.handleClickOutside);
    document.addEventListener('click', this.handleClickOutsideBulk);
  },
  beforeUnmount() {
    clearTimeout(this.filterDebounce);
    document.removeEventListener('click', this.handleClickOutside);
    document.removeEventListener('click', this.handleClickOutsideBulk);
  },
  methods: {
    ...mapActions({
      fetchPipeline: 'pipelines/show',
      fetchPipelines: 'pipelines/get',
      fetchBoard: 'deals/fetchBoard',
      loadMoreForStage: 'deals/loadMoreForStage',
      moveDeal: 'deals/move',
      fetchLabels: 'labels/get',
      deleteDeal: 'deals/delete',
      updateDeal: 'deals/update',
      createDeal: 'deals/create',
    }),
    async loadData() {
      await Promise.all([
        this.fetchPipeline(this.pipelineId),
        this.fetchPipelines(),
        this.fetchLabels(),
      ]);
      await this.fetchBoardData();
    },
    async fetchBoardData() {
      try {
        await this.fetchBoard({
          pipelineId: this.pipelineId,
          filters: this.boardFilters,
        });
      } catch (error) {
        this.$toast.error(this.$t('CRM.DEALS.LOAD_ERROR'));
      }
    },
    async loadMore(stage) {
      try {
        await this.loadMoreForStage({
          stageId: stage.id,
          filters: {
            pipelineId: this.pipelineId,
            q: this.searchQuery || undefined,
            label: this.filterTag || undefined,
            customFieldKey: this.filterCustomFieldKey || undefined,
            customFieldValue: this.filterCustomFieldValue || undefined,
          },
        });
      } catch (error) {
        this.$toast.error(this.$t('CRM.DEALS.LOAD_ERROR'));
      }
    },
    // Carrega a proxima pagina ao chegar perto do fim da coluna.
    onStageScroll(event, stage) {
      const el = event.target;
      const nearBottom =
        el.scrollHeight - el.scrollTop - el.clientHeight < 120;
      if (!nearBottom) return;
      if (stage.deals.length >= stage.total_count) return;
      if (this.isStageLoading(stage.id)) return;

      this.loadMore(stage);
    },
    getTagColor(title) {
      const label = this.allLabels?.find(l => l.title === title);
      return label ? label.color : '#3b82f6';
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
    toggleSelectAllFiltered() {
      if (this.isAllFilteredDealsSelected) {
        // Deselect only the currently filtered/displayed deals
        const filteredIds = this.loadedDeals.map(deal => deal.id);
        this.selectedDealIds = this.selectedDealIds.filter(id => !filteredIds.includes(id));
      } else {
        // Select all currently filtered/displayed deals (union with existing selection)
        const filteredIds = this.loadedDeals.map(deal => deal.id);
        const union = new Set([...this.selectedDealIds, ...filteredIds]);
        this.selectedDealIds = Array.from(union);
      }
    },
    deleteSelectedDeals() {
      this.showBulkActionsDropdown = false;
      this.isBulkDelete = true;
      this.showDeleteModal = true;
    },
    closeDeleteModal() {
      this.showDeleteModal = false;
      this.isBulkDelete = false;
    },
    async confirmDeleteDeal() {
      this.closeDeleteModal();
      try {
        await Promise.all(this.selectedDealIds.map(id => this.deleteDeal(id)));
        this.$toast.success('Negócio(s) excluído(s) com sucesso.');
        this.selectedDealIds = [];
        this.fetchBoardData();
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
      this.filterMinValue = null;
      this.filterMaxValue = null;
      this.selectedDealIds = [];
    },
    async onDragEnd(event) {
      const dealId = Number(event.item.getAttribute('data-deal-id'));
      const newStageId = Number(event.to.getAttribute('data-stage-id'));
      if (!dealId || !newStageId) return;

      try {
        await this.moveDeal({
          id: dealId,
          stageId: newStageId,
          position: event.newIndex,
        });
      } catch (error) {
        this.$toast.error(this.$t('CRM.DEALS.MOVE_ERROR'));
        // Reload deals on error
        this.fetchBoardData();
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
      this.fetchBoardData();
    },
    openDealDrawer(deal) {
      this.selectedDeal = deal;
      this.showDealDrawer = true;
    },
    closeDealDrawer() {
      this.showDealDrawer = false;
      setTimeout(() => {
        if (!this.showDealDrawer) {
          this.selectedDeal = null;
        }
      }, 250);
    },
    onDealUpdated() {
      this.fetchBoardData();
    },
    onDealDeleted() {
      this.closeDealDrawer();
      this.fetchBoardData();
    },

    formatDate(date) {
      return formatDistanceToNow(new Date(date), {
        addSuffix: true,
        locale: ptBR,
      });
    },
    currencyValue(value) {
      return formatDealValue(value, this.boardCurrency);
    },
    compactValue(value) {
      return formatDealValueCompact(value, this.boardCurrency);
    },
    toggleBulkActionsDropdown() {
      this.showBulkActionsDropdown = !this.showBulkActionsDropdown;
    },
    toggleBulkMovePipeline(pipelineId) {
      if (this.bulkMoveExpandedPipelineId === pipelineId) {
        this.bulkMoveExpandedPipelineId = null;
      } else {
        this.bulkMoveExpandedPipelineId = pipelineId;
      }
    },
    openBulkMoveModal() {
      this.showBulkActionsDropdown = false;
      this.showBulkMoveModal = true;
      this.bulkMoveExpandedPipelineId = this.allPipelines[0]?.id;
    },
    closeBulkMoveModal() {
      this.showBulkMoveModal = false;
      this.bulkMoveExpandedPipelineId = null;
    },
    async executeBulkMove(stageId) {
      this.closeBulkMoveModal();
      this.$toast.info('Movendo negócios...');
      try {
        await Promise.all(
          this.selectedDealIds.map(id =>
            this.updateDeal({
              id: id,
              stage_id: stageId,
            })
          )
        );
        this.$toast.success('Negócio(s) movido(s) com sucesso!');
        this.selectedDealIds = [];
        this.fetchBoardData();
      } catch (error) {
        this.$toast.error('Erro ao mover os negócios.');
      }
    },
    exportDeals() {
      this.showBulkActionsDropdown = false;
      const selectedDeals = this.loadedDeals.filter(d => this.selectedDealIds.includes(d.id));
      if (selectedDeals.length === 0) return;

      const headers = ['ID', 'Negocio', 'Valor', 'Contato', 'E-mail', 'Telefone', 'Pipeline', 'Etapa', 'Responsavel', 'Status', 'Criado Em'];
      const rows = selectedDeals.map(d => [
        d.id,
        d.title || '',
        d.value ?? 0,
        d.contact?.name || '',
        d.contact?.email || '',
        d.contact?.phone_number || '',
        d.pipeline?.name || '',
        d.stage?.name || '',
        d.assignee?.name || '',
        d.status || '',
        d.created_at || '',
      ]);

      const csvContent = "data:text/csv;charset=utf-8,\uFEFF" 
        + [headers.join(','), ...rows.map(e => e.map(val => `"${String(val).replace(/"/g, '""')}"`).join(','))].join('\n');
      
      const encodedUri = encodeURI(csvContent);
      const link = document.createElement("a");
      link.setAttribute("href", encodedUri);
      link.setAttribute("download", `negocios_exportados_${new Date().getTime()}.csv`);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      this.$toast.success('Negócios exportados com sucesso!');
    },
    importDeals() {
      this.showBulkActionsDropdown = false;
      this.$refs.importFileInput.click();
    },
    async handleCSVImport(event) {
      const file = event.target.files[0];
      if (!file) return;

      const reader = new FileReader();
      reader.onload = async (e) => {
        try {
          const text = e.target.result;
          const lines = text.split('\n').map(l => l.trim()).filter(Boolean);
          if (lines.length <= 1) {
            this.$toast.error('O arquivo CSV está vazio ou inválido.');
            return;
          }

          const headers = lines[0].split(',').map(h => h.replace(/^"|"$/g, '').trim().toLowerCase());
          const titleIdx = headers.indexOf('negocio') > -1 ? headers.indexOf('negocio') : headers.indexOf('negócio');
          const contactIdx = headers.indexOf('contato');

          if (titleIdx === -1) {
            this.$toast.error('A coluna "Negócio" é obrigatória no CSV.');
            return;
          }

          const pipeline = this.currentPipeline;
          const stageId = pipeline?.stages?.[0]?.id;
          if (!stageId) {
            this.$toast.error('Nenhum funil ou etapa activa encontrada para importar.');
            return;
          }

          this.$toast.info('Iniciando importação de negócios...');
          let successCount = 0;
          let skipped = 0;

          for (let i = 1; i < lines.length; i++) {
            const cols = lines[i].split(',').map(c => c.replace(/^"|"$/g, '').trim());
            const title = cols[titleIdx];
            if (!title) continue;

            const contactName = contactIdx !== -1 ? cols[contactIdx] : 'Cliente Importado';

            // Sem contato nao ha negocio valido. Antes o fallback pegava o
            // contato de outro negocio da tela, ou o id 1, e vinculava a linha
            // importada a alguem que nao tinha nada a ver com ela.
            let contactId = null;
            try {
              const newContact = await this.$store.dispatch('contacts/create', { name: contactName });
              contactId = newContact.id;
            } catch (err) {
              skipped += 1;
              continue;
            }

            try {
              await this.createDeal({
                title,
                stage_id: stageId,
                contact_id: contactId,
              });
              successCount++;
            } catch (err) {
              skipped += 1;
            }
          }

          if (skipped > 0) {
            this.$toast.info(
              `${successCount} negócio(s) importado(s), ${skipped} linha(s) ignorada(s).`
            );
          } else {
            this.$toast.success(`${successCount} negócio(s) importado(s) com sucesso!`);
          }
          this.fetchBoardData();
        } catch (err) {
          this.$toast.error('Erro ao ler ou processar o arquivo CSV.');
        }
      };
      reader.readAsText(file);
      event.target.value = '';
    },
    handleClickOutsideBulk(event) {
      const dropdown = this.$refs.bulkActionsDropdown;
      if (dropdown && !dropdown.contains(event.target)) {
        this.showBulkActionsDropdown = false;
      }
    },
  },
};
</script>

<style lang="scss" scoped>
:deep(.modal-container),
:deep(.modal-container .deal-form),
:deep(.modal-container form) {
  &:has(.deal-form) {
    overflow: visible !important;
  }
}
</style>
