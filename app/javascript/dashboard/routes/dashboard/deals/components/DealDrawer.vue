<template>
  <transition
    enter-active-class="transition duration-300 ease-out"
    enter-from-class="opacity-0"
    leave-active-class="transition duration-200 ease-in"
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
        <div class="w-[480px] max-w-full h-full bg-n-surface-2 border-l border-n-weak shadow-2xl flex flex-col overflow-hidden">
          <!-- Header -->
          <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak bg-n-solid-2 shrink-0">
            <h2 class="text-base font-semibold text-n-slate-12 truncate flex-1 m-0 mr-4">{{ cleanTitle(deal.title) }}</h2>
            <div class="flex items-center gap-1.5 shrink-0">
              <woot-button
                variant="smooth"
                icon="edit"
                size="small"
                class="hover:bg-n-alpha-2"
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
                class="text-n-slate-11 hover:text-n-slate-12"
                @click="$emit('close')"
              />
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
              <div v-if="deal.status === 'won'" class="flex items-center gap-2 px-3 py-2 bg-n-green-3 text-n-green-11 border border-n-green-6 rounded-lg text-sm font-medium w-full justify-center">
                <fluent-icon icon="checkmark-circle" size="16" />
                {{ $t('CRM.DEALS.STATUS_WON') }}
              </div>
              <div v-if="deal.status === 'lost'" class="flex items-center gap-2 px-3 py-2 bg-n-red-3 text-n-red-11 border border-n-red-6 rounded-lg text-sm font-medium w-full justify-center">
                <fluent-icon icon="dismiss-circle" size="16" />
                {{ $t('CRM.DEALS.STATUS_LOST') }}
              </div>
            </div>

            <!-- Deal Info / Details -->
            <div class="mb-6">
              <h3 class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider mb-3">
                {{ $t('CRM.DEALS.DETAILS') }}
              </h3>
              <div class="grid grid-cols-2 gap-4 p-4 bg-n-alpha-1 border border-n-weak rounded-xl">
                <div class="flex flex-col gap-1">
                  <span class="text-[11px] text-n-slate-11">{{ $t('CRM.DEALS.VALUE') }}</span>
                  <span class="text-base font-bold text-n-green-11">{{ formatCurrency(deal.value || 0) }}</span>
                </div>
                <div class="flex flex-col gap-1">
                  <span class="text-[11px] text-n-slate-11">{{ $t('CRM.DEALS.WEIGHTED_VALUE') }}</span>
                  <span class="text-sm font-semibold text-n-slate-12">{{ formatCurrency(deal.weighted_value || 0) }}</span>
                </div>
                <div class="flex flex-col gap-1">
                  <span class="text-[11px] text-n-slate-11">{{ $t('CRM.DEALS.STAGE') }}</span>
                  <span class="text-sm font-medium text-n-slate-12">{{ deal.stage?.name }}</span>
                </div>
                <div class="flex flex-col gap-1">
                  <span class="text-[11px] text-n-slate-11">{{ $t('CRM.DEALS.PIPELINE') }}</span>
                  <span class="text-sm font-medium text-n-slate-12 truncate">{{ deal.pipeline?.name }}</span>
                </div>
                <div class="flex flex-col gap-1">
                  <span class="text-[11px] text-n-slate-11">{{ $t('CRM.DEALS.EXPECTED_CLOSE') }}</span>
                  <span class="text-sm font-medium text-n-slate-12">{{ formatDateFull(deal.expected_close_date) }}</span>
                </div>
                <div class="flex flex-col gap-1">
                  <span class="text-[11px] text-n-slate-11">{{ $t('CRM.DEALS.CREATED') }}</span>
                  <span class="text-sm font-medium text-n-slate-12">{{ formatDateFull(deal.created_at) }}</span>
                </div>
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
            <div class="mb-6">
              <h3 class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider mb-3">
                {{ $t('CRM.DEALS.ASSIGNEE') }}
              </h3>
              <div v-if="deal.assignee" class="flex items-center gap-3 p-3 bg-n-alpha-1 border border-n-weak rounded-xl">
                <Avatar
                  :src="deal.assignee?.avatar_url"
                  :name="deal.assignee?.name"
                  :size="32"
                  class="shrink-0"
                />
                <div class="flex flex-col flex-1 min-w-0">
                  <span class="font-medium text-n-slate-12 text-sm truncate">{{ deal.assignee?.name }}</span>
                  <span class="text-xs text-n-slate-11 truncate">{{ deal.assignee?.email }}</span>
                </div>
              </div>
              <span v-else class="text-sm text-n-slate-11 italic block p-3 bg-n-alpha-1 border border-n-weak rounded-xl">
                {{ $t('CRM.DEALS.UNASSIGNED') }}
              </span>
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
    <div class="p-6 min-w-[400px] flex flex-col gap-4 bg-n-surface-2">
      <woot-modal-header :header-title="$t('CRM.ACTIVITIES.ADD')" />
      <form @submit.prevent="submitActivity" class="flex flex-col gap-4">
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.ACTIVITIES.TYPE') }} *</label>
          <select v-model="newActivity.activity_type" required class="w-full px-3 py-2 text-sm bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-12 placeholder-n-slate-9 focus:border-n-brand focus:ring-1 focus:ring-n-brand transition-colors duration-150">
            <option value="call">{{ $t('CRM.ACTIVITIES.TYPES.CALL') }}</option>
            <option value="email">
              {{ $t('CRM.ACTIVITIES.TYPES.EMAIL') }}
            </option>
            <option value="meeting">
              {{ $t('CRM.ACTIVITIES.TYPES.MEETING') }}
            </option>
            <option value="task">{{ $t('CRM.ACTIVITIES.TYPES.TASK') }}</option>
            <option value="note">{{ $t('CRM.ACTIVITIES.TYPES.NOTE') }}</option>
          </select>
        </div>
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.ACTIVITIES.DESCRIPTION') }}</label>
          <textarea
            v-model="newActivity.description"
            :placeholder="$t('CRM.ACTIVITIES.DESCRIPTION_PLACEHOLDER')"
            rows="3"
            class="w-full px-3 py-2 text-sm bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-12 placeholder-n-slate-9 focus:border-n-brand focus:ring-1 focus:ring-n-brand transition-colors duration-150"
          />
        </div>
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.ACTIVITIES.DUE_DATE') }}</label>
          <input v-model="newActivity.due_date" type="datetime-local" class="w-full px-3 py-2 text-sm bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-12 focus:border-n-brand focus:ring-1 focus:ring-n-brand transition-colors duration-150" />
        </div>
        <div class="flex justify-end gap-3 mt-4">
          <woot-button variant="clear" @click.prevent="closeActivityModal">
            {{ $t('CRM.CANCEL') }}
          </woot-button>
          <woot-button
            type="submit"
            color-scheme="primary"
            :is-loading="isCreatingActivity"
          >
            {{ $t('CRM.CREATE') }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>

  <!-- Link Conversation Modal -->
  <woot-modal
    v-model:show="showLinkConversationModal"
    :on-close="closeLinkConversationModal"
  >
    <div class="p-6 min-w-[400px] flex flex-col gap-4 bg-n-surface-2">
      <woot-modal-header :header-title="$t('CRM.DEALS.LINK_CONVERSATION')" />
      <div class="flex flex-col gap-1.5">
        <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider">{{ $t('CRM.DEALS.CONVERSATION_ID') }}</label>
        <input
          v-model="conversationIdToLink"
          type="number"
          :placeholder="$t('CRM.DEALS.CONVERSATION_ID_PLACEHOLDER')"
          min="1"
          class="w-full px-3 py-2 text-sm bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-12 placeholder-n-slate-9 focus:border-n-brand focus:ring-1 focus:ring-n-brand transition-colors duration-150"
        />
      </div>
      <div class="flex justify-end gap-3 mt-4">
        <woot-button variant="clear" @click="closeLinkConversationModal">
          {{ $t('CRM.CANCEL') }}
        </woot-button>
        <woot-button
          color-scheme="primary"
          :is-loading="isLinkingConversation"
          @click="linkConversation"
        >
          {{ $t('CRM.DEALS.LINK') }}
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
      linkedConversations: [],
      showEditModal: false,
      showLostModal: false,
      showActivityModal: false,
      showLinkConversationModal: false,
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
    };
  },
  watch: {
    isOpen: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          this.fetchActivities();
          this.fetchLinkedConversations();
        }
      },
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
      if (!title) return '';
      return title.replace(/\s*-\s*\d+$/, '');
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
