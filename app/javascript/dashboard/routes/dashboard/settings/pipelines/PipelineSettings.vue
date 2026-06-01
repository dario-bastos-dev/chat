<template>
  <SettingsLayout
    :is-loading="isLoading"
    :no-records-found="!pipelines.length"
    :loading-message="$t('CRM.LOADING')"
    :no-records-message="$t('CRM.PIPELINES.EMPTY.TITLE')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('CRM.PIPELINES.TITLE')"
        :description="$t('CRM.PIPELINES.SUBTITLE')"
        search-placeholder="Pesquisar pipelines..."
        feature-name="pipelines"
      >
        <template v-if="pipelines.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ pipelines.length }} {{ pipelines.length === 1 ? 'pipeline' : 'pipelines' }}
          </span>
        </template>
        <template #actions>
          <Button
            :label="$t('CRM.PIPELINES.CREATE')"
            size="sm"
            class="rounded-xl font-semibold shadow-md shadow-woot-500/10 cursor-pointer"
            @click="openAddPipelineModal"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="filteredPipelines"
        :no-data-message="
          searchQuery ? 'Nenhum pipeline correspondente encontrado.' : $t('CRM.PIPELINES.EMPTY.TITLE')
        "
      >
        <template #row="{ items }">
          <BaseTableRow v-for="pipeline in items" :key="pipeline.id" :item="pipeline">
            <template #default>
              <!-- Nome + Badge Default -->
              <BaseTableCell class="max-w-0 min-w-0">
                <div class="flex items-center gap-2 min-w-0">
                  <span class="text-body-main text-n-slate-12 font-medium truncate block">
                    {{ pipeline.name }}
                  </span>
                  <span v-if="pipeline.is_default" class="text-[9px] font-bold text-woot-500 bg-woot-500/10 px-2 py-0.5 rounded-full ring-1 ring-woot-500/20 uppercase tracking-wider flex-shrink-0">
                    {{ $t('CRM.PIPELINES.DEFAULT') }}
                  </span>
                </div>
              </BaseTableCell>

              <!-- Etapas -->
              <BaseTableCell class="max-w-0">
                <span class="text-body-main text-n-slate-11">
                  {{ pipeline.stages ? pipeline.stages.length : 0 }} etapas
                </span>
              </BaseTableCell>

              <!-- Negócios -->
              <BaseTableCell class="max-w-0">
                <span class="text-body-main text-n-slate-11">
                  {{ pipeline.deals_count || 0 }} negócios
                </span>
              </BaseTableCell>

              <!-- Visibilidade -->
              <BaseTableCell class="max-w-0">
                <span class="text-body-main text-n-slate-11 capitalize">
                  {{ pipeline.visibility === 'restricted' ? 'Restrito' : 'Público' }}
                </span>
              </BaseTableCell>

              <!-- Ações -->
              <BaseTableCell align="end" class="w-24">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('CRM.UPDATE')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    class="rounded-lg cursor-pointer hover:bg-n-alpha-1"
                    @click="editPipeline(pipeline)"
                  />
                  <Button
                    v-tooltip.top="$t('CRM.DELETE')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2 rounded-lg cursor-pointer"
                    @click="deletePipeline(pipeline)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>
  </SettingsLayout>

  <!-- Add/Edit Pipeline Modal -->
  <woot-modal v-model:show="showModal" :on-close="closeModal" size="modal-big">
    <div class="p-6 min-w-[400px] sm:min-w-[700px] lg:min-w-[850px] bg-n-solid-1 text-n-slate-12">
      <!-- Title Input (Header) -->
      <div class="pb-4 border-b border-n-weak mb-5 flex items-center justify-between">
        <input
          v-model="currentPipeline.name"
          type="text"
          class="text-xl font-bold bg-transparent border-0 border-b border-transparent hover:border-n-weak focus:border-n-brand focus:outline-none transition-all px-1 py-0.5 w-full md:max-w-[32%] text-n-slate-12 placeholder:text-n-slate-9"
          placeholder="Nome do Pipeline..."
          required
        />
      </div>

      <form @submit.prevent="savePipeline" class="space-y-6">
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
              <label class="flex items-center gap-2 px-2 py-1 text-xs font-semibold text-n-slate-11 cursor-pointer m-0" :class="{ 'opacity-60 cursor-not-allowed': isDefaultCheckboxDisabled }">
                <input
                  type="checkbox"
                  v-model="currentPipeline.is_default"
                  :disabled="isDefaultCheckboxDisabled"
                  class="w-3.5 h-3.5 rounded border-n-weak text-n-brand focus:ring-n-brand cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
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
                          class="flex items-center gap-2 bg-n-solid-2 p-1.5 border border-n-weak rounded-xl shadow-sm hover:border-n-brand/20 transition-all animate-fadeIn"
                        >
                          <!-- Drag Handle -->
                          <span class="drag-handle i-ph-dots-six-vertical size-3.5 text-n-slate-9 cursor-move flex-shrink-0 inline-flex items-center justify-center" />
                          
                          <!-- Custom Color Picker Circle -->
                          <div class="relative flex items-center justify-center flex-shrink-0">
                            <div
                              class="w-5 h-5 rounded-full border border-black/10 cursor-pointer shadow-inner hover:scale-105 transition-transform"
                              :style="{ backgroundColor: getStageColor(stage) }"
                              @click="$refs[`editColorPicker_${group.key}_${index}`][0].click()"
                            ></div>
                            <input
                              :ref="`editColorPicker_${group.key}_${index}`"
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
                          class="flex items-center gap-2 bg-n-solid-2 p-1.5 border border-n-weak rounded-xl shadow-sm hover:border-n-brand/20 transition-all animate-fadeIn"
                        >
                          <!-- Drag Handle -->
                          <span class="drag-handle i-ph-dots-six-vertical size-3.5 text-n-slate-9 cursor-move flex-shrink-0 inline-flex items-center justify-center" />
                          
                          <!-- Custom Color Picker Circle -->
                          <div class="relative flex items-center justify-center flex-shrink-0">
                            <div
                              class="w-5 h-5 rounded-full border border-black/10 cursor-pointer shadow-inner hover:scale-105 transition-transform"
                              :style="{ backgroundColor: getStageColor(stage) }"
                              @click="$refs[`editColorPicker_${group.key}_${index}`][0].click()"
                            ></div>
                            <input
                              :ref="`editColorPicker_${group.key}_${index}`"
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
                            class="p-1.5 text-n-slate-11 hover:text-n-ruby-9 rounded-lg transition-colors cursor-pointer border-0 bg-transparent flex-shrink-0"
                            :disabled="currentPipeline.stages.length <= 3"
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
                          class="flex items-center gap-2 bg-n-solid-2 p-1.5 border border-n-weak rounded-xl shadow-sm hover:border-n-brand/20 transition-all animate-fadeIn"
                        >
                          <!-- Drag Handle -->
                          <span class="drag-handle i-ph-dots-six-vertical size-3.5 text-n-slate-9 cursor-move flex-shrink-0 inline-flex items-center justify-center" />
                          
                          <!-- Custom Color Picker Circle -->
                          <div class="relative flex items-center justify-center flex-shrink-0">
                            <div
                              class="w-5 h-5 rounded-full border border-black/10 cursor-pointer shadow-inner hover:scale-105 transition-transform"
                              :style="{ backgroundColor: getStageColor(stage) }"
                              @click="$refs[`editColorPicker_${group.key}_${index}`][0].click()"
                            ></div>
                            <input
                              :ref="`editColorPicker_${group.key}_${index}`"
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
                          class="flex items-center gap-2 bg-n-solid-2 p-1.5 border border-n-weak rounded-xl shadow-sm hover:border-n-brand/20 transition-all animate-fadeIn"
                        >
                          <!-- Drag Handle -->
                          <span class="drag-handle i-ph-dots-six-vertical size-3.5 text-n-slate-9 cursor-move flex-shrink-0 inline-flex items-center justify-center" />
                          
                          <!-- Custom Color Picker Circle -->
                          <div class="relative flex items-center justify-center flex-shrink-0">
                            <div
                              class="w-5 h-5 rounded-full border border-black/10 cursor-pointer shadow-inner hover:scale-105 transition-transform"
                              :style="{ backgroundColor: getStageColor(stage) }"
                              @click="$refs[`editColorPicker_${group.key}_${index}`][0].click()"
                            ></div>
                            <input
                              :ref="`editColorPicker_${group.key}_${index}`"
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
                    v-model="currentPipeline.visibility"
                    class="w-full px-3 py-2.5 text-sm border border-n-weak rounded-xl bg-n-solid-2 text-n-slate-12 focus:outline-none focus:border-n-brand shadow-sm"
                  >
                    <option value="public">{{ $t('CRM.PIPELINES.FORM.VISIBILITY_PUBLIC') }}</option>
                    <option value="restricted">{{ $t('CRM.PIPELINES.FORM.VISIBILITY_RESTRICTED') }}</option>
                  </select>
                </div>

                <div v-if="currentPipeline.visibility === 'restricted'" class="bg-n-solid-2 p-4 border border-n-weak rounded-2xl">
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
                        :checked="currentPipeline.allowed_team_ids.includes(team.id)"
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
                    v-for="(reason, idx) in currentPipeline.lost_reasons"
                    :key="idx"
                    class="flex items-center gap-2 bg-n-solid-2 p-1.5 border border-n-weak rounded-xl shadow-sm hover:border-n-brand/20 transition-all"
                  >
                    <input
                      v-model="currentPipeline.lost_reasons[idx]"
                      type="text"
                      class="flex-1 min-w-0 px-2.5 py-1.5 text-xs border border-n-weak rounded-lg bg-n-solid-2 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:border-n-brand"
                      :placeholder="$t('CRM.PIPELINES.FORM.LOST_REASON_PLACEHOLDER')"
                    />
                    <button
                      type="button"
                      class="p-1.5 text-n-slate-11 hover:text-n-ruby-9 rounded-lg transition-colors cursor-pointer border-0 bg-transparent flex-shrink-0"
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
            @click.prevent="closeModal"
          >
            {{ $t('CRM.CANCEL') }}
          </button>
          <button
            type="submit"
            class="flex items-center justify-center px-4 py-2 text-sm font-semibold text-white bg-woot-500 hover:bg-woot-600 active:bg-woot-800 rounded-xl transition-colors cursor-pointer shadow-md shadow-woot-500/10"
            :class="{ 'opacity-50 cursor-not-allowed': isSaving }"
            :disabled="isSaving"
          >
            <span>{{ isEditing ? $t('CRM.UPDATE') : $t('CRM.CREATE') }}</span>
          </button>
        </div>
      </form>
    </div>
  </woot-modal>

  <!-- Delete Pipeline Modal -->
  <woot-delete-modal
    v-if="showDeleteModal"
    v-model:show="showDeleteModal"
    :title="$t('CRM.PIPELINES.DELETE_CONFIRM_TITLE')"
    :message="$t('CRM.PIPELINES.DELETE_CONFIRM_MESSAGE')"
    :confirm-text="$t('CRM.DELETE')"
    :reject-text="$t('CRM.CANCEL')"
    :on-confirm="confirmDeletePipeline"
    :on-close="closeDeleteModal"
  />
</template>

<script>
import { mapGetters, mapActions } from 'vuex';
import Spinner from 'shared/components/Spinner.vue';
import Draggable from 'vuedraggable';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { BaseTable, BaseTableRow, BaseTableCell } from 'dashboard/components-next/table';
import { useAlert } from 'dashboard/composables';

export default {
  components: {
    Spinner,
    Draggable,
    SettingsLayout,
    BaseSettingsHeader,
    Button,
    BaseTable,
    BaseTableRow,
    BaseTableCell,
  },
  data() {
    return {
      isLoading: false,
      isSaving: false,
      showModal: false,
      showDeleteModal: false,
      pipelineToDelete: null,
      searchQuery: '',
      currentPipeline: {
        name: '',
        is_default: false,
        stages: [],
        lost_reasons: [],
        visibility: 'public',
        allowed_team_ids: [],
      },
      isEditing: false,
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
      teams: 'teams/getTeams',
    }),
    filteredPipelines() {
      if (!this.searchQuery) return this.pipelines;
      const query = this.searchQuery.toLowerCase();
      return this.pipelines.filter(p => p.name.toLowerCase().includes(query));
    },
    isDefaultCheckboxDisabled() {
      if (this.isEditing) {
        const originalPipeline = this.pipelines.find(p => p.id === this.currentPipeline.id);
        return originalPipeline ? originalPipeline.is_default : false;
      }
      return !this.pipelines || this.pipelines.length === 0;
    },
    tableHeaders() {
      return [
        'Nome',
        'Etapas',
        'Negócios',
        'Visibilidade',
        'Ações',
      ];
    },
    notStartedStages: {
      get() {
        return this.currentPipeline.stages.filter(s => s.stage_type === 'not_started');
      },
      set(newStages) {
        this.updateGroupStages('not_started', newStages);
      }
    },
    activeStages: {
      get() {
        return this.currentPipeline.stages.filter(s => s.stage_type === 'active');
      },
      set(newStages) {
        this.updateGroupStages('active', newStages);
      }
    },
    doneStages: {
      get() {
        return this.currentPipeline.stages.filter(s => s.stage_type === 'done');
      },
      set(newStages) {
        this.updateGroupStages('done', newStages);
      }
    },
    closedStages: {
      get() {
        return this.currentPipeline.stages.filter(s => s.stage_type === 'closed');
      },
      set(newStages) {
        this.updateGroupStages('closed', newStages);
      }
    },
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
    getStagesByGroup(groupKey) {
      if (!this.currentPipeline.stages) return [];
      return this.currentPipeline.stages.filter(s => s.stage_type === groupKey);
    },
    getStageColor(stage) {
      if (stage.color) return stage.color;
      if (stage.stage_type === 'not_started') return '#3b82f6';
      if (stage.stage_type === 'done') return '#22c55e';
      if (stage.stage_type === 'closed') return '#ef4444';
      return '#eab308';
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
      this.currentPipeline.stages.push({
        name: '',
        color: defaultColor,
        stage_type: groupKey,
        win_probability: defaultWinProbability,
        position: this.currentPipeline.stages.length + 1,
      });
    },
    updateGroupStages(groupKey, newStages) {
      const otherStages = this.currentPipeline.stages.filter(s => s.stage_type !== groupKey);
      this.currentPipeline.stages = [...otherStages, ...newStages];
    },
    removeStageObject(stage) {
      const idx = this.currentPipeline.stages.findIndex(s => s === stage);
      if (idx > -1) {
        this.currentPipeline.stages.splice(idx, 1);
      }
    },
    openAddPipelineModal() {
      this.isEditing = false;
      this.activeTab = 'stages';
      const isFirstPipeline = !this.pipelines || this.pipelines.length === 0;
      this.currentPipeline = {
        name: '',
        is_default: isFirstPipeline,
        stages: [
          { name: 'Pendente', color: '#3b82f6', stage_type: 'not_started', position: 1, win_probability: 10 },
          { name: 'Aberto', color: '#eab308', stage_type: 'active', position: 2, win_probability: 50 },
          { name: 'Ganho', color: '#22c55e', stage_type: 'done', position: 3, win_probability: 100 },
          { name: 'Perdido', color: '#ef4444', stage_type: 'closed', position: 4, win_probability: 0 },
        ],
        lost_reasons: [],
        visibility: 'public',
        allowed_team_ids: [],
      };
      this.showModal = true;
    },
    editPipeline(pipeline) {
      this.isEditing = true;
      this.activeTab = 'stages';
      this.currentPipeline = JSON.parse(JSON.stringify(pipeline));
      // Backfill missing stage_types to active by default
      if (this.currentPipeline.stages) {
        this.currentPipeline.stages.forEach(s => {
          if (!s.stage_type) s.stage_type = 'active';
        });
        this.currentPipeline.stages.sort((a, b) => a.position - b.position);
      }
      this.showModal = true;
    },
    closeModal() {
      this.showModal = false;
      setTimeout(() => {
        if (!this.showModal) {
          this.currentPipeline = {
            name: '',
            is_default: false,
            stages: [],
            lost_reasons: [],
            visibility: 'public',
            allowed_team_ids: [],
          };
        }
      }, 200);
    },
    addLostReason() {
      this.currentPipeline.lost_reasons.push('');
    },
    removeLostReason(index) {
      this.currentPipeline.lost_reasons.splice(index, 1);
    },
    toggleTeam(teamId) {
      const idx = this.currentPipeline.allowed_team_ids.indexOf(teamId);
      if (idx > -1) {
        this.currentPipeline.allowed_team_ids.splice(idx, 1);
      } else {
        this.currentPipeline.allowed_team_ids.push(teamId);
      }
    },
    removeStage(index) {
      this.currentPipeline.stages.splice(index, 1);
    },
    async savePipeline() {
      this.isSaving = true;

      // Ordenar logicamente por tipo de estágio (not_started -> active -> done -> closed)
      const stageTypeOrder = {
        'not_started': 1,
        'active': 2,
        'done': 3,
        'closed': 4
      };

      const sortedStages = [...this.currentPipeline.stages].sort((a, b) => {
        const orderA = stageTypeOrder[a.stage_type] || 2;
        const orderB = stageTypeOrder[b.stage_type] || 2;
        if (orderA !== orderB) {
          return orderA - orderB;
        }
        return (a.position || 0) - (b.position || 0);
      });

      // Update positions based on sorted order
      sortedStages.forEach((stage, index) => {
        stage.position = index + 1;
      });

      this.currentPipeline.stages = sortedStages;

      try {
        if (this.isEditing) {
          const payload = {
            id: this.currentPipeline.id,
            name: this.currentPipeline.name,
            is_default: this.currentPipeline.is_default,
            visibility: this.currentPipeline.visibility,
            lost_reasons: this.currentPipeline.lost_reasons,
            allowed_team_ids: this.currentPipeline.allowed_team_ids,
            stages_attributes: this.currentPipeline.stages.map((s, idx) => ({
              id: s.id,
              name: s.name,
              color: s.color,
              stage_type: s.stage_type || 'active',
              position: idx + 1,
              win_probability: s.win_probability,
              rotting_days: s.rotting_days,
            })),
          };
          await this.updatePipeline(payload);
          useAlert(this.$t('CRM.PIPELINES.UPDATE_SUCCESS'));
        } else {
          const payload = {
            name: this.currentPipeline.name,
            is_default: this.currentPipeline.is_default,
            visibility: this.currentPipeline.visibility,
            lost_reasons: this.currentPipeline.lost_reasons,
            allowed_team_ids: this.currentPipeline.allowed_team_ids,
            stages_attributes: this.currentPipeline.stages.map((s, idx) => ({
              name: s.name,
              color: s.color,
              stage_type: s.stage_type || 'active',
              position: idx + 1,
              win_probability: s.win_probability,
              rotting_days: s.rotting_days,
            })),
          };
          await this.createPipeline(payload);
          useAlert(this.$t('CRM.PIPELINES.CREATE_SUCCESS'));
        }
        this.closeModal();
        this.$nextTick(async () => {
          try {
            await this.fetchPipelinesAction();
          } catch (e) {
            // Sincronização em background silenciada
          }
        });
      } catch (error) {
        useAlert(error.message || this.$t('CRM.PIPELINES.SAVE_ERROR'));
      } finally {
        this.isSaving = false;
      }
    },
    deletePipeline(pipeline) {
      this.pipelineToDelete = pipeline;
      this.showDeleteModal = true;
    },
    closeDeleteModal() {
      this.showDeleteModal = false;
      this.pipelineToDelete = null;
    },
    async confirmDeletePipeline() {
      if (!this.pipelineToDelete) return;
      try {
        await this.deletePipelineAction(this.pipelineToDelete.id);
        useAlert(this.$t('CRM.PIPELINES.DELETE_SUCCESS'));
        this.fetchPipelines();
      } catch (error) {
        useAlert(error.message || this.$t('CRM.PIPELINES.DELETE_ERROR'));
      } finally {
        this.closeDeleteModal();
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
