<template>
  <div class="deal-form bg-n-surface-2 p-6 rounded-2xl border border-n-weak min-w-[460px] max-w-full shadow-2xl">
    <!-- Header -->
    <div class="flex items-center justify-between pb-4 mb-5 border-b border-n-weak">
      <h2 class="text-base font-semibold text-n-slate-12 m-0 tracking-tight">
        {{ isEditing ? $t('CRM.DEALS.EDIT') : $t('CRM.DEALS.CREATE') }}
      </h2>
    </div>

    <!-- Form -->
    <form @submit.prevent="submitForm">
      <div class="space-y-5 pr-1">
        <!-- Título -->
        <div class="flex flex-col gap-1.5">
          <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.DEALS.FORM.TITLE') }} *</label>
          <input
            v-model="form.title"
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
              class="flex items-center justify-between w-full text-left text-sm font-medium text-n-slate-12 hover:text-n-brand px-3 py-2 bg-n-alpha-1 hover:bg-n-alpha-2 border border-n-weak hover:border-n-brand rounded-xl transition-all duration-150 cursor-pointer h-10"
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

            <!-- Dropdown Menu de Etapas -->
            <div
              v-if="showStageDropdown"
              class="absolute left-0 top-full mt-1.5 z-[100] w-64 max-h-[26rem] overflow-y-auto bg-n-solid-3 border border-n-weak rounded-xl shadow-xl p-2 flex flex-col gap-0.5 text-left"
              style="background-color: var(--bg-n-solid-3, #1c1d1f);"
            >
              <button
                type="button"
                v-for="stage in pipeline?.stages"
                :key="stage.id"
                class="flex items-center justify-between w-full px-3 py-2.5 text-xs text-left transition-all duration-150 cursor-pointer border-l-4 hover:brightness-95 active:brightness-90 text-n-slate-12 font-medium rounded-md border-0 bg-transparent"
                :style="{
                  backgroundColor: stage.color ? `${stage.color}15` : '#1f93ff15',
                  borderLeftColor: stage.color || '#1f93ff'
                }"
                @click="selectStage(stage.id)"
              >
                <span :class="{ 'font-semibold text-n-brand': form.stage_id === stage.id }">
                  {{ stage.name }}
                </span>
                <span
                  v-if="form.stage_id === stage.id"
                  class="text-n-brand flex shrink-0"
                >
                  <fluent-icon icon="checkmark" size="12" />
                </span>
              </button>
            </div>
          </div>
        </div>

        <!-- Contato -->
        <div class="flex flex-col gap-1.5">
          <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.DEALS.FORM.CONTACT') }} *</label>
          <div class="contact-selector-wrap">
            <div
              v-if="selectedContact"
              class="flex items-center justify-between bg-n-alpha-1 hover:bg-n-alpha-2 border border-n-weak p-3 rounded-xl h-12 transition-all duration-150"
            >
              <div class="flex items-center gap-2.5 min-w-0">
                <Avatar
                  :src="selectedContact.thumbnail || selectedContact.avatar_url"
                  :name="selectedContact.name"
                  :size="24"
                  class="shrink-0"
                />
                <span class="text-sm font-medium text-n-slate-12 truncate">
                  {{ selectedContact.name }}
                  <span v-if="selectedContact.email" class="text-xs text-n-slate-11 ml-1 font-normal">
                    ({{ selectedContact.email }})
                  </span>
                </span>
              </div>
              <button
                class="flex items-center justify-center w-6 h-6 rounded-lg hover:bg-n-alpha-1 text-n-slate-11 hover:text-n-slate-12 cursor-pointer transition-colors border-0 bg-transparent"
                @click.prevent="clearSelectedContact"
              >
                <fluent-icon icon="dismiss" size="12" />
              </button>
            </div>
            <tag-input
              v-else
              :placeholder="$t('CRM.DEALS.FORM.CONTACT_PLACEHOLDER')"
              mode="single"
              :menu-items="contactMenuItems"
              :is-loading="isSearchingContacts"
              :show-dropdown="contacts.length > 0"
              class="contact-tag-input w-full text-xs md:text-sm text-n-slate-12"
              @input="searchContacts"
              @add="setSelectedContact"
            />
          </div>
        </div>

        <!-- Responsável -->
        <div class="flex flex-col gap-1.5 relative" ref="assigneeSelectorContainer">
          <label class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.DEALS.FORM.ASSIGNEE') }}</label>
          <div class="relative w-full">
            <button
              type="button"
              class="flex items-center justify-between w-full text-left text-sm font-medium text-n-slate-12 hover:text-n-brand px-3 py-2 bg-n-alpha-1 hover:bg-n-alpha-2 border border-n-weak hover:border-n-brand rounded-xl transition-all duration-150 cursor-pointer h-10"
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
              class="absolute left-0 top-full mt-1.5 z-[100] w-64 max-h-[180px] overflow-y-auto bg-n-solid-3 border border-n-weak rounded-xl shadow-xl p-1.5 flex flex-col gap-0.5 text-left"
              style="background-color: var(--bg-n-solid-3, #1c1d1f);"
            >
              <button
                type="button"
                class="flex items-center gap-2.5 w-full px-3 py-2 text-xs font-medium text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-1 rounded-lg transition-colors cursor-pointer border-0 bg-transparent"
                @click="selectAssignee(null)"
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
                @click="selectAssignee(agent.id)"
              >
                <div class="flex items-center gap-2.5 min-w-0">
                  <Avatar
                    :src="agent.avatar_url"
                    :name="agent.name"
                    :size="20"
                    class="shrink-0"
                  />
                  <span class="truncate" :class="{ 'font-semibold text-n-brand': form.assignee_id === agent.id }">
                    {{ agent.name }}
                  </span>
                </div>
                <span
                  v-if="form.assignee_id === agent.id"
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
          @click.prevent="$emit('close')"
        >
          {{ $t('CRM.CANCEL') }}
        </button>
        <button
          type="submit"
          class="px-5.5 py-2 text-xs font-semibold rounded-xl text-white bg-n-brand hover:brightness-110 active:brightness-95 transition-all duration-150 cursor-pointer shadow-md border-0 flex items-center justify-center gap-1.5 disabled:opacity-50"
          :disabled="isSubmitting"
        >
          <woot-spinner v-if="isSubmitting" size="tiny" class="mr-1" />
          {{ isEditing ? $t('CRM.UPDATE') : $t('CRM.CREATE') }}
        </button>
      </div>
    </form>
  </div>
</template>

<script>
import { mapGetters, mapActions } from 'vuex';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';
import ContactsAPI from 'dashboard/api/contacts';

export default {
  name: 'DealForm',
  components: {
    Avatar,
    TagInput,
  },
  props: {
    pipeline: {
      type: Object,
      required: true,
    },
    initialStageId: {
      type: Number,
      default: null,
    },
    deal: {
      type: Object,
      default: null,
    },
  },
  emits: ['close', 'created', 'updated'],
  data() {
    return {
      form: {
        title: '',
        stage_id: null,
        contact_id: null,
        assignee_id: null,
      },
      selectedContact: null,
      contacts: [],
      isSearchingContacts: false,
      isSubmitting: false,
      showStageDropdown: false,
      showAssigneeDropdown: false,
    };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getAgents',
      currentUser: 'getCurrentUser',
    }),
    selectedStageName() {
      const stage = this.pipeline?.stages?.find(s => s.id === this.form.stage_id);
      return stage ? stage.name : 'Selecionar etapa...';
    },
    selectedAssigneeName() {
      if (!this.form.assignee_id) return 'Não atribuído';
      const agent = this.agents?.find(a => a.id === this.form.assignee_id);
      return agent ? agent.name : 'Não atribuído';
    },
    isEditing() {
      return !!this.deal;
    },
    contactMenuItems() {
      return this.contacts.map(contact => ({
        ...contact,
        label: contact.email ? `${contact.name} (${contact.email})` : contact.name,
        value: contact.id,
        action: 'contact',
      }));
    },
  },
  mounted() {
    this.initForm();
    this.fetchAgents();
    document.addEventListener('click', this.handleClickOutside);
  },
  beforeUnmount() {
    document.removeEventListener('click', this.handleClickOutside);
  },
  methods: {
    ...mapActions({
      fetchAgents: 'agents/get',
      createDeal: 'deals/create',
      updateDeal: 'deals/update',
    }),
    initForm() {
      if (this.deal) {
        this.form = {
          title: this.deal.title,
          stage_id: this.deal.stage_id || this.deal.stage?.id,
          contact_id: this.deal.contact_id || this.deal.contact?.id,
          assignee_id: this.deal.assignee_id || this.deal.assignee?.id,
        };
        this.selectedContact = this.deal.contact;
      } else {
        this.form.stage_id =
          this.initialStageId || this.pipeline?.stages?.[0]?.id;
        this.form.assignee_id = this.currentUser?.id;
      }
    },
    async searchContacts(query) {
      if (!query || query.length < 2) {
        this.contacts = [];
        return;
      }

      this.isSearchingContacts = true;
      try {
        const response = await ContactsAPI.search(query);
        this.contacts = response.data.payload || response.data;
      } catch (error) {
        // Silent error
      } finally {
        this.isSearchingContacts = false;
      }
    },
    setSelectedContact(item) {
      this.selectedContact = {
        id: item.id,
        name: item.name,
        email: item.email,
        thumbnail: item.thumbnail || item.avatar_url,
      };
      this.contacts = [];
    },
    clearSelectedContact() {
      this.selectedContact = null;
      this.contacts = [];
    },
    async submitForm() {
      if (!this.selectedContact) {
        this.$toast.error(this.$t('CRM.DEALS.FORM.CONTACT_REQUIRED'));
        return;
      }

      this.isSubmitting = true;
      this.form.contact_id = this.selectedContact.id;

      try {
        if (this.isEditing) {
          await this.updateDeal({ id: this.deal.id, ...this.form });
          this.$emit('updated');
        } else {
          const deal = await this.createDeal(this.form);
          this.$emit('created', deal);
        }
      } catch (error) {
        this.$toast.error(error.message || this.$t('CRM.DEALS.FORM.ERROR'));
      } finally {
        this.isSubmitting = false;
      }
    },
    toggleStageDropdown() {
      this.showStageDropdown = !this.showStageDropdown;
      this.showAssigneeDropdown = false;
    },
    toggleAssigneeDropdown() {
      this.showAssigneeDropdown = !this.showAssigneeDropdown;
      this.showStageDropdown = false;
    },
    selectStage(stageId) {
      this.form.stage_id = stageId;
      this.showStageDropdown = false;
    },
    selectAssignee(agentId) {
      this.form.assignee_id = agentId;
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
  },
};
</script>

<style lang="scss" scoped>
.deal-form {
  min-width: 480px;

  /* Proteções estritas contra estilos globais legados de formulários do Chatwoot (Foundation) */
  input[type="text"],
  select {
    margin-bottom: 0 !important;
    box-shadow: none !important;
    font-family: inherit !important;
    transition: all 0.15s ease-in-out !important;

    &:focus {
      box-shadow: 0 0 0 2px var(--n-brand-alpha, rgba(37, 99, 235, 0.2)) !important;
    }
  }

  /* Remover setas padrão nativas do navegador nos elementos select */
  select {
    -webkit-appearance: none !important;
    -moz-appearance: none !important;
    appearance: none !important;
  }

  /* Garantir consistência estética nos botões mesmo contra CSS global */
  button {
    font-family: inherit !important;
    box-shadow: none !important;
    margin: 0 !important;

    &[type="submit"] {
      box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px -1px rgba(0, 0, 0, 0.1) !important;
    }
  }
}

.contact-tag-input {
  :deep(.inline-input) {
    @apply h-10 mb-0 border-0 bg-transparent p-0 !important;
    input {
      @apply h-10 mb-0 text-xs md:text-sm text-n-slate-12 bg-n-alpha-1 hover:bg-n-alpha-2 focus:bg-n-alpha-2 border border-n-weak focus:border-n-brand rounded-xl px-3 transition-all duration-150 outline-none w-full !important;
      box-shadow: none !important;
      margin-bottom: 0 !important;
      
      &:focus {
        @apply border-n-brand !important;
        box-shadow: 0 0 0 2px var(--n-brand-alpha, rgba(37, 99, 235, 0.2)) !important;
      }
    }
  }
}

:deep(.modal-container),
.deal-form,
.deal-form form {
  overflow: visible !important;
}
</style>
