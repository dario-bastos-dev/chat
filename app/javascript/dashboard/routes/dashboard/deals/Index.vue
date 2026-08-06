<template>
  <div class="flex flex-col flex-1 h-full">
    <!-- Redirecting to default pipeline — show skeleton only -->
    <div v-if="((uiFlags.isFetching && pipelines.length === 0) || isRedirecting) && !showDealDrawer" class="flex flex-1 gap-4 p-4 animate-pulse">
      <div
        v-for="i in 5"
        :key="i"
        class="flex flex-col min-w-[280px] flex-1 rounded-xl border border-n-weak bg-n-solid-2"
      >
        <div class="px-3 py-3 border-b border-n-weak">
          <div class="h-4 w-24 bg-n-alpha-2 rounded" />
        </div>
        <div class="flex flex-col gap-3 p-3">
          <div
            v-for="j in (3 + i % 2)"
            :key="j"
            class="h-20 bg-n-alpha-2 rounded-lg"
          />
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div
      v-else-if="pipelines.length === 0"
      class="flex items-center justify-center h-[calc(100vh-200px)] p-6"
    >
      <div
        class="flex flex-col items-center text-center max-w-md p-8 bg-n-solid-2 border border-n-weak rounded-2xl shadow-xl shadow-n-weak/10 animate-fadeIn"
      >
        <div
          class="w-16 h-16 rounded-full bg-n-brand/10 text-n-brand flex items-center justify-center mb-6 ring-4 ring-n-brand/5 shadow-inner"
        >
          <fluent-icon icon="briefcase" size="28" />
        </div>
        <h2 class="text-lg font-bold text-n-slate-12 m-0 mb-2 tracking-tight">
          {{ $t('CRM.PIPELINES.EMPTY.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11 m-0 mb-6 leading-relaxed max-w-sm">
          {{ $t('CRM.PIPELINES.EMPTY.DESCRIPTION') }}
        </p>
        <button
          class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-semibold text-white bg-woot-500 hover:bg-woot-600 active:bg-woot-800 rounded-xl transition-all duration-200 cursor-pointer shadow-lg shadow-woot-500/20 hover:shadow-xl hover:shadow-woot-500/30 hover:-translate-y-0.5 active:translate-y-0"
          @click="openCreatePipelineModal"
        >
          <fluent-icon icon="add" size="14" />
          {{ $t('CRM.PIPELINES.CREATE') }}
        </button>
      </div>
    </div>

    <!-- Tabela Geral de Negócios (Deals List) se tiver pipelines -->
    <div v-else class="flex flex-col flex-1 overflow-hidden bg-n-background">
      <!-- Header da listagem de negócios -->
      <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak bg-n-solid-2 gap-4 shrink-0">
        <div class="flex flex-col gap-0.5">
          <h1 class="text-lg font-bold text-n-slate-12 m-0 tracking-tight">
            Negócios
          </h1>
        </div>

        <!-- Barra de busca alinhada à direita -->
        <div class="flex items-center gap-3 w-full max-w-xs md:max-w-md shrink-0 ml-auto">
          <div class="relative w-full">
            <div class="flex items-center gap-2 bg-n-alpha-1 border border-n-weak rounded-lg px-3 focus-within:border-n-brand focus-within:ring-1 focus-within:ring-n-brand transition-colors duration-150 h-9">
              <fluent-icon icon="search" size="16" class="text-n-slate-11 shrink-0" />
              <input
                v-model="searchQuery"
                type="text"
                placeholder="Pesquisar por negócio ou contato..."
                class="w-full !py-1 text-sm !bg-transparent !border-0 !border-none !outline-none !focus:outline-none !focus:ring-0 !focus:border-none !focus-visible:outline-none !shadow-none text-n-slate-12 placeholder-n-slate-11 !h-full !p-0 !m-0 no-margin"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Barra de Estatísticas da listagem -->
      <div class="flex items-center justify-between px-6 py-2.5 border-b border-n-weak bg-n-solid-2 shrink-0 gap-4">
        <div class="flex items-center gap-6">
          <div class="flex items-center gap-1.5 text-sm">
            <span class="text-n-slate-11">Total de Negócios:</span>
            <span class="font-semibold text-n-slate-12">{{ filteredDeals.length }}</span>
          </div>
        </div>

        <!-- Bulk Actions / Selection Controls -->
        <div class="flex items-center gap-4 text-sm shrink-0">
          <!-- Select All Checkbox -->
          <label class="flex items-center gap-2 text-xs font-medium text-n-slate-11 cursor-pointer select-none">
            <input
              type="checkbox"
              :checked="isAllSelected"
              @change="toggleSelectAll"
              class="w-3.5 h-3.5 rounded border-n-weak text-n-brand focus:ring-n-brand cursor-pointer"
              :disabled="filteredDeals.length === 0"
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

      <!-- Tabela Base -->
      <div class="flex-1 overflow-auto p-6">
        <div class="bg-n-solid-2 border border-n-weak rounded-2xl overflow-hidden shadow-sm">
          <BaseTable
            :headers="tableHeaders"
            :items="filteredDeals"
            no-data-message="Nenhum negócio encontrado no CRM."
          >
            <template #row="{ items }">
              <BaseTableRow v-for="deal in items" :key="deal.id" :item="deal">
                <!-- Checkbox Seleção -->
                <BaseTableCell class="w-12 pl-2 pr-0">
                  <div class="flex items-center justify-start">
                    <input
                      type="checkbox"
                      :value="deal.id"
                      :checked="selectedDealIds.includes(deal.id)"
                      @change="toggleSelectDeal(deal.id)"
                      class="w-4 h-4 rounded border-n-weak text-n-brand focus:ring-n-brand cursor-pointer"
                    />
                  </div>
                </BaseTableCell>

                <!-- Negócio -->
                <BaseTableCell class="font-medium text-n-slate-12">
                  <span
                    class="font-semibold text-n-slate-12 cursor-pointer hover:text-woot-500 transition-colors truncate block max-w-[200px]"
                    @click="openDealDrawer(deal)"
                  >
                    {{ deal.title }}
                  </span>
                </BaseTableCell>

                <!-- Valor -->
                <BaseTableCell>
                  <span class="font-medium text-n-slate-12 whitespace-nowrap">
                    {{ currencyValue(deal.value) }}
                  </span>
                </BaseTableCell>

                <!-- Contato -->
                <BaseTableCell>
                  <span class="text-n-slate-11 truncate block max-w-[150px]">
                    {{ deal.contact ? deal.contact.name : '—' }}
                  </span>
                </BaseTableCell>

                <!-- Pipeline -->
                <BaseTableCell>
                  <span class="text-n-slate-11 font-medium">
                    {{ deal.pipeline ? deal.pipeline.name : '—' }}
                  </span>
                </BaseTableCell>

                <!-- Etapa -->
                <BaseTableCell>
                  <div class="flex items-center gap-2">
                    <span
                      class="w-2 h-2 rounded-full shrink-0"
                      :style="{ backgroundColor: getDealStageColor(deal) }"
                    />
                    <span class="text-n-slate-12 font-medium truncate block max-w-[120px]">
                      {{ deal.stage ? deal.stage.name : '—' }}
                    </span>
                  </div>
                </BaseTableCell>



                <!-- Responsável -->
                <BaseTableCell>
                  <div class="flex items-center gap-2">
                    <Avatar
                      v-if="deal.assignee"
                      :src="deal.assignee.avatar_url"
                      :name="deal.assignee.name"
                      :size="20"
                      class="rounded-full"
                    />
                    <span class="text-n-slate-11 text-xs truncate max-w-[100px]">
                      {{ deal.assignee ? deal.assignee.name : 'Não atribuído' }}
                    </span>
                  </div>
                </BaseTableCell>

                <!-- Status -->
                <BaseTableCell>
                  <span
                    class="text-[9px] font-bold px-2 py-0.5 rounded-full uppercase tracking-wider ring-1 shrink-0 inline-block"
                    :class="getStatusBadgeClass(deal.status)"
                  >
                    {{ getStatusLabel(deal.status) }}
                  </span>
                </BaseTableCell>

                <!-- Ações -->
                <BaseTableCell align="end" class="w-24">
                  <div class="flex gap-2.5 justify-end shrink-0">
                    <Button
                      v-tooltip.top="'Editar'"
                      icon="i-woot-edit-pen"
                      slate
                      sm
                      class="rounded-lg cursor-pointer hover:bg-n-alpha-1"
                      @click="openDealDrawer(deal)"
                    />
                    <Button
                      v-tooltip.top="'Deletar'"
                      icon="i-woot-bin"
                      slate
                      sm
                      class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2 rounded-lg cursor-pointer"
                      @click="deleteDeal(deal)"
                    />
                  </div>
                </BaseTableCell>
              </BaseTableRow>
            </template>
          </BaseTable>
        </div>
      </div>
    </div>

    <!-- Deal Drawer for editing details -->
    <DealDrawer
      v-if="selectedDeal"
      :is-open="showDealDrawer"
      :initial-deal="selectedDeal"
      @close="closeDealDrawer"
    />

    <!-- Create Deal Modal -->
    <woot-modal v-model:show="showCreateDealModal" :on-close="closeCreateDealModal">
      <DealForm
        v-if="showCreateDealModal && defaultPipeline"
        :pipeline="defaultPipeline"
        @close="closeCreateDealModal"
        @success="onDealCreated"
      />
    </woot-modal>

    <!-- Create Pipeline Modal (ClickUp-like 2 Columns Layout) -->
    <woot-modal v-model:show="showCreateModal" :on-close="closeCreateModal" size="modal-big">
      <div class="p-6 min-w-[400px] sm:min-w-[700px] lg:min-w-[850px] bg-n-solid-1 text-n-slate-12">
        <!-- Title Input (Header) -->
        <div class="pb-4 border-b border-n-weak mb-5 flex items-center justify-between">
          <input
            v-model="newPipeline.name"
            type="text"
            class="text-xl font-bold bg-transparent border-0 border-b border-transparent hover:border-n-weak focus:border-n-brand focus:outline-none transition-all px-1 py-0.5 w-full md:max-w-[32%] text-n-slate-12 placeholder:text-n-slate-9"
            placeholder="Nome do Pipeline..."
            required
          />
        </div>

        <form @submit.prevent="createPipeline" class="space-y-6">
          <div class="flex flex-col md:flex-row gap-6">
            <!-- Coluna Esquerda: Menu de Configurações (32%) -->
            <div class="w-full md:w-[32%] flex flex-col justify-between self-stretch">
              <div class="space-y-1.5">
                <!-- Item 1: Etapas -->
                <div
                  class="flex items-center gap-3 p-3 rounded-xl cursor-pointer transition-all border border-transparent font-semibold text-sm"
                  :class="activeTab === 'stages' ? 'bg-n-brand/10 text-n-brand border-n-brand/20 shadow-sm' : 'text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-1'"
                  @click="activeTab = 'stages'"
                >
                  <fluent-icon icon="board" size="18" />
                  <span>Etapas do Funil</span>
                </div>

                <!-- Item 2: Visibilidade -->
                <div
                  class="flex items-center gap-3 p-3 rounded-xl cursor-pointer transition-all border border-transparent font-semibold text-sm"
                  :class="activeTab === 'visibility' ? 'bg-n-brand/10 text-n-brand border-n-brand/20 shadow-sm' : 'text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-1'"
                  @click="activeTab = 'visibility'"
                >
                  <fluent-icon icon="globe" size="18" />
                  <span>Visibilidade</span>
                </div>

                <!-- Item 3: Motivos de Perda -->
                <div
                  class="flex items-center gap-3 p-3 rounded-xl cursor-pointer transition-all border border-transparent font-semibold text-sm"
                  :class="activeTab === 'lost_reasons' ? 'bg-n-brand/10 text-n-brand border-n-brand/20 shadow-sm' : 'text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-1'"
                  @click="activeTab = 'lost_reasons'"
                >
                  <fluent-icon icon="dismiss" size="18" />
                  <span>Motivos de Perda</span>
                </div>
              </div>

              <!-- Pipeline Padrão no rodapé da coluna -->
              <div class="mt-8 pt-4 border-t border-n-weak/50">
                <label class="flex items-center gap-2 px-2 py-1 text-xs font-semibold text-n-slate-11 cursor-pointer m-0">
                  <input
                    type="checkbox"
                    v-model="newPipeline.is_default"
                    class="w-3.5 h-3.5 rounded border-n-weak text-n-brand focus:ring-n-brand cursor-pointer"
                  />
                  <span>Definir como padrão</span>
                </label>
              </div>
            </div>

            <!-- Coluna Direita: Conteúdo Ativo (68%) -->
            <div class="w-full md:w-[68%] md:pl-6 md:border-l md:border-n-weak min-h-[360px]">
              
              <!-- TAB 1: ETAPAS DO FUNIL (SEM SCROLL OU BARRAS!) -->
              <div v-if="activeTab === 'stages'" class="space-y-5 animate-fadeIn">
                <div>
                  <h4 class="text-sm font-semibold text-n-slate-12 m-0 mb-1">
                    Etapas do Funil
                  </h4>
                  <p class="text-xs text-n-slate-11 m-0 leading-relaxed">
                    Configure os estágios organizados por grupos de fluxo de vendas. Mínimo de 3 etapas no total.
                  </p>
                </div>

                <div class="space-y-4">
                  <!-- Grupos de Etapas -->
                  <div v-for="group in stageGroups" :key="group.key" class="space-y-2">
                    <!-- Group Header -->
                    <div class="flex items-center justify-between border-b border-n-weak/50 pb-1.5">
                      <div class="flex items-center gap-2">
                        <span class="w-2 h-2 rounded-full" :class="group.dotColor" />
                        <span class="text-xs font-bold text-n-slate-12 uppercase tracking-wider">
                          {{ $t(`CRM.STAGE_GROUPS.${group.key.toUpperCase()}`) }}
                        </span>
                        <span class="text-[10px] text-n-slate-10 font-medium">
                          ({{ getStagesByGroup(group.key).length }})
                        </span>
                      </div>
                      <button
                        v-if="group.key === 'active'"
                        type="button"
                        class="p-1 text-woot-500 hover:bg-woot-500/10 rounded-lg cursor-pointer border-0 bg-transparent flex items-center justify-center"
                        @click="addStageByGroup(group.key)"
                        title="Adicionar etapa a este grupo"
                      >
                        <fluent-icon icon="add" size="12" />
                      </button>
                    </div>

                    <!-- Group Stage List (SEM SCROLL HORIZONTAL OU INPUTS ADICIONAIS!) -->
                    <div class="space-y-2">
                      <!-- Not Started Group Draggable -->
                      <draggable
                        v-if="group.key === 'not_started'"
                        v-model="notStartedStages"
                        class="space-y-2"
                        handle=".drag-handle"
                        item-key="position"
                      >
                        <template #item="{ element: stage, index }">
                          <div
                            class="flex items-center gap-2 bg-n-solid-2 p-1.5 border border-n-weak rounded-xl shadow-sm hover:border-n-brand/20 transition-all"
                          >
                            <!-- Drag Handle -->
                            <span class="drag-handle i-ph-dots-six-vertical size-3.5 text-n-slate-9 cursor-move flex-shrink-0 inline-flex items-center justify-center" />
                            
                            <!-- Custom Color Picker Circle -->
                            <div class="relative flex items-center justify-center flex-shrink-0">
                              <div
                                class="w-5 h-5 rounded-full border border-black/10 cursor-pointer shadow-inner hover:scale-105 transition-transform"
                                :style="{ backgroundColor: getStageColor(stage) }"
                                @click="$refs[`colorPicker_${group.key}_${index}`][0].click()"
                              />
                              <input
                                :ref="`colorPicker_${group.key}_${index}`"
                                type="color"
                                v-model="stage.color"
                                class="absolute inset-0 opacity-0 w-5 h-5 pointer-events-none"
                              />
                            </div>

                            <!-- Stage Name input -->
                            <input
                              v-model="stage.name"
                              type="text"
                              class="flex-1 min-w-0 px-2.5 py-1.5 text-xs border border-n-weak rounded-lg bg-n-solid-2 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:border-n-brand focus:ring-1 focus:ring-n-brand/20 transition-all no-margin"
                              placeholder="Nome da etapa"
                              required
                            />

                          </div>
                        </template>
                      </draggable>

                      <!-- Active Group Draggable -->
                      <draggable
                        v-if="group.key === 'active'"
                        v-model="activeStages"
                        class="space-y-2"
                        handle=".drag-handle"
                        item-key="position"
                      >
                        <template #item="{ element: stage, index }">
                          <div
                            class="flex items-center gap-2 bg-n-solid-2 p-1.5 border border-n-weak rounded-xl shadow-sm hover:border-n-brand/20 transition-all"
                          >
                            <!-- Drag Handle -->
                            <span class="drag-handle i-ph-dots-six-vertical size-3.5 text-n-slate-9 cursor-move flex-shrink-0 inline-flex items-center justify-center" />
                            
                            <!-- Custom Color Picker Circle -->
                            <div class="relative flex items-center justify-center flex-shrink-0">
                              <div
                                class="w-5 h-5 rounded-full border border-black/10 cursor-pointer shadow-inner hover:scale-105 transition-transform"
                                :style="{ backgroundColor: getStageColor(stage) }"
                                @click="$refs[`colorPicker_${group.key}_${index}`][0].click()"
                              />
                              <input
                                :ref="`colorPicker_${group.key}_${index}`"
                                type="color"
                                v-model="stage.color"
                                class="absolute inset-0 opacity-0 w-5 h-5 pointer-events-none"
                              />
                            </div>

                            <!-- Stage Name input -->
                            <input
                              v-model="stage.name"
                              type="text"
                              class="flex-1 min-w-0 px-2.5 py-1.5 text-xs border border-n-weak rounded-lg bg-n-solid-2 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:border-n-brand focus:ring-1 focus:ring-n-brand/20 transition-all no-margin"
                              placeholder="Nome da etapa"
                              required
                            />

                            <!-- Remove button -->
                            <button
                              type="button"
                              class="p-1.5 text-n-slate-11 hover:text-n-ruby-9 hover:bg-n-ruby-9/10 rounded-lg transition-colors cursor-pointer border-0 bg-transparent flex-shrink-0"
                              :disabled="newPipeline.stages.length <= 3"
                              @click="removeStageObject(stage)"
                            >
                              <fluent-icon icon="dismiss" size="12" />
                            </button>
                          </div>
                        </template>
                      </draggable>

                      <!-- Done Group Draggable -->
                      <draggable
                        v-if="group.key === 'done'"
                        v-model="doneStages"
                        class="space-y-2"
                        handle=".drag-handle"
                        item-key="position"
                      >
                        <template #item="{ element: stage, index }">
                          <div
                            class="flex items-center gap-2 bg-n-solid-2 p-1.5 border border-n-weak rounded-xl shadow-sm hover:border-n-brand/20 transition-all"
                          >
                            <!-- Drag Handle -->
                            <span class="drag-handle i-ph-dots-six-vertical size-3.5 text-n-slate-9 cursor-move flex-shrink-0 inline-flex items-center justify-center" />
                            
                            <!-- Custom Color Picker Circle -->
                            <div class="relative flex items-center justify-center flex-shrink-0">
                              <div
                                class="w-5 h-5 rounded-full border border-black/10 cursor-pointer shadow-inner hover:scale-105 transition-transform"
                                :style="{ backgroundColor: getStageColor(stage) }"
                                @click="$refs[`colorPicker_${group.key}_${index}`][0].click()"
                              />
                              <input
                                :ref="`colorPicker_${group.key}_${index}`"
                                type="color"
                                v-model="stage.color"
                                class="absolute inset-0 opacity-0 w-5 h-5 pointer-events-none"
                              />
                            </div>

                            <!-- Stage Name input -->
                            <input
                              v-model="stage.name"
                              type="text"
                              class="flex-1 min-w-0 px-2.5 py-1.5 text-xs border border-n-weak rounded-lg bg-n-solid-2 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:border-n-brand focus:ring-1 focus:ring-n-brand/20 transition-all no-margin"
                              placeholder="Nome da etapa"
                              required
                            />

                          </div>
                        </template>
                      </draggable>

                      <!-- Closed Group Draggable -->
                      <draggable
                        v-if="group.key === 'closed'"
                        v-model="closedStages"
                        class="space-y-2"
                        handle=".drag-handle"
                        item-key="position"
                      >
                        <template #item="{ element: stage, index }">
                          <div
                            class="flex items-center gap-2 bg-n-solid-2 p-1.5 border border-n-weak rounded-xl shadow-sm hover:border-n-brand/20 transition-all"
                          >
                            <!-- Drag Handle -->
                            <span class="drag-handle i-ph-dots-six-vertical size-3.5 text-n-slate-9 cursor-move flex-shrink-0 inline-flex items-center justify-center" />
                            
                            <!-- Custom Color Picker Circle -->
                            <div class="relative flex items-center justify-center flex-shrink-0">
                              <div
                                class="w-5 h-5 rounded-full border border-black/10 cursor-pointer shadow-inner hover:scale-105 transition-transform"
                                :style="{ backgroundColor: getStageColor(stage) }"
                                @click="$refs[`colorPicker_${group.key}_${index}`][0].click()"
                              />
                              <input
                                :ref="`colorPicker_${group.key}_${index}`"
                                type="color"
                                v-model="stage.color"
                                class="absolute inset-0 opacity-0 w-5 h-5 pointer-events-none"
                              />
                            </div>

                            <!-- Stage Name input -->
                            <input
                              v-model="stage.name"
                              type="text"
                              class="flex-1 min-w-0 px-2.5 py-1.5 text-xs border border-n-weak rounded-lg bg-n-solid-2 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:border-n-brand focus:ring-1 focus:ring-n-brand/20 transition-all no-margin"
                              placeholder="Nome da etapa"
                              required
                            />

                          </div>
                        </template>
                      </draggable>
                    </div>
                  </div>
                </div>
              </div>


            <!-- TAB 2: VISIBILIDADE -->
            <div v-if="activeTab === 'visibility'" class="space-y-5 animate-fadeIn">
              <div>
                <h4 class="text-sm font-semibold text-n-slate-12 m-0 mb-1">
                  {{ $t('CRM.PIPELINES.FORM.VISIBILITY_TITLE') }}
                </h4>
                <p class="text-xs text-n-slate-11 m-0 leading-relaxed">
                  {{ $t('CRM.PIPELINES.FORM.VISIBILITY_HELP') }}
                </p>
              </div>

              <div class="space-y-4">
                <div>
                  <select
                    v-model="newPipeline.visibility"
                    class="w-full px-3 py-2.5 text-sm border border-n-weak rounded-xl bg-n-solid-2 text-n-slate-12 focus:outline-none focus:border-n-brand shadow-sm"
                  >
                    <option value="public">{{ $t('CRM.PIPELINES.FORM.VISIBILITY_PUBLIC') }}</option>
                    <option value="restricted">{{ $t('CRM.PIPELINES.FORM.VISIBILITY_RESTRICTED') }}</option>
                  </select>
                </div>

                <div v-if="newPipeline.visibility === 'restricted'" class="bg-n-solid-2 p-4 border border-n-weak rounded-2xl">
                  <label class="block text-xs font-bold text-n-slate-12 mb-2.5 uppercase tracking-wider">
                    {{ $t('CRM.PIPELINES.FORM.ALLOWED_TEAMS') }}
                  </label>
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                    <label
                      v-for="team in teams"
                      :key="team.id"
                      class="flex items-center gap-2 text-xs text-n-slate-11 hover:text-n-slate-12 cursor-pointer m-0"
                    >
                      <input
                        type="checkbox"
                        :value="team.id"
                        :checked="newPipeline.allowed_team_ids.includes(team.id)"
                        @change="toggleTeam(team.id)"
                        class="w-4 h-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                      />
                      {{ team.name }}
                    </label>
                  </div>
                </div>
              </div>
            </div>


            <!-- TAB 3: MOTIVOS DE PERDA -->
            <div v-if="activeTab === 'lost_reasons'" class="space-y-5 animate-fadeIn">
              <div>
                <h4 class="text-sm font-semibold text-n-slate-12 m-0 mb-1">
                  {{ $t('CRM.PIPELINES.FORM.LOST_REASONS_TITLE') }}
                </h4>
                <p class="text-xs text-n-slate-11 m-0 leading-relaxed">
                  {{ $t('CRM.PIPELINES.FORM.LOST_REASONS_HELP') }}
                </p>
              </div>

              <div class="space-y-4">
                <div class="space-y-2">
                  <div
                    v-for="(reason, idx) in newPipeline.lost_reasons"
                    :key="idx"
                    class="flex items-center gap-2 bg-n-solid-2 p-1.5 border border-n-weak rounded-xl shadow-sm hover:border-n-brand/20 transition-all"
                  >
                    <input
                      v-model="newPipeline.lost_reasons[idx]"
                      type="text"
                      class="flex-1 min-w-0 px-2.5 py-1.5 text-xs border border-n-weak rounded-lg bg-n-solid-2 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:border-n-brand"
                      :placeholder="$t('CRM.PIPELINES.FORM.LOST_REASON_PLACEHOLDER')"
                    />
                    <button
                      type="button"
                      class="p-1.5 text-n-slate-11 hover:text-n-ruby-9 hover:bg-n-ruby-9/10 rounded-lg transition-colors cursor-pointer border-0 bg-transparent flex-shrink-0"
                      @click="removeLostReason(idx)"
                    >
                      <fluent-icon icon="dismiss" size="12" />
                    </button>
                  </div>
                </div>
                
                <button
                  type="button"
                  class="flex items-center justify-center gap-1.5 w-full px-3 py-2.5 text-xs font-semibold text-woot-500 hover:text-woot-600 bg-woot-500/10 hover:bg-woot-500/20 rounded-xl transition-all cursor-pointer border-0"
                  @click="addLostReason"
                >
                  <fluent-icon icon="add" size="12" />
                  {{ $t('CRM.PIPELINES.FORM.ADD_LOST_REASON') }}
                </button>
              </div>
            </div>

          </div>
        </div>

        <!-- Footer -->
        <div class="flex justify-end gap-2 pt-4 border-t border-n-weak mt-4">
          <button
            class="px-4 py-2 text-sm font-semibold text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-1 rounded-xl transition-colors cursor-pointer border-0 bg-transparent"
            @click.prevent="closeCreateModal"
          >
            {{ $t('CRM.CANCEL') }}
          </button>
          <button
            type="submit"
            class="flex items-center justify-center px-4 py-2 text-sm font-semibold text-white bg-woot-500 hover:bg-woot-600 active:bg-woot-800 rounded-xl transition-colors cursor-pointer shadow-md shadow-woot-500/10 hover:shadow-lg"
            :class="{ 'opacity-50 cursor-not-allowed': uiFlags.isCreating }"
            :disabled="uiFlags.isCreating"
          >
            <span>{{ $t('CRM.CREATE') }}</span>
          </button>
        </div>
      </form>
    </div>
  </woot-modal>

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
            v-for="pipeline in pipelines"
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
import Draggable from 'vuedraggable';
import DealDrawer from './components/DealDrawer.vue';
import DealForm from './components/DealForm.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { BaseTable, BaseTableRow, BaseTableCell } from 'dashboard/components-next/table';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import {
  formatDealValue,
  DEFAULT_CRM_CURRENCY,
} from 'dashboard/helper/crmCurrency';
import { buildDefaultPipeline, STAGE_TYPE_COLORS } from './constants';

export default {
  name: 'DealsIndex',
  components: {
    Draggable,
    DealDrawer,
    DealForm,
    Button,
    BaseTable,
    BaseTableRow,
    BaseTableCell,
    Avatar,
  },
  data() {
    return {
      showCreateModal: false,
      isRedirecting: true,
      searchQuery: '',
      showCreateDealModal: false,
      showDealDrawer: false,
      selectedDeal: null,
      selectedDealIds: [],
      showDeleteModal: false,
      showBulkActionsDropdown: false,
      showBulkMoveModal: false,
      bulkMoveExpandedPipelineId: null,
      dealToDelete: null,
      isBulkDelete: false,
      newPipeline: buildDefaultPipeline(false),
      activeTab: 'stages',
      stageGroups: [
        { key: 'not_started', label: 'Entrada', dotColor: 'bg-n-brand' },
        { key: 'active', label: 'Ativas', dotColor: 'bg-n-amber-11' },
        { key: 'done', label: 'Done', dotColor: 'bg-n-teal-11' },
        { key: 'closed', label: 'Closed', dotColor: 'bg-n-ruby-11' },
      ],
    };
  },
  computed: {
    ...mapGetters({
      pipelines: 'pipelines/getPipelines',
      uiFlags: 'pipelines/getUIFlags',
      teams: 'teams/getTeams',
      deals: 'deals/getDeals',
      dealsUiFlags: 'deals/getUIFlags',
      agents: 'agents/getAgents',
      currentAccount: 'getCurrentAccount',
    }),
    defaultPipeline() {
      return this.pipelines.find(p => p.is_default) || this.pipelines[0];
    },
    tableHeaders() {
      return [
        '',
        'Negócio',
        'Valor',
        'Contato',
        'Pipeline',
        'Etapa',
        'Responsável',
        'Status',
        'Ações',
      ];
    },
    isAllSelected() {
      if (this.filteredDeals.length === 0) return false;
      return this.filteredDeals.every(deal => this.selectedDealIds.includes(deal.id));
    },
    isSomeSelected() {
      if (this.filteredDeals.length === 0) return false;
      return this.filteredDeals.some(deal => this.selectedDealIds.includes(deal.id));
    },
    filteredDeals() {
      if (!this.searchQuery) return this.deals;
      const query = this.searchQuery.toLowerCase();
      return this.deals.filter(deal => {
        const titleMatch = deal.title?.toLowerCase().includes(query);
        const contactMatch = deal.contact?.name?.toLowerCase().includes(query);
        return titleMatch || contactMatch;
      });
    },

    notStartedStages: {
      get() {
        return this.newPipeline.stages.filter(s => s.stage_type === 'not_started');
      },
      set(newStages) {
        this.updateGroupStages('not_started', newStages);
      }
    },
    activeStages: {
      get() {
        return this.newPipeline.stages.filter(s => s.stage_type === 'active');
      },
      set(newStages) {
        this.updateGroupStages('active', newStages);
      }
    },
    doneStages: {
      get() {
        return this.newPipeline.stages.filter(s => s.stage_type === 'done');
      },
      set(newStages) {
        this.updateGroupStages('done', newStages);
      }
    },
    closedStages: {
      get() {
        return this.newPipeline.stages.filter(s => s.stage_type === 'closed');
      },
      set(newStages) {
        this.updateGroupStages('closed', newStages);
      }
    },
  },
  async mounted() {
    this.isRedirecting = true;
    try {
      await this.fetchPipelines();
      if (this.$route.name === 'deals_index') {
        this.isRedirecting = false;
        await this.fetchDealsAction({ pipelineId: null, stageId: null });
        this.fetchAgents();
      } else {
        this.redirectToDefaultPipeline();
      }
    } catch (error) {
      this.isRedirecting = false;
    }
    document.addEventListener('click', this.handleClickOutsideBulk);
  },
  beforeUnmount() {
    document.removeEventListener('click', this.handleClickOutsideBulk);
  },
  methods: {
    ...mapActions({
      fetchPipelines: 'pipelines/get',
      createPipelineAction: 'pipelines/create',
      fetchDealsAction: 'deals/get',
      deleteDealAction: 'deals/delete',
      fetchAgents: 'agents/get',
      updateDeal: 'deals/update',
      createDeal: 'deals/create',
    }),
    getStagesByGroup(groupKey) {
      return this.newPipeline.stages.filter(s => s.stage_type === groupKey);
    },
    getStageColor(stage) {
      return stage.color || STAGE_TYPE_COLORS[stage.stage_type] || STAGE_TYPE_COLORS.active;
    },
    updateGroupStages(groupKey, newStages) {
      const otherStages = this.newPipeline.stages.filter(s => s.stage_type !== groupKey);
      this.newPipeline.stages = [...otherStages, ...newStages];
    },
    removeStageObject(stage) {
      const idx = this.newPipeline.stages.findIndex(s => s === stage);
      if (idx > -1) {
        this.newPipeline.stages.splice(idx, 1);
      }
    },
    addStageByGroup(groupKey) {
      let defaultColor = '#3b82f6';
      let defaultWinProbability = 50;
      if (groupKey === 'not_started') {
        defaultColor = '#3b82f6';
        defaultWinProbability = 10;
      } else if (groupKey === 'active') {
        defaultColor = '#eab308';
        defaultWinProbability = 50;
      } else if (groupKey === 'done') {
        defaultColor = '#22c55e';
        defaultWinProbability = 100;
      } else if (groupKey === 'closed') {
        defaultColor = '#ef4444';
        defaultWinProbability = 0;
      }
      this.newPipeline.stages.push({
        name: '',
        color: defaultColor,
        stage_type: groupKey,
        win_probability: defaultWinProbability,
        position: this.newPipeline.stages.length + 1,
      });
    },
    redirectToDefaultPipeline() {
      if (!this.pipelines.length) {
        this.isRedirecting = false;
        return;
      }

      const defaultPipeline =
        this.pipelines.find(p => p.is_default) || this.pipelines[0];
      this.openPipeline(defaultPipeline);
    },
    openPipeline(pipeline) {
      this.$router.push({
        name: 'deals_kanban',
        params: {
          accountId: this.$route.params.accountId,
          pipelineId: pipeline.id,
        },
      });
    },
    openCreatePipelineModal() {
      this.showCreateModal = true;
    },
    closeCreateModal() {
      this.showCreateModal = false;
      this.newPipeline = buildDefaultPipeline(false);
      this.activeTab = 'stages';
    },
    addLostReason() {
      this.newPipeline.lost_reasons.push('');
    },
    removeLostReason(index) {
      this.newPipeline.lost_reasons.splice(index, 1);
    },
    toggleTeam(teamId) {
      const idx = this.newPipeline.allowed_team_ids.indexOf(teamId);
      if (idx > -1) {
        this.newPipeline.allowed_team_ids.splice(idx, 1);
      } else {
        this.newPipeline.allowed_team_ids.push(teamId);
      }
    },
    removeStage(index) {
      this.newPipeline.stages.splice(index, 1);
    },
    async createPipeline() {
      try {
        const payload = {
          name: this.newPipeline.name,
          is_default: this.newPipeline.is_default,
          visibility: this.newPipeline.visibility,
          lost_reasons: this.newPipeline.lost_reasons,
          allowed_team_ids: this.newPipeline.allowed_team_ids,
          stages_attributes: this.newPipeline.stages.map((stage, index) => ({
            name: stage.name,
            color: stage.color,
            stage_type: stage.stage_type || 'active',
            position: index + 1,
            win_probability: stage.win_probability,
            rotting_days: stage.rotting_days,
          })),
        };
        const pipeline = await this.createPipelineAction(payload);
        this.$toast.success(this.$t('CRM.PIPELINES.CREATE_SUCCESS'));
        this.closeCreateModal();
        this.openPipeline(pipeline);
      } catch (error) {
        this.$toast.error(
          error.message || this.$t('CRM.PIPELINES.CREATE_ERROR')
        );
      }
    },
    currencyValue(value) {
      return formatDealValue(
        value,
        this.currentAccount?.settings?.crm_currency || DEFAULT_CRM_CURRENCY
      );
    },

    getDealStageColor(deal) {
      if (deal.stage && deal.stage.color) return deal.stage.color;
      return '#3b82f6';
    },
    getStatusBadgeClass(status) {
      if (status === 'won') return 'bg-n-teal-3 text-n-teal-11 ring-n-teal-5';
      if (status === 'lost') return 'bg-n-ruby-3 text-n-ruby-11 ring-n-ruby-5';
      return 'bg-n-brand/10 text-n-brand ring-n-brand/20';
    },
    getStatusLabel(status) {
      if (status === 'won') return 'Ganho';
      if (status === 'lost') return 'Perdido';
      return 'Aberto';
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
    deleteDeal(deal) {
      this.dealToDelete = deal;
      this.isBulkDelete = false;
      this.showDeleteModal = true;
    },
    openCreateDealModal() {
      this.showCreateDealModal = true;
    },
    closeCreateDealModal() {
      this.showCreateDealModal = false;
    },
    async onDealCreated() {
      this.closeCreateDealModal();
      this.$toast.success('Negócio criado com sucesso.');
      await this.fetchDealsAction({ pipelineId: null, stageId: null });
    },
    toggleSelectDeal(dealId) {
      const idx = this.selectedDealIds.indexOf(dealId);
      if (idx > -1) {
        this.selectedDealIds.splice(idx, 1);
      } else {
        this.selectedDealIds.push(dealId);
      }
    },
    toggleSelectAll() {
      if (this.isAllSelected) {
        const filteredIds = this.filteredDeals.map(deal => deal.id);
        this.selectedDealIds = this.selectedDealIds.filter(id => !filteredIds.includes(id));
      } else {
        const filteredIds = this.filteredDeals.map(deal => deal.id);
        const union = new Set([...this.selectedDealIds, ...filteredIds]);
        this.selectedDealIds = Array.from(union);
      }
    },
    clearSelection() {
      this.selectedDealIds = [];
    },
    deleteSelectedDeals() {
      this.showBulkActionsDropdown = false;
      this.isBulkDelete = true;
      this.dealToDelete = null;
      this.showDeleteModal = true;
    },
    closeDeleteModal() {
      this.showDeleteModal = false;
      this.dealToDelete = null;
      this.isBulkDelete = false;
    },
    async confirmDeleteDeal() {
      try {
        if (this.isBulkDelete) {
          await Promise.all(this.selectedDealIds.map(id => this.deleteDealAction(id)));
          this.$toast.success('Negócio(s) excluído(s) com sucesso.');
          this.selectedDealIds = [];
        } else if (this.dealToDelete) {
          await this.deleteDealAction(this.dealToDelete.id);
          this.$toast.success('Negócio excluído com sucesso.');
        }
        await this.fetchDealsAction({ pipelineId: null, stageId: null });
      } catch (error) {
        this.$toast.error('Erro ao excluir negócio(s).');
      } finally {
        this.closeDeleteModal();
      }
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
      this.bulkMoveExpandedPipelineId = this.pipelines[0]?.id;
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
        await this.fetchDealsAction({ pipelineId: null, stageId: null });
      } catch (error) {
        this.$toast.error('Erro ao mover os negócios.');
      }
    },
    exportDeals() {
      this.showBulkActionsDropdown = false;
      const selectedDeals = this.deals.filter(d => this.selectedDealIds.includes(d.id));
      if (selectedDeals.length === 0) return;

      const headers = ['ID', 'Negocio', 'Contato', 'E-mail', 'Telefone', 'Pipeline', 'Etapa', 'Responsavel', 'Status', 'Criado Em'];
      const rows = selectedDeals.map(d => [
        d.id,
        d.title || '',
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

          const pipeline = this.defaultPipeline;
          const stageId = pipeline?.stages?.[0]?.id;
          if (!stageId) {
            this.$toast.error('Nenhum funil ou etapa ativa encontrada para importar.');
            return;
          }

          this.$toast.info('Iniciando importação de negócios...');
          let successCount = 0;

          for (let i = 1; i < lines.length; i++) {
            const cols = lines[i].split(',').map(c => c.replace(/^"|"$/g, '').trim());
            const title = cols[titleIdx];
            if (!title) continue;

            const contactName = contactIdx !== -1 ? cols[contactIdx] : 'Cliente Importado';

            let contactId = null;
            try {
              const newContact = await this.$store.dispatch('contacts/create', { name: contactName });
              contactId = newContact.id;
            } catch (err) {
              contactId = this.deals[0]?.contact_id || 1;
            }

            try {
              await this.createDeal({
                title,
                stage_id: stageId,
                contact_id: contactId,
              });
              successCount++;
            } catch (err) {
              // Ignore row error
            }
          }

          this.$toast.success(`${successCount} negócio(s) importado(s) com sucesso!`);
          await this.fetchDealsAction({ pipelineId: null, stageId: null });
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
.animate-fadeIn {
  animation: fadeIn 0.4s ease-out;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>
