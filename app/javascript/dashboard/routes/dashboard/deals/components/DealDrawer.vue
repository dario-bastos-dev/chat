<template>
  <transition
    enter-active-class="transition duration-300 ease-out"
    enter-from-class="opacity-0"
    leave-active-class="transition duration-250 ease-in"
    leave-to-class="opacity-0"
  >
    <div v-if="isOpen" class="fixed inset-0 bg-black/40 dark:bg-black/60 z-50 flex justify-end" @click.self="$emit('close')">
      <transition
        appear
        enter-active-class="transition duration-300 ease-out transform"
        enter-from-class="translate-x-full"
        leave-active-class="transition duration-200 ease-in transform"
        leave-to-class="translate-x-full"
      >
        <div v-if="isOpen" class="w-[480px] max-w-full h-full bg-n-surface-2 border-l border-n-weak shadow-2xl flex flex-col overflow-hidden">
          <!-- Header -->
          <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak bg-n-solid-2 shrink-0">
            <div class="flex items-center gap-2 mr-4 min-w-0 flex-1">
              <input
                v-if="isEditingTitle"
                ref="titleInput"
                v-model="editTitleValue"
                type="text"
                class="w-full text-base font-semibold text-n-slate-12 bg-n-alpha-1 border border-n-brand rounded px-2 py-0.5 outline-none focus:ring-2 focus:ring-n-brand/20 h-8"
                @blur="saveTitle"
                @keydown.enter="saveTitle"
                @keydown.esc="cancelEditingTitle"
              />
              <h2
                v-else
                class="group text-base font-semibold text-n-slate-12 truncate m-0 cursor-pointer hover:bg-n-alpha-1 hover:text-n-brand px-2 py-0.5 rounded -ml-2 transition-all duration-150 flex items-center gap-1.5 max-w-full"
                title="Clique para editar o nome do negócio"
                @click="startEditingTitle"
              >
                {{ cleanTitle(deal.title) }}
                <fluent-icon icon="edit" size="12" class="opacity-0 group-hover:opacity-100 transition-opacity shrink-0 text-n-slate-11 pointer-events-none" />
              </h2>
            </div>
            <div class="flex items-center gap-1.5 shrink-0">
              <button
                class="flex items-center justify-center w-8 h-8 rounded-lg border border-n-weak bg-n-alpha-1 hover:bg-red-50 text-red-600 hover:text-red-700 transition-colors cursor-pointer"
                @click="confirmDelete"
                title="Excluir Negócio"
              >
                <fluent-icon icon="delete" size="14" />
              </button>
              <button
                class="flex items-center justify-center w-8 h-8 rounded-lg hover:bg-n-alpha-1 text-n-slate-11 hover:text-n-slate-12 transition-colors cursor-pointer border-0 bg-transparent"
                @click="$emit('close')"
                title="Fechar"
              >
                <fluent-icon icon="dismiss" size="14" />
              </button>
            </div>
          </div>

          <!-- Content -->
          <div class="flex-1 overflow-y-auto p-6">
            <!-- Status Actions -->
            <div class="flex items-center gap-3 p-4 bg-n-alpha-1 border border-n-weak rounded-xl mb-6 shrink-0">
              <button
                v-if="deal.status === 'open'"
                class="flex-1 flex items-center justify-center gap-1.5 px-4 py-2.5 text-xs font-semibold text-white bg-green-600 hover:bg-green-700 active:bg-green-800 rounded-lg transition-colors duration-150 cursor-pointer shadow-sm disabled:opacity-50"
                :disabled="isUpdating"
                @click="markAsWon"
              >
                <fluent-icon v-if="!isUpdating" icon="checkmark-circle" size="14" />
                <span v-else class="animate-spin mr-1">⌛</span>
                {{ $t('CRM.DEALS.MARK_WON') }}
              </button>
              <button
                v-if="deal.status === 'open'"
                class="flex-1 flex items-center justify-center gap-1.5 px-4 py-2.5 text-xs font-semibold text-white bg-red-600 hover:bg-red-700 active:bg-red-800 rounded-lg transition-colors duration-150 cursor-pointer shadow-sm"
                @click="openLostModal"
              >
                <fluent-icon icon="dismiss-circle" size="14" />
                {{ $t('CRM.DEALS.MARK_LOST') }}
              </button>
              <div v-if="deal.status === 'won'" class="flex flex-col gap-2 w-full">
                <div class="flex items-center gap-2 px-3 py-2 bg-n-green-3 text-n-green-11 border border-n-green-6 rounded-lg text-sm font-medium w-full justify-center">
                  <fluent-icon icon="checkmark-circle" size="16" />
                  {{ $t('CRM.DEALS.STATUS_WON') }}
                </div>
                <button
                  class="w-full flex items-center justify-center gap-1.5 px-4 py-2 text-xs font-semibold text-n-slate-12 hover:text-n-brand bg-n-alpha-1 hover:bg-n-alpha-2 active:bg-n-alpha-3 border border-n-weak hover:border-n-brand rounded-lg transition-all duration-150 cursor-pointer shadow-sm disabled:opacity-50"
                  :disabled="isUpdating"
                  @click="reopenDeal"
                >
                  <fluent-icon icon="arrow-undo" size="14" />
                  {{ $t('CRM.DEALS.REOPEN') }}
                </button>
              </div>
              <div v-if="deal.status === 'lost'" class="flex flex-col gap-2 w-full">
                <div class="flex items-center gap-2 px-3 py-2 bg-n-red-3 text-n-red-11 border border-n-red-6 rounded-lg text-sm font-medium w-full justify-center">
                  <fluent-icon icon="dismiss-circle" size="16" />
                  {{ $t('CRM.DEALS.STATUS_LOST') }}
                </div>
                <button
                  class="w-full flex items-center justify-center gap-1.5 px-4 py-2 text-xs font-semibold text-n-slate-12 hover:text-n-brand bg-n-alpha-1 hover:bg-n-alpha-2 active:bg-n-alpha-3 border border-n-weak hover:border-n-brand rounded-lg transition-all duration-150 cursor-pointer shadow-sm disabled:opacity-50"
                  :disabled="isUpdating"
                  @click="reopenDeal"
                >
                  <fluent-icon icon="arrow-undo" size="14" />
                  {{ $t('CRM.DEALS.REOPEN') }}
                </button>
              </div>
            </div>

            <!-- Deal Info / Details -->
            <div class="mb-6">
              <h3 class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider mb-3">
                {{ $t('CRM.DEALS.DETAILS') }}
              </h3>
              <div class="grid grid-cols-2 gap-4 p-4 bg-n-alpha-1 border border-n-weak rounded-xl">
                <div class="flex flex-col gap-1 relative" ref="stageSelectorContainer">
                  <span class="text-[11px] text-n-slate-11">{{ $t('CRM.DEALS.STAGE') }}</span>
                  <button
                    class="flex items-center justify-between w-full text-left text-sm font-medium text-n-slate-12 hover:text-n-brand px-3 py-2 bg-n-alpha-1 hover:bg-n-alpha-2 border border-n-weak hover:border-n-brand rounded-lg transition-all duration-150 cursor-pointer h-9 disabled:opacity-50"
                    :disabled="isUpdating"
                    @click="toggleStageDropdown"
                  >
                    <span class="truncate">{{ deal.stage?.name }}</span>
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
                    class="absolute left-0 top-full mt-1.5 z-[100] w-64 max-h-[30rem] overflow-y-auto bg-n-solid-3 border border-n-weak rounded-xl shadow-xl p-2 flex flex-col gap-1.5 text-left"
                    style="background-color: var(--bg-n-solid-3, #1c1d1f);"
                  >
                    <div
                      v-for="pipeline in allPipelines"
                      :key="pipeline.id"
                      class="flex flex-col border border-n-weak/50 rounded-lg overflow-hidden bg-n-solid-2"
                    >
                      <!-- Nome do Pipeline (Acordeão Header) -->
                      <button
                        class="flex items-center justify-between w-full px-3 py-2.5 text-xs font-bold uppercase tracking-wider bg-n-solid-2 text-n-slate-11 hover:text-n-brand transition-colors cursor-pointer"
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
                          v-for="stage in pipeline.stages"
                          :key="stage.id"
                          class="flex items-center justify-between w-full px-3.5 py-2 text-xs text-left transition-all duration-150 cursor-pointer border-l-4 hover:brightness-95 active:brightness-90 text-n-slate-12 font-medium rounded-md"
                          :style="{
                            backgroundColor: stage.color ? `${stage.color}15` : '#1f93ff15',
                            borderLeftColor: stage.color || '#1f93ff'
                          }"
                          @click="selectStageForDeal(stage.id)"
                        >
                          <span :class="{ 'font-semibold text-n-brand': (deal.stage_id || deal.stage?.id) === stage.id }">
                            {{ stage.name }}
                          </span>
                          <span
                            v-if="(deal.stage_id || deal.stage?.id) === stage.id"
                            class="text-n-brand flex shrink-0"
                          >
                            <fluent-icon icon="checkmark" size="12" />
                          </span>
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="flex flex-col gap-1">
                  <span class="text-[11px] text-n-slate-11">{{ $t('CRM.DEALS.PIPELINE') }}</span>
                  <span class="text-sm font-medium text-n-slate-12 truncate py-2">{{ deal.pipeline?.name }}</span>
                </div>
                <div class="flex flex-col gap-1">
                  <span class="text-[11px] text-n-slate-11">{{ $t('CRM.DEALS.CREATED') }}</span>
                  <span class="text-sm font-medium text-n-slate-12">{{ formatDateFull(deal.created_at) }}</span>
                </div>
                <!-- Etiquetas (Tags) do Negócio -->
                <div class="flex flex-col gap-1 relative" ref="tagSelectorContainer">
                  <span class="text-[11px] text-n-slate-11">Etiquetas</span>
                  <div
                    class="flex flex-wrap gap-1 items-center min-h-9 p-1 bg-n-alpha-1 border border-n-weak rounded-lg w-full relative"
                  >
                    <AddLabel @add="toggleTagDropdown" />
                    <woot-label
                      v-for="label in deal.labels || []"
                      :key="label"
                      :title="label"
                      show-close
                      :color="getTagColor(label)"
                      variant="smooth"
                      class="max-w-[calc(100%-0.5rem)] text-[10px]"
                      @remove="removeLabelFromDeal"
                    />

                    <!-- Dropdown de Etiquetas -->
                    <div
                      v-if="showTagDropdown"
                      class="absolute left-0 top-full mt-1.5 z-[100] w-64 max-h-52 overflow-y-auto bg-n-solid-3 border border-n-weak rounded-xl shadow-xl p-2 flex flex-col gap-0.5 text-left"
                      style="background-color: var(--bg-n-solid-3, #1c1d1f);"
                    >
                      <LabelDropdown
                        :account-labels="accountLabels"
                        :selected-labels="deal.labels || []"
                        :allow-creation="isAdmin"
                        @add="addLabelToDeal"
                        @remove="removeLabelFromDeal"
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Custom Attributes Section -->
            <div class="mb-6">
              <h3 class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider mb-3">
                Atributos do negócio
              </h3>
              <div v-if="!hasDealAttributes" class="text-sm text-n-slate-11 italic p-4 bg-n-alpha-1 border border-n-weak rounded-xl">
                <span class="block dark:text-n-slate-11 text-n-slate-11 font-medium">
                  {{ $t('CRM.DEALS.NO_CUSTOM_ATTRIBUTES') }}
                </span>
              </div>
              <div v-else class="flex flex-col border border-n-weak rounded-xl bg-n-alpha-1 divide-y divide-n-weak/50 dark:divide-n-weak/90 overflow-hidden">
                <DealCustomAttributeItem
                  v-for="attribute in processedDealAttributes"
                  :key="attribute.id"
                  :deal="deal"
                  is-editing-view
                  :attribute="attribute"
                  @updated="onCustomAttributeUpdated"
                />
              </div>
            </div>

            <!-- Contact -->
            <div class="mb-6">
              <h3 class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider mb-3">
                {{ $t('CRM.DEALS.CONTACT') }}
              </h3>
              <div class="flex items-center gap-3 p-4 bg-n-alpha-1 hover:bg-n-alpha-2 border border-n-weak rounded-xl cursor-pointer transition-all duration-150" @click="openContactPage">
                <Avatar
                  :src="deal.contact?.avatar_url"
                  :name="deal.contact?.name"
                  :size="40"
                  class="shrink-0"
                />
                <div class="flex flex-col flex-1 min-w-0">
                  <span class="font-medium text-n-slate-12 text-sm truncate">{{ deal.contact?.name }}</span>
                  <span class="text-xs text-n-slate-11 truncate">{{ deal.contact?.email }}</span>
                  <span class="text-xs text-n-slate-11 truncate">{{ deal.contact?.phone_number }}</span>
                </div>
                <fluent-icon icon="chevron-right" size="16" class="text-n-slate-11 shrink-0" />
              </div>
            </div>

            <!-- Assignee -->
            <div class="mb-6 relative" ref="assigneeSelectorContainer">
              <h3 class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider mb-3">
                {{ $t('CRM.DEALS.ASSIGNEE') }}
              </h3>
              <!-- Botão interativo do Responsável -->
              <button
                class="w-full flex items-center justify-between gap-3 p-3 bg-n-alpha-1 hover:bg-n-alpha-2 border border-n-weak hover:border-n-brand rounded-xl cursor-pointer text-left transition-all duration-150 h-16 disabled:opacity-50"
                :disabled="isUpdating"
                @click="toggleAssigneeDropdown"
              >
                <div v-if="deal.assignee" class="flex items-center gap-3 min-w-0">
                  <Avatar
                    :src="deal.assignee?.avatar_url"
                    :name="deal.assignee?.name"
                    :size="32"
                    class="shrink-0"
                  />
                  <div class="flex flex-col min-w-0">
                    <span class="font-medium text-n-slate-12 text-sm truncate">{{ deal.assignee?.name }}</span>
                    <span class="text-xs text-n-slate-11 truncate">{{ deal.assignee?.email }}</span>
                  </div>
                </div>
                <div v-else class="flex items-center gap-3">
                  <div class="w-8 h-8 rounded-full border border-dashed border-n-weak bg-n-alpha-1 flex items-center justify-center text-n-slate-10">
                    <fluent-icon icon="person" size="14" />
                  </div>
                  <span class="text-sm font-medium text-n-slate-11 italic">
                    {{ $t('CRM.DEALS.UNASSIGNED') }}
                  </span>
                </div>
                <fluent-icon icon="chevron-down" size="14" class="text-n-slate-11 shrink-0 ml-2" />
              </button>

              <!-- Dropdown de Agentes -->
              <div
                v-if="showAssigneeDropdown"
                class="absolute left-0 top-full mt-1.5 z-[100] w-64 max-h-60 overflow-y-auto bg-n-solid-3 border border-n-weak rounded-xl shadow-xl p-1.5 flex flex-col gap-0.5 text-left"
                style="background-color: var(--bg-n-solid-3, #1c1d1f);"
              >
                <!-- Opção Sem Atribuição -->
                <button
                  class="flex items-center gap-2.5 w-full px-3 py-2 text-xs font-medium text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-1 rounded-lg transition-colors cursor-pointer border-0 bg-transparent"
                  @click="selectAssigneeForDeal(null)"
                >
                  <div class="w-5 h-5 rounded-full border border-dashed border-n-weak bg-n-alpha-1 flex items-center justify-center text-n-slate-10 shrink-0">
                    <fluent-icon icon="person-delete" size="10" />
                  </div>
                  <span>Não atribuído</span>
                </button>
                <div class="h-[1px] bg-n-weak/30 my-1" />
                
                <!-- Lista de Agentes -->
                <button
                  v-for="agent in agents"
                  :key="agent.id"
                  class="flex items-center justify-between w-full px-3 py-2 text-xs text-left transition-all duration-150 cursor-pointer hover:bg-n-alpha-1 rounded-lg border-0 bg-transparent text-n-slate-12 font-medium"
                  @click="selectAssigneeForDeal(agent.id)"
                >
                  <div class="flex items-center gap-2.5 min-w-0">
                    <Avatar
                      :src="agent.avatar_url"
                      :name="agent.name"
                      :size="20"
                      class="shrink-0"
                    />
                    <span class="truncate" :class="{ 'font-semibold text-n-brand': deal.assignee_id === agent.id }">
                      {{ agent.name }}
                    </span>
                  </div>
                  <span
                    v-if="deal.assignee_id === agent.id"
                    class="text-n-brand flex shrink-0 ml-2"
                  >
                    <fluent-icon icon="checkmark" size="12" />
                  </span>
                </button>
              </div>
            </div>

            <!-- Activities -->
            <div class="mb-6">
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider m-0">
                  {{ $t('CRM.ACTIVITIES.TITLE') }}
                </h3>
                <button
                  class="flex items-center gap-1 px-3 py-1.5 text-xs font-semibold text-white bg-woot-500 hover:bg-woot-600 active:bg-woot-700 rounded-lg transition-colors duration-150 cursor-pointer shadow-sm"
                  @click="openAddActivityModal"
                >
                  <fluent-icon icon="add" size="12" />
                  {{ $t('CRM.ACTIVITIES.ADD') }}
                </button>
              </div>

              <div v-if="activities.length === 0" class="text-sm text-n-slate-11 italic text-center p-6 bg-n-alpha-1 border border-n-weak rounded-xl">
                {{ $t('CRM.ACTIVITIES.EMPTY') }}
              </div>

              <div v-else class="flex flex-col gap-3">
                <div
                  v-for="activity in activities"
                  :key="activity.id"
                  class="flex items-start gap-3 p-3 bg-n-alpha-1 border border-n-weak rounded-xl"
                  :class="{ 'opacity-60 line-through': activity.is_completed }"
                >
                  <div class="w-8 h-8 flex items-center justify-center bg-n-brand/10 text-n-brand rounded-lg shrink-0">
                    <fluent-icon
                      :icon="getActivityIcon(activity.activity_type)"
                      size="16"
                    />
                  </div>
                  <div class="flex flex-col flex-1 min-w-0 gap-1">
                    <span class="text-[10px] font-bold text-n-brand uppercase tracking-wider">
                      {{ getActivityLabel(activity.activity_type) }}
                    </span>
                    <span class="text-xs text-n-slate-12 break-words">
                      {{ activity.description }}
                    </span>
                    <span class="text-[10px] text-n-slate-11 mt-1">
                      {{ activity.user?.name }} • {{ formatDate(activity.created_at) }}
                    </span>
                  </div>
                  <woot-button
                    v-if="!activity.is_completed"
                    variant="clear"
                    size="tiny"
                    icon="checkmark"
                    class="shrink-0 text-n-slate-11 hover:text-n-green-11"
                    @click="completeActivity(activity.id)"
                  />
                </div>
              </div>
            </div>

            <!-- Linked Conversations -->
            <div class="mb-6">
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider m-0">
                  {{ $t('CRM.DEALS.CONVERSATIONS') }}
                </h3>
                <button
                  class="flex items-center gap-1 px-3 py-1.5 text-xs font-semibold text-white bg-woot-500 hover:bg-woot-600 active:bg-woot-700 rounded-lg transition-colors duration-150 cursor-pointer shadow-sm"
                  @click="openLinkConversationModal"
                >
                  <fluent-icon icon="add" size="12" />
                  {{ $t('CRM.DEALS.LINK_CONVERSATION') }}
                </button>
              </div>

              <div
                v-if="linkedConversations.length === 0"
                class="text-sm text-n-slate-11 italic text-center p-6 bg-n-alpha-1 border border-n-weak rounded-xl"
              >
                {{ $t('CRM.DEALS.NO_CONVERSATIONS') }}
              </div>

              <div v-else class="flex flex-col gap-3">
                <div
                  v-for="conv in linkedConversations"
                  :key="conv.id"
                  class="flex items-start gap-3 p-3 bg-n-alpha-1 hover:bg-n-alpha-2 border border-n-weak rounded-xl cursor-pointer transition-all duration-150"
                  @click="openConversation(conv)"
                >
                  <div class="w-8 h-8 flex items-center justify-center bg-n-brand/10 text-n-brand rounded-lg shrink-0">
                    <fluent-icon
                      :icon="getInboxIcon(conv.inbox?.channel_type)"
                      size="16"
                    />
                  </div>
                  <div class="flex flex-col flex-1 min-w-0 gap-1">
                    <div class="flex items-center gap-2">
                      <span class="text-sm font-bold text-n-slate-12">Conversa #{{ conv.display_id || conv.id }}</span>
                      <span
                        class="text-[10px] font-semibold px-2 py-0.5 rounded-full uppercase"
                        :class="
                          conv.status === 'open'
                            ? 'bg-n-green-3 text-n-green-11'
                            : conv.status === 'pending'
                            ? 'bg-n-amber-3 text-n-amber-11'
                            : 'bg-n-red-3 text-n-red-11'
                        "
                      >
                        {{ conv.status }}
                      </span>
                    </div>
                    <span class="text-xs text-n-slate-11 truncate">{{ conv.contact?.name || conv.meta?.sender?.name || '-' }}</span>
                    <span class="text-[10px] text-n-slate-11">
                      {{ conv.inbox?.name }} • {{ formatDate(conv.created_at) }}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </transition>
    </div>
  </transition>

  <!-- Edit Modal -->
  <woot-modal v-model:show="showEditModal" :on-close="closeEditModal">
    <deal-form
      :pipeline="{ stages: [deal.stage] }"
      :deal="deal"
      @close="closeEditModal"
      @updated="onDealUpdated"
    />
  </woot-modal>

  <!-- Lost Reason Modal -->
  <woot-modal v-model:show="showLostModal" :on-close="closeLostModal">
    <div class="p-6 min-w-[400px] flex flex-col gap-4 bg-n-surface-2">
      <woot-modal-header :header-title="$t('CRM.DEALS.LOST_REASON_TITLE')" />
      <div class="flex flex-col gap-1.5">
        <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.DEALS.LOST_REASON') }} *</label>
        <textarea
          v-model="lostReason"
          :placeholder="$t('CRM.DEALS.LOST_REASON_PLACEHOLDER')"
          rows="3"
          class="w-full px-3 py-2 text-sm bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-12 placeholder-n-slate-9 focus:border-n-brand focus:ring-1 focus:ring-n-brand transition-colors duration-150"
        />
      </div>
      <div class="flex justify-end gap-3 mt-4">
        <woot-button variant="clear" @click="closeLostModal">
          {{ $t('CRM.CANCEL') }}
        </woot-button>
        <woot-button
          color-scheme="alert"
          :is-loading="isUpdating"
          @click="markAsLost"
        >
          {{ $t('CRM.DEALS.MARK_LOST') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>

  <!-- Add Activity Modal -->
  <woot-modal v-model:show="showActivityModal" :on-close="closeActivityModal">
    <div class="deal-form bg-n-surface-2 p-6 rounded-2xl border border-n-weak min-w-[460px] max-w-full shadow-2xl">
      <!-- Header -->
      <div class="flex items-center justify-between pb-4 mb-5 border-b border-n-weak">
        <h2 class="text-base font-semibold text-n-slate-12 m-0 tracking-tight">
          {{ $t('CRM.ACTIVITIES.ADD') }}
        </h2>
      </div>

      <form @submit.prevent="submitActivity">
        <div class="space-y-5 pr-1">
          <!-- Tipo de Atividade -->
          <div class="flex flex-col gap-1.5">
            <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.ACTIVITIES.TYPE') }} *</label>
            <select
              v-model="newActivity.activity_type"
              required
              class="w-full text-xs md:text-sm text-n-slate-12 bg-n-alpha-1 hover:bg-n-alpha-2 focus:bg-n-alpha-2 border border-n-weak focus:border-n-brand rounded-xl h-10 px-3 transition-all duration-150 outline-none focus:ring-2 focus:ring-n-brand/20 cursor-pointer"
            >
              <option value="call">{{ $t('CRM.ACTIVITIES.TYPES.CALL') }}</option>
              <option value="email">{{ $t('CRM.ACTIVITIES.TYPES.EMAIL') }}</option>
              <option value="meeting">{{ $t('CRM.ACTIVITIES.TYPES.MEETING') }}</option>
              <option value="task">{{ $t('CRM.ACTIVITIES.TYPES.TASK') }}</option>
              <option value="note">{{ $t('CRM.ACTIVITIES.TYPES.NOTE') }}</option>
            </select>
          </div>

          <!-- Descrição -->
          <div class="flex flex-col gap-1.5">
            <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.ACTIVITIES.DESCRIPTION') }}</label>
            <textarea
              v-model="newActivity.description"
              :placeholder="$t('CRM.ACTIVITIES.DESCRIPTION_PLACEHOLDER')"
              rows="3"
              class="w-full text-xs md:text-sm text-n-slate-12 bg-n-alpha-1 hover:bg-n-alpha-2 focus:bg-n-alpha-2 border border-n-weak focus:border-n-brand rounded-xl p-3 transition-all duration-150 outline-none placeholder:text-n-slate-9 focus:ring-2 focus:ring-n-brand/20"
            />
          </div>

          <!-- Data de Vencimento -->
          <div class="flex flex-col gap-1.5">
            <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.ACTIVITIES.DUE_DATE') }}</label>
            <input
              v-model="newActivity.due_date"
              type="datetime-local"
              class="w-full text-xs md:text-sm text-n-slate-12 bg-n-alpha-1 hover:bg-n-alpha-2 focus:bg-n-alpha-2 border border-n-weak focus:border-n-brand rounded-xl h-10 px-3 transition-all duration-150 outline-none focus:ring-2 focus:ring-n-brand/20 cursor-pointer"
            />
          </div>
        </div>

        <!-- Footer -->
        <div class="flex justify-end gap-3 mt-6 pt-5 border-t border-n-weak">
          <button
            type="button"
            class="px-4.5 py-2 text-xs font-semibold rounded-xl border border-n-weak bg-n-alpha-1 text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 active:bg-n-alpha-3 transition-all duration-150 cursor-pointer shadow-sm"
            @click.prevent="closeActivityModal"
          >
            {{ $t('CRM.CANCEL') }}
          </button>
          <button
            type="submit"
            class="px-5.5 py-2 text-xs font-semibold rounded-xl text-white bg-n-brand hover:brightness-110 active:brightness-95 transition-all duration-150 cursor-pointer shadow-md border-0 flex items-center justify-center gap-1.5 disabled:opacity-50"
            :disabled="isCreatingActivity"
          >
            <woot-spinner v-if="isCreatingActivity" size="tiny" class="mr-1" />
            {{ $t('CRM.CREATE') }}
          </button>
        </div>
      </form>
    </div>
  </woot-modal>

  <!-- Link Conversation Modal -->
  <woot-modal
    v-model:show="showLinkConversationModal"
    :on-close="closeLinkConversationModal"
  >
    <div class="deal-form bg-n-surface-2 p-6 rounded-2xl border border-n-weak min-w-[460px] max-w-full shadow-2xl">
      <!-- Header -->
      <div class="flex items-center justify-between pb-4 mb-5 border-b border-n-weak">
        <h2 class="text-base font-semibold text-n-slate-12 m-0 tracking-tight">
          {{ $t('CRM.DEALS.LINK_CONVERSATION') }}
        </h2>
      </div>

      <div class="space-y-5 pr-1">
        <!-- ID da Conversa -->
        <div class="flex flex-col gap-1.5">
          <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.DEALS.CONVERSATION_ID') }}</label>
          <input
            v-model="conversationIdToLink"
            type="number"
            :placeholder="$t('CRM.DEALS.CONVERSATION_ID_PLACEHOLDER')"
            min="1"
            class="w-full text-xs md:text-sm text-n-slate-12 bg-n-alpha-1 hover:bg-n-alpha-2 focus:bg-n-alpha-2 border border-n-weak focus:border-n-brand rounded-xl h-10 px-3 transition-all duration-150 outline-none focus:ring-2 focus:ring-n-brand/20"
          />
        </div>
      </div>

      <!-- Footer -->
      <div class="flex justify-end gap-3 mt-6 pt-5 border-t border-n-weak">
        <button
          type="button"
          class="px-4.5 py-2 text-xs font-semibold rounded-xl border border-n-weak bg-n-alpha-1 text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 active:bg-n-alpha-3 transition-all duration-150 cursor-pointer shadow-sm"
          @click.prevent="closeLinkConversationModal"
        >
          {{ $t('CRM.CANCEL') }}
        </button>
        <button
          type="button"
          class="px-5.5 py-2 text-xs font-semibold rounded-xl text-white bg-n-brand hover:brightness-110 active:brightness-95 transition-all duration-150 cursor-pointer shadow-md border-0 flex items-center justify-center gap-1.5 disabled:opacity-50"
          :disabled="isLinkingConversation"
          @click="linkConversation"
        >
          <woot-spinner v-if="isLinkingConversation" size="tiny" class="mr-1" />
          {{ $t('CRM.DEALS.LINK') }}
        </button>
      </div>
    </div>
  </woot-modal>

  <!-- Delete Deal Modal -->
  <woot-delete-modal
    v-if="showDeleteModal"
    v-model:show="showDeleteModal"
    :title="$t('CRM.DEALS.DELETE_TITLE') || 'Excluir Negócio'"
    :message="$t('CRM.DEALS.DELETE_CONFIRM') || 'Tem certeza que deseja excluir este negócio? Esta ação não pode ser desfeita.'"
    :confirm-text="$t('CRM.DELETE') || 'Excluir'"
    :reject-text="$t('CRM.CANCEL') || 'Cancelar'"
    :on-confirm="executeDelete"
    :on-close="closeDeleteModal"
  />
</template>

<script>
import { mapGetters, mapActions } from 'vuex';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import DealForm from './DealForm.vue';
import DealCustomAttributeItem from './DealCustomAttributeItem.vue';
import DealsAPI from 'dashboard/api/deals';
import { format, formatDistanceToNow } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import LabelDropdown from 'shared/components/ui/label/LabelDropdown.vue';
import AddLabel from 'shared/components/ui/dropdown/AddLabel.vue';

export default {
  name: 'DealDrawer',
  components: {
    Avatar,
    DealForm,
    DealCustomAttributeItem,
    LabelDropdown,
    AddLabel,
  },
  props: {
    initialDeal: {
      type: Object,
      required: true,
    },
    isOpen: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['close', 'updated', 'deleted'],
  data() {
    return {
      activities: [],
      linkedConversations: [],
      showEditModal: false,
      showLostModal: false,
      showActivityModal: false,
      showLinkConversationModal: false,
      showDeleteModal: false,
      showStageDropdown: false,
      showAssigneeDropdown: false,
      showTagDropdown: false,
      expandedPipelineId: null,
      lostReason: '',
      isUpdating: false,
      isCreatingActivity: false,
      isLinkingConversation: false,
      conversationIdToLink: null,
      newActivity: {
        activity_type: 'note',
        description: '',
        due_date: null,
      },
      isEditingTitle: false,
      editTitleValue: '',
      localDeal: null,
    };
  },
  computed: {
    ...mapGetters({
      allPipelines: 'pipelines/getPipelines',
      dealAttributes: 'attributes/getDealAttributes',
      agents: 'agents/getAgents',
      accountLabels: 'labels/getLabels',
    }),
    storeDeal() {
      return this.$store.getters['deals/getDealById'](this.initialDeal.id);
    },
    deal() {
      return this.localDeal || this.storeDeal || this.initialDeal;
    },
    isAdmin() {
      return this.$store.getters['getCurrentRole'] === 'administrator';
    },
    hasDealAttributes() {
      return this.dealAttributes?.length > 0;
    },
    processedDealAttributes() {
      if (!this.dealAttributes?.length) return [];
      const customAttrs = this.deal.custom_attributes || {};
      return this.dealAttributes.map(attr => ({
        ...attr,
        value: customAttrs[attr.attributeKey] ?? '',
      }));
    },
  },
  watch: {
    initialDeal: {
      immediate: true,
      handler(newVal) {
        this.localDeal = newVal ? { ...newVal } : null;
      },
    },
    storeDeal: {
      handler(newVal) {
        if (newVal) {
          this.localDeal = { ...newVal };
        }
      },
      deep: true,
    },
    isOpen: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          this.fetchActivities();
          this.fetchLinkedConversations();
          if (!this.allPipelines?.length) {
            this.fetchPipelines();
          }
          this.fetchAgents();
          this.$store.dispatch('attributes/get');
          this.$store.dispatch('labels/get');
        }
      },
    },
    deal: {
      immediate: true,
      handler(newVal) {
        if (newVal?.pipeline?.id || newVal?.pipeline_id) {
          this.expandedPipelineId = newVal.pipeline?.id || newVal.pipeline_id;
        }
      },
    },
  },
  mounted() {
    document.addEventListener('click', this.handleClickOutside);
  },
  beforeUnmount() {
    document.removeEventListener('click', this.handleClickOutside);
  },
  methods: {
    ...mapActions({
      deleteDeal: 'deals/delete',
      winDeal: 'deals/win',
      loseDeal: 'deals/lose',
      updateDeal: 'deals/update',
      fetchPipelines: 'pipelines/get',
      fetchAgents: 'agents/get',
    }),
    toggleStageDropdown() {
      this.showStageDropdown = !this.showStageDropdown;
      if (this.showStageDropdown && (this.deal.pipeline?.id || this.deal.pipeline_id)) {
        this.expandedPipelineId = this.deal.pipeline?.id || this.deal.pipeline_id;
      }
    },
    togglePipelineStages(pipelineId) {
      if (this.expandedPipelineId === pipelineId) {
        this.expandedPipelineId = null;
      } else {
        this.expandedPipelineId = pipelineId;
      }
    },
    async selectStageForDeal(stageId) {
      this.showStageDropdown = false;
      this.isUpdating = true;
      try {
        const updatedDeal = await this.updateDeal({
          id: this.deal.id,
          stage_id: stageId,
        });
        if (updatedDeal) {
          this.localDeal = { ...this.localDeal, ...updatedDeal };
        }
        this.$emit('updated');
        this.$toast.success('Etapa do negócio atualizada com sucesso!');
      } catch (error) {
        this.$toast.error('Ocorreu um erro ao atualizar a etapa.');
      } finally {
        this.isUpdating = false;
      }
    },
    handleClickOutside(event) {
      const container = this.$refs.stageSelectorContainer;
      if (container && !container.contains(event.target)) {
        this.showStageDropdown = false;
      }
      const assigneeContainer = this.$refs.assigneeSelectorContainer;
      if (assigneeContainer && !assigneeContainer.contains(event.target)) {
        this.showAssigneeDropdown = false;
      }
      const tagContainer = this.$refs.tagSelectorContainer;
      if (tagContainer && !tagContainer.contains(event.target)) {
        this.showTagDropdown = false;
      }
    },
    toggleTagDropdown() {
      this.showTagDropdown = !this.showTagDropdown;
    },
    closeTagDropdown() {
      this.showTagDropdown = false;
    },
    getTagColor(title) {
      const label = this.accountLabels?.find(l => l.title === title);
      return label ? label.color : '#3b82f6';
    },
    async addLabelToDeal(label) {
      const currentLabels = this.deal.labels || [];
      if (currentLabels.includes(label.title)) return;
      const newLabels = [...currentLabels, label.title];
      await this.updateDealLabels(newLabels);
    },
    async removeLabelFromDeal(labelTitle) {
      const currentLabels = this.deal.labels || [];
      const newLabels = currentLabels.filter(l => l !== labelTitle);
      await this.updateDealLabels(newLabels);
    },
    async updateDealLabels(newLabels) {
      this.isUpdating = true;
      try {
        const updatedDeal = await this.updateDeal({
          id: this.deal.id,
          labels: newLabels,
        });
        if (updatedDeal) {
          this.localDeal = { ...this.localDeal, ...updatedDeal };
        }
        this.$emit('updated');
        this.$toast.success('Etiquetas do negócio atualizadas com sucesso!');
      } catch (error) {
        this.$toast.error('Erro ao atualizar etiquetas do negócio.');
      } finally {
        this.isUpdating = false;
      }
    },
    toggleAssigneeDropdown() {
      this.showAssigneeDropdown = !this.showAssigneeDropdown;
    },
    async selectAssigneeForDeal(agentId) {
      this.showAssigneeDropdown = false;
      this.isUpdating = true;
      try {
        const updatedDeal = await this.updateDeal({
          id: this.deal.id,
          assignee_id: agentId,
        });
        if (updatedDeal) {
          this.localDeal = { ...this.localDeal, ...updatedDeal };
        }
        this.$emit('updated');
        this.$toast.success('Responsável do negócio atualizado com sucesso!');
      } catch (error) {
        this.$toast.error('Ocorreu um erro ao atualizar o responsável.');
      } finally {
        this.isUpdating = false;
      }
    },
    async fetchActivities() {
      try {
        const response = await DealsAPI.getActivities(this.deal.id);
        this.activities = response.data;
      } catch (error) {
        console.error('Error fetching activities:', error);
      }
    },
    openEditModal() {
      this.showEditModal = true;
    },
    closeEditModal() {
      this.showEditModal = false;
    },
    onDealUpdated() {
      this.closeEditModal();
      this.$emit('updated');
    },
    onCustomAttributeUpdated(updatedDeal) {
      if (updatedDeal) {
        this.localDeal = { ...this.localDeal, ...updatedDeal };
      }
      this.$emit('updated');
    },
    confirmDelete() {
      this.showDeleteModal = true;
    },
    closeDeleteModal() {
      this.showDeleteModal = false;
    },
    async executeDelete() {
      try {
        await this.deleteDeal(this.deal.id);
        this.$emit('deleted');
      } catch (error) {
        this.$toast.error(this.$t('CRM.DEALS.DELETE_ERROR'));
      } finally {
        this.closeDeleteModal();
      }
    },
    async reopenDeal() {
      this.isUpdating = true;
      try {
        const pipelineId = this.deal.pipeline_id || this.deal.pipeline?.id;
        const pipeline = this.allPipelines.find(p => p.id === pipelineId);
        
        if (!pipeline) {
          throw new Error('Pipeline not found');
        }

        // Encontrar a primeira etapa ativa (not_started ou active)
        const activeStage = pipeline.stages.find(
          s => s.stage_type === 'not_started' || s.stage_type === 'active'
        ) || pipeline.stages[0];

        if (!activeStage) {
          throw new Error('No active stage found in pipeline');
        }

        const updatedDeal = await this.updateDeal({
          id: this.deal.id,
          stage_id: activeStage.id,
        });

        if (updatedDeal) {
          this.localDeal = { ...this.localDeal, ...updatedDeal };
        }

        this.$emit('updated');
        this.$toast.success(this.$t('CRM.DEALS.REOPEN_SUCCESS'));
      } catch (error) {
        this.$toast.error(this.$t('CRM.DEALS.REOPEN_ERROR'));
      } finally {
        this.isUpdating = false;
      }
    },
    async markAsWon() {
      this.isUpdating = true;
      try {
        await this.winDeal(this.deal.id);
        this.$emit('updated');
        this.$toast.success(this.$t('CRM.DEALS.WON_SUCCESS'));
      } catch (error) {
        this.$toast.error(this.$t('CRM.DEALS.WON_ERROR'));
      } finally {
        this.isUpdating = false;
      }
    },
    openLostModal() {
      this.showLostModal = true;
    },
    closeLostModal() {
      this.showLostModal = false;
      this.lostReason = '';
    },
    async markAsLost() {
      if (!this.lostReason.trim()) {
        this.$toast.error(this.$t('CRM.DEALS.LOST_REASON_REQUIRED'));
        return;
      }

      this.isUpdating = true;
      try {
        await this.loseDeal({ id: this.deal.id, lostReason: this.lostReason });
        this.closeLostModal();
        this.$emit('updated');
        this.$toast.success(this.$t('CRM.DEALS.LOST_SUCCESS'));
      } catch (error) {
        this.$toast.error(this.$t('CRM.DEALS.LOST_ERROR'));
      } finally {
        this.isUpdating = false;
      }
    },
    openContactPage() {
      this.$router.push({
        name: 'contacts_edit',
        params: {
          accountId: this.$route.params.accountId,
          contactId: this.deal.contact?.id,
        },
      });
    },
    openAddActivityModal() {
      this.showActivityModal = true;
    },
    closeActivityModal() {
      this.showActivityModal = false;
      this.newActivity = {
        activity_type: 'note',
        description: '',
        due_date: null,
      };
    },
    async submitActivity() {
      this.isCreatingActivity = true;
      try {
        await DealsAPI.createActivity(this.deal.id, this.newActivity);
        this.closeActivityModal();
        this.fetchActivities();
        this.$toast.success(this.$t('CRM.ACTIVITIES.CREATE_SUCCESS'));
      } catch (error) {
        this.$toast.error(this.$t('CRM.ACTIVITIES.CREATE_ERROR'));
      } finally {
        this.isCreatingActivity = false;
      }
    },
    async fetchLinkedConversations() {
      try {
        const response = await DealsAPI.getConversations(this.deal.id);
        this.linkedConversations = response.data || [];
      } catch (error) {
        this.linkedConversations = [];
      }
    },
    openLinkConversationModal() {
      this.showLinkConversationModal = true;
    },
    closeLinkConversationModal() {
      this.showLinkConversationModal = false;
      this.conversationIdToLink = null;
    },
    async linkConversation() {
      if (!this.conversationIdToLink) return;
      this.isLinkingConversation = true;
      try {
        await DealsAPI.linkConversation(
          this.deal.id,
          this.conversationIdToLink
        );
        this.closeLinkConversationModal();
        this.fetchLinkedConversations();
        this.$toast.success(this.$t('CRM.DEALS.LINK_SUCCESS'));
      } catch (error) {
        this.$toast.error(this.$t('CRM.DEALS.LINK_ERROR'));
      } finally {
        this.isLinkingConversation = false;
      }
    },
    openConversation(conv) {
      this.$router.push({
        name: 'inbox_conversation',
        params: {
          accountId: this.$route.params.accountId,
          conversation_id: conv.display_id || conv.id,
        },
      });
    },
    getInboxIcon(channelType) {
      const icons = {
        'Channel::WebWidget': 'globe',
        'Channel::FacebookPage': 'brand-facebook',
        'Channel::TwitterProfile': 'brand-twitter',
        'Channel::Whatsapp': 'brand-whatsapp',
        'Channel::Api': 'code',
        'Channel::Email': 'mail',
        'Channel::Telegram': 'send',
        'Channel::Sms': 'chat',
      };
      return icons[channelType] || 'chat';
    },
    async completeActivity(activityId) {
      try {
        await DealsAPI.completeActivity(this.deal.id, activityId);
        this.fetchActivities();
      } catch (error) {
        this.$toast.error(this.$t('CRM.ACTIVITIES.COMPLETE_ERROR'));
      }
    },
    getActivityIcon(type) {
      const icons = {
        call: 'call',
        email: 'mail',
        meeting: 'calendar',
        task: 'task-list',
        note: 'note',
      };
      return icons[type] || 'note';
    },
    getActivityLabel(type) {
      return this.$t(`CRM.ACTIVITIES.TYPES.${type.toUpperCase()}`);
    },
    cleanTitle(title) {
      return title || '';
    },
    startEditingTitle() {
      this.isEditingTitle = true;
      this.editTitleValue = this.cleanTitle(this.deal.title);
      this.$nextTick(() => {
        const input = this.$refs.titleInput;
        if (input) {
          input.focus();
          input.select();
        }
      });
    },
    cancelEditingTitle() {
      this.isEditingTitle = false;
      this.editTitleValue = '';
    },
    async saveTitle() {
      const cleanNewTitle = this.editTitleValue.trim();
      const currentTitle = this.cleanTitle(this.deal.title);

      if (!cleanNewTitle) {
        this.$toast.error('O nome do negócio não pode ser vazio.');
        this.cancelEditingTitle();
        return;
      }

      if (cleanNewTitle === currentTitle) {
        this.cancelEditingTitle();
        return;
      }

      this.isUpdating = true;
      try {
        const updatedDeal = await this.updateDeal({
          id: this.deal.id,
          title: cleanNewTitle,
        });
        if (updatedDeal) {
          this.localDeal = { ...this.localDeal, ...updatedDeal };
        }
        this.$emit('updated');
        this.$toast.success('Nome do negócio atualizado com sucesso!');
        this.isEditingTitle = false;
      } catch (error) {
        this.$toast.error('Erro ao atualizar o nome do negócio.');
        this.cancelEditingTitle();
      } finally {
        this.isUpdating = false;
      }
    },
    formatCurrency(value) {
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: this.deal.currency || 'BRL',
      }).format(value);
    },
    formatDate(date) {
      if (!date) return '-';
      return formatDistanceToNow(new Date(date), {
        addSuffix: true,
        locale: ptBR,
      });
    },
    formatDateFull(date) {
      if (!date) return '-';
      return format(new Date(date), 'dd/MM/yyyy', { locale: ptBR });
    },
  },
};
</script>

<style scoped>
/* Scoped styles are fully replaced by utility-first Tailwind classes */
</style>
