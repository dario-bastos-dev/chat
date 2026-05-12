<template>
  <div class="deal-form">
    <woot-modal-header
      :header-title="isEditing ? $t('CRM.DEALS.EDIT') : $t('CRM.DEALS.CREATE')"
    />
    <form @submit.prevent="submitForm">
      <div class="form-content">
        <div class="form-field">
          <label>{{ $t('CRM.DEALS.FORM.TITLE') }} *</label>
          <input
            v-model="form.title"
            type="text"
            :placeholder="$t('CRM.DEALS.FORM.TITLE_PLACEHOLDER')"
            required
          />
        </div>

        <div class="form-row">
          <div class="form-field">
            <label>{{ $t('CRM.DEALS.FORM.VALUE') }}</label>
            <input
              v-model.number="form.value"
              type="number"
              step="0.01"
              min="0"
              :placeholder="$t('CRM.DEALS.FORM.VALUE_PLACEHOLDER')"
            />
          </div>
          <div class="form-field">
            <label>{{ $t('CRM.DEALS.FORM.CURRENCY') }}</label>
            <select v-model="form.currency">
              <option value="BRL">BRL - Real</option>
              <option value="USD">USD - Dólar</option>
              <option value="EUR">EUR - Euro</option>
            </select>
          </div>
        </div>

        <div class="form-field">
          <label>{{ $t('CRM.DEALS.FORM.STAGE') }} *</label>
          <select v-model="form.stage_id" required>
            <option
              v-for="stage in pipeline?.stages"
              :key="stage.id"
              :value="stage.id"
            >
              {{ stage.name }}
            </option>
          </select>
        </div>

        <div class="form-field">
          <label>{{ $t('CRM.DEALS.FORM.CONTACT') }} *</label>
          <div class="contact-selector-wrap">
            <div
              v-if="selectedContact"
              class="selected-contact-pill flex items-center justify-between bg-n-alpha-2 p-2 rounded-lg border border-n-weak"
            >
              <div class="flex items-center gap-2">
                <Avatar
                  :src="selectedContact.thumbnail"
                  :name="selectedContact.name"
                  :size="24"
                />
                <span class="text-sm font-medium text-n-slate-12">
                  {{ selectedContact.name }}
                  <span v-if="selectedContact.email" class="text-xs text-n-slate-11">
                    ({{ selectedContact.email }})
                  </span>
                </span>
              </div>
              <woot-button
                variant="ghost"
                icon="i-lucide-x"
                color="slate"
                size="xs"
                @click="clearSelectedContact"
              />
            </div>
            <tag-input
              v-else
              :placeholder="$t('CRM.DEALS.FORM.CONTACT_PLACEHOLDER')"
              mode="single"
              :menu-items="contactMenuItems"
              :is-loading="isSearchingContacts"
              :show-dropdown="contacts.length > 0"
              class="contact-tag-input"
              @input="searchContacts"
              @add="setSelectedContact"
            />
          </div>
        </div>

        <div class="form-field">
          <label>{{ $t('CRM.DEALS.FORM.ASSIGNEE') }}</label>
          <select v-model="form.assignee_id">
            <option :value="null">{{ $t('CRM.DEALS.FORM.UNASSIGNED') }}</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </div>

        <div class="form-field">
          <label>{{ $t('CRM.DEALS.FORM.EXPECTED_CLOSE') }}</label>
          <input v-model="form.expected_close_date" type="date" />
        </div>
      </div>

      <div class="modal-footer">
        <woot-button
          class="!bg-red-500 hover:!bg-red-600 !text-white"
          @click.prevent="$emit('close')"
        >
          {{ $t('CRM.CANCEL') }}
        </woot-button>
        <woot-button
          type="submit"
          class="!bg-woot-500 hover:!bg-woot-600 !text-white"
          :is-loading="isSubmitting"
        >
          {{ isEditing ? $t('CRM.UPDATE') : $t('CRM.CREATE') }}
        </woot-button>
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
        value: null,
        currency: 'BRL',
        stage_id: null,
        contact_id: null,
        assignee_id: null,
        expected_close_date: null,
      },
      selectedContact: null,
      contacts: [],
      isSearchingContacts: false,
      isSubmitting: false,
    };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getAgents',
      currentUser: 'getCurrentUser',
    }),
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
          value: this.deal.value,
          currency: this.deal.currency,
          stage_id: this.deal.stage_id || this.deal.stage?.id,
          contact_id: this.deal.contact_id || this.deal.contact?.id,
          assignee_id: this.deal.assignee_id || this.deal.assignee?.id,
          expected_close_date: this.deal.expected_close_date,
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
  },
};
</script>

<style lang="scss" scoped>
.deal-form {
  padding: var(--space-normal);
  min-width: 480px;
}

.form-content {
  max-height: 60vh;
  overflow-y: auto;
  padding-right: var(--space-small);
}

.form-field {
  margin-bottom: var(--space-normal);

  label {
    display: block;
    margin-bottom: var(--space-smaller);
    font-size: var(--font-size-small);
    font-weight: var(--font-weight-medium);
    color: var(--color-heading);
  }

  input,
  select {
    width: 100%;
    padding: var(--space-small);
    border: 1px solid var(--color-border);
    border-radius: var(--border-radius-small);
    font-size: var(--font-size-small);
    background: var(--color-background);
    color: var(--color-body);

    &:focus {
      border-color: var(--w-500);
      outline: none;
    }
  }

  .contact-selector-wrap {
    .contact-tag-input {
      :deep(.inline-input) {
        @apply h-10 !important;
        input {
          @apply h-10 mb-0 !important;
        }
      }
    }
  }
}

.form-row {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: var(--space-normal);
}

.contact-option {
  display: flex;
  align-items: center;
  gap: var(--space-small);
}

.contact-info {
  display: flex;
  flex-direction: column;
}

.contact-name {
  font-weight: var(--font-weight-medium);
}

.contact-email {
  font-size: var(--font-size-mini);
  color: var(--color-body);
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-normal);
  margin-top: var(--space-normal);
  padding-top: var(--space-normal);
  border-top: 1px solid var(--color-border);
}
</style>
