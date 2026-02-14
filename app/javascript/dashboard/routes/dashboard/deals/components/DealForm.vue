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
          <multiselect
            v-model="selectedContact"
            :options="contacts"
            :searchable="true"
            :loading="isSearchingContacts"
            track-by="id"
            label="name"
            :placeholder="$t('CRM.DEALS.FORM.CONTACT_PLACEHOLDER')"
            :internal-search="false"
            :show-no-results="true"
            @search-change="searchContacts"
          >
            <template #option="{ option }">
              <div class="contact-option">
                <Avatar
                  :src="option.avatar_url"
                  :name="option.name"
                  :size="24"
                />
                <div class="contact-info">
                  <span class="contact-name">{{ option.name }}</span>
                  <span class="contact-email">{{ option.email }}</span>
                </div>
              </div>
            </template>
          </multiselect>
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
        <woot-button variant="clear" @click.prevent="$emit('close')">
          {{ $t('CRM.CANCEL') }}
        </woot-button>
        <woot-button
          type="submit"
          color-scheme="primary"
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
import ContactsAPI from 'dashboard/api/contacts';

export default {
  name: 'DealForm',
  components: {
    Avatar,
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
      if (!query || query.length < 2) return;

      this.isSearchingContacts = true;
      try {
        const response = await ContactsAPI.search(query);
        this.contacts = response.data.payload || response.data;
      } catch (error) {
        console.error('Error searching contacts:', error);
      } finally {
        this.isSearchingContacts = false;
      }
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
    font-weight: var(--font-weight-medium);
    font-size: var(--font-size-small);
    color: var(--color-heading);
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
  gap: var(--space-small);
  margin-top: var(--space-normal);
  padding-top: var(--space-normal);
  border-top: 1px solid var(--color-border);
}
</style>
