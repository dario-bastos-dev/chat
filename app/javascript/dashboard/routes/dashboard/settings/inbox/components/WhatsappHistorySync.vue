<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import InboxesAPI from 'dashboard/api/inboxes';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();

const isRefreshing = ref(false);
const refreshedState = ref(null);

const syncState = computed(
  () => refreshedState.value ?? props.inbox.provider_config?.history_sync
);

// Meta delivers the chunks within minutes. A request still untouched after
// an hour means no webhook is arriving at all — almost always the `history`
// field missing from the app's webhook subscription — so it is reported as
// such instead of sitting on "waiting" forever.
const STALE_REQUEST_MS = 60 * 60 * 1000;

const status = computed(() => {
  const state = syncState.value;
  if (!state) return undefined;
  if (
    state.status === 'requested' &&
    state.requested_at &&
    Date.now() - new Date(state.requested_at).getTime() > STALE_REQUEST_MS
  ) {
    return 'not_received';
  }
  return state.status;
});

const progress = computed(() => Number(syncState.value?.progress) || 0);

const STATUS_COLORS = {
  requested: 'text-n-slate-11',
  receiving: 'text-n-amber-11',
  completed: 'text-n-teal-11',
  unavailable: 'text-n-slate-11',
  not_received: 'text-n-amber-11',
};

const statusColor = computed(
  () => STATUS_COLORS[status.value] || 'text-n-slate-11'
);

const statusLabel = computed(() =>
  status.value
    ? t(`INBOX_MGMT.HISTORY_SYNC.STATUS.${status.value.toUpperCase()}`)
    : ''
);

// Chunks land minutes apart over the sync, so the state is refreshed on demand
// rather than polled. It reads the inbox directly because the inboxes store is
// served from an IndexedDB cache that the sync writes do not invalidate.
const refresh = async () => {
  isRefreshing.value = true;
  try {
    const { data } = await InboxesAPI.show(props.inbox.id);
    refreshedState.value = data.provider_config?.history_sync ?? null;
  } finally {
    isRefreshing.value = false;
  }
};
</script>

<template>
  <div
    v-if="syncState"
    class="flex flex-col gap-3 p-4 rounded-xl bg-n-solid-2 border border-n-weak"
  >
    <div class="flex items-start justify-between gap-4">
      <div class="flex flex-col gap-1">
        <span class="text-heading-3 text-n-slate-12">
          {{ $t('INBOX_MGMT.HISTORY_SYNC.TITLE') }}
        </span>
        <span class="text-sm" :class="statusColor">{{ statusLabel }}</span>
      </div>
      <NextButton
        size="sm"
        variant="faded"
        color="slate"
        :is-loading="isRefreshing"
        :label="$t('INBOX_MGMT.HISTORY_SYNC.REFRESH')"
        @click="refresh"
      />
    </div>

    <div v-if="status === 'receiving' || status === 'completed'">
      <div class="w-full h-1.5 rounded-full bg-n-alpha-2">
        <div
          class="h-1.5 rounded-full bg-n-teal-9 transition-all duration-500"
          :style="{ width: `${Math.min(progress, 100)}%` }"
        />
      </div>
      <p class="mt-1.5 text-label-small text-n-slate-11">
        {{ $t('INBOX_MGMT.HISTORY_SYNC.PROGRESS', { progress }) }}
      </p>
    </div>

    <p v-if="syncState.error" class="text-label-small text-n-slate-11">
      {{ syncState.error }}
    </p>

    <p class="text-label-small text-n-slate-11">
      {{ $t('INBOX_MGMT.HISTORY_SYNC.HELP_TEXT') }}
    </p>
  </div>
</template>
