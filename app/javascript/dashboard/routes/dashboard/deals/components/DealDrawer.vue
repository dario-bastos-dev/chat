<template>
  <transition name="slide-drawer">
    <div v-if="isOpen" class="deal-drawer-overlay" @click.self="$emit('close')">
      <div class="deal-drawer">
        <div class="drawer-header">
          <h2 class="drawer-title">{{ deal.title }}</h2>
          <div class="drawer-actions">
            <woot-button
              variant="smooth"
              icon="edit"
              size="small"
              @click="openEditModal"
            />
            <woot-button
              variant="smooth"
              color-scheme="alert"
              icon="delete"
              size="small"
              @click="confirmDelete"
            />
            <woot-button
              variant="clear"
              icon="dismiss"
              size="small"
              @click="$emit('close')"
            />
          </div>
        </div>

        <div class="drawer-content">
          <!-- Status Actions -->
          <div class="deal-status-actions">
            <woot-button
              v-if="deal.status === 'open'"
              color-scheme="success"
              icon="checkmark-circle"
              @click="markAsWon"
              :is-loading="isUpdating"
            >
              {{ $t('CRM.DEALS.MARK_WON') }}
            </woot-button>
            <woot-button
              v-if="deal.status === 'open'"
              color-scheme="alert"
              variant="smooth"
              icon="dismiss-circle"
              @click="openLostModal"
            >
              {{ $t('CRM.DEALS.MARK_LOST') }}
            </woot-button>
            <div v-if="deal.status === 'won'" class="status-badge won">
              <fluent-icon icon="checkmark-circle" size="16" />
              {{ $t('CRM.DEALS.STATUS_WON') }}
            </div>
            <div v-if="deal.status === 'lost'" class="status-badge lost">
              <fluent-icon icon="dismiss-circle" size="16" />
              {{ $t('CRM.DEALS.STATUS_LOST') }}
            </div>
          </div>

          <!-- Deal Info -->
          <div class="deal-info-section">
            <h3 class="section-title">{{ $t('CRM.DEALS.DETAILS') }}</h3>

            <div class="info-grid">
              <div class="info-item">
                <span class="info-label">{{ $t('CRM.DEALS.VALUE') }}</span>
                <span class="info-value value-highlight">{{
                  formatCurrency(deal.value || 0)
                }}</span>
              </div>
              <div class="info-item">
                <span class="info-label">{{
                  $t('CRM.DEALS.WEIGHTED_VALUE')
                }}</span>
                <span class="info-value">{{
                  formatCurrency(deal.weighted_value || 0)
                }}</span>
              </div>
              <div class="info-item">
                <span class="info-label">{{ $t('CRM.DEALS.STAGE') }}</span>
                <span class="info-value">{{ deal.stage?.name }}</span>
              </div>
              <div class="info-item">
                <span class="info-label">{{ $t('CRM.DEALS.PIPELINE') }}</span>
                <span class="info-value">{{ deal.pipeline?.name }}</span>
              </div>
              <div class="info-item">
                <span class="info-label">{{
                  $t('CRM.DEALS.EXPECTED_CLOSE')
                }}</span>
                <span class="info-value">{{
                  formatDateFull(deal.expected_close_date)
                }}</span>
              </div>
              <div class="info-item">
                <span class="info-label">{{ $t('CRM.DEALS.CREATED') }}</span>
                <span class="info-value">{{
                  formatDateFull(deal.created_at)
                }}</span>
              </div>
            </div>
          </div>

          <!-- Contact -->
          <div class="deal-info-section">
            <h3 class="section-title">{{ $t('CRM.DEALS.CONTACT') }}</h3>
            <div class="contact-card" @click="openContactPage">
              <Avatar
                :src="deal.contact?.avatar_url"
                :name="deal.contact?.name"
                :size="40"
              />
              <div class="contact-details">
                <span class="contact-name">{{ deal.contact?.name }}</span>
                <span class="contact-email">{{ deal.contact?.email }}</span>
                <span class="contact-phone">{{
                  deal.contact?.phone_number
                }}</span>
              </div>
              <fluent-icon icon="chevron-right" size="16" />
            </div>
          </div>

          <!-- Assignee -->
          <div class="deal-info-section">
            <h3 class="section-title">{{ $t('CRM.DEALS.ASSIGNEE') }}</h3>
            <div v-if="deal.assignee" class="assignee-card">
              <Avatar
                :src="deal.assignee?.avatar_url"
                :name="deal.assignee?.name"
                :size="32"
              />
              <div class="assignee-details">
                <span class="assignee-name">{{ deal.assignee?.name }}</span>
                <span class="assignee-email">{{ deal.assignee?.email }}</span>
              </div>
            </div>
            <span v-else class="no-assignee">{{
              $t('CRM.DEALS.UNASSIGNED')
            }}</span>
          </div>

          <!-- Activities -->
          <div class="deal-info-section">
            <div class="section-header">
              <h3 class="section-title">{{ $t('CRM.ACTIVITIES.TITLE') }}</h3>
              <woot-button
                variant="smooth"
                size="small"
                icon="add"
                @click="openAddActivityModal"
              >
                {{ $t('CRM.ACTIVITIES.ADD') }}
              </woot-button>
            </div>

            <div v-if="activities.length === 0" class="empty-activities">
              {{ $t('CRM.ACTIVITIES.EMPTY') }}
            </div>

            <div v-else class="activities-list">
              <div
                v-for="activity in activities"
                :key="activity.id"
                class="activity-item"
                :class="{ completed: activity.is_completed }"
              >
                <div class="activity-icon">
                  <fluent-icon
                    :icon="getActivityIcon(activity.activity_type)"
                    size="16"
                  />
                </div>
                <div class="activity-content">
                  <span class="activity-type">{{
                    getActivityLabel(activity.activity_type)
                  }}</span>
                  <span class="activity-description">{{
                    activity.description
                  }}</span>
                  <span class="activity-meta">
                    {{ activity.user?.name }} •
                    {{ formatDate(activity.created_at) }}
                  </span>
                </div>
                <woot-button
                  v-if="!activity.is_completed"
                  variant="clear"
                  size="tiny"
                  icon="checkmark"
                  @click="completeActivity(activity.id)"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
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
    <div class="lost-modal">
      <woot-modal-header :header-title="$t('CRM.DEALS.LOST_REASON_TITLE')" />
      <div class="form-field">
        <label>{{ $t('CRM.DEALS.LOST_REASON') }} *</label>
        <textarea
          v-model="lostReason"
          :placeholder="$t('CRM.DEALS.LOST_REASON_PLACEHOLDER')"
          rows="3"
        />
      </div>
      <div class="modal-footer">
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
</template>

<script>
import { mapActions } from 'vuex';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import DealForm from './DealForm.vue';
import DealsAPI from 'dashboard/api/deals';
import { format, formatDistanceToNow } from 'date-fns';
import { ptBR } from 'date-fns/locale';

export default {
  name: 'DealDrawer',
  components: {
    Avatar,
    DealForm,
  },
  props: {
    deal: {
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
      showEditModal: false,
      showLostModal: false,
      lostReason: '',
      isUpdating: false,
    };
  },
  watch: {
    isOpen(newVal) {
      if (newVal) {
        this.fetchActivities();
      }
    },
  },
  methods: {
    ...mapActions({
      deleteDeal: 'deals/delete',
      winDeal: 'deals/win',
      loseDeal: 'deals/lose',
    }),
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
    async confirmDelete() {
      const confirmed = await this.$confirm(
        this.$t('CRM.DEALS.DELETE_CONFIRM'),
        this.$t('CRM.DEALS.DELETE_TITLE')
      );

      if (confirmed) {
        try {
          await this.deleteDeal(this.deal.id);
          this.$emit('deleted');
        } catch (error) {
          this.$toast.error(this.$t('CRM.DEALS.DELETE_ERROR'));
        }
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
        name: 'contacts_dashboard',
        params: {
          accountId: this.$route.params.accountId,
          contactId: this.deal.contact?.id,
        },
      });
    },
    openAddActivityModal() {
      // TODO: Implementar modal de adicionar atividade
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

<style lang="scss" scoped>
.deal-drawer-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.4);
  z-index: 1000;
  display: flex;
  justify-content: flex-end;
}

.deal-drawer {
  width: 480px;
  max-width: 100%;
  height: 100%;
  background: var(--white);
  box-shadow: var(--shadow-large);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.drawer-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--space-normal);
  border-bottom: 1px solid var(--color-border);
}

.drawer-title {
  font-size: var(--font-size-medium);
  font-weight: var(--font-weight-bold);
  color: var(--color-heading);
  margin: 0;
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.drawer-actions {
  display: flex;
  gap: var(--space-smaller);
}

.drawer-content {
  flex: 1;
  overflow-y: auto;
  padding: var(--space-normal);
}

.deal-status-actions {
  display: flex;
  gap: var(--space-small);
  margin-bottom: var(--space-normal);
}

.status-badge {
  display: flex;
  align-items: center;
  gap: var(--space-smaller);
  padding: var(--space-small) var(--space-normal);
  border-radius: var(--border-radius-medium);
  font-weight: var(--font-weight-medium);

  &.won {
    background: var(--g-100);
    color: var(--g-800);
  }

  &.lost {
    background: var(--r-100);
    color: var(--r-800);
  }
}

.deal-info-section {
  margin-bottom: var(--space-large);
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--space-small);
}

.section-title {
  font-size: var(--font-size-small);
  font-weight: var(--font-weight-bold);
  color: var(--color-heading);
  margin: 0 0 var(--space-small) 0;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.info-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-normal);
}

.info-item {
  display: flex;
  flex-direction: column;
  gap: var(--space-micro);
}

.info-label {
  font-size: var(--font-size-mini);
  color: var(--color-body);
}

.info-value {
  font-size: var(--font-size-small);
  color: var(--color-heading);

  &.value-highlight {
    font-size: var(--font-size-medium);
    font-weight: var(--font-weight-bold);
    color: var(--g-600);
  }
}

.contact-card {
  display: flex;
  align-items: center;
  gap: var(--space-small);
  padding: var(--space-small);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-small);
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    border-color: var(--w-500);
    background: var(--s-25);
  }
}

.contact-details,
.assignee-details {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.contact-name,
.assignee-name {
  font-weight: var(--font-weight-medium);
  color: var(--color-heading);
}

.contact-email,
.contact-phone,
.assignee-email {
  font-size: var(--font-size-mini);
  color: var(--color-body);
}

.assignee-card {
  display: flex;
  align-items: center;
  gap: var(--space-small);
}

.no-assignee {
  color: var(--color-body);
  font-style: italic;
}

.empty-activities {
  text-align: center;
  padding: var(--space-normal);
  color: var(--color-body);
  font-style: italic;
}

.activities-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-small);
}

.activity-item {
  display: flex;
  gap: var(--space-small);
  padding: var(--space-small);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-small);

  &.completed {
    opacity: 0.6;
    text-decoration: line-through;
  }
}

.activity-icon {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--s-100);
  border-radius: var(--border-radius-small);
  color: var(--s-700);
}

.activity-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: var(--space-micro);
}

.activity-type {
  font-size: var(--font-size-mini);
  font-weight: var(--font-weight-medium);
  color: var(--color-heading);
  text-transform: uppercase;
}

.activity-description {
  font-size: var(--font-size-small);
  color: var(--color-body);
}

.activity-meta {
  font-size: var(--font-size-micro);
  color: var(--s-500);
}

.lost-modal {
  padding: var(--space-normal);
  min-width: 400px;
}

.form-field {
  margin-bottom: var(--space-normal);

  label {
    display: block;
    margin-bottom: var(--space-smaller);
    font-weight: var(--font-weight-medium);
  }

  textarea {
    width: 100%;
    padding: var(--space-small);
    border: 1px solid var(--color-border);
    border-radius: var(--border-radius-small);
    resize: vertical;
  }
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-small);
}

// Animations
.slide-drawer-enter-active,
.slide-drawer-leave-active {
  transition: all 0.3s ease;
}

.slide-drawer-enter-from,
.slide-drawer-leave-to {
  opacity: 0;

  .deal-drawer {
    transform: translateX(100%);
  }
}
</style>
