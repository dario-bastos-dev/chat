<script setup>
import { ref, watch, computed } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import DealsAPI from 'dashboard/api/deals';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const router = useRouter();
const route = useRoute();

const deals = ref([]);
const isLoading = ref(false);

const fetchDeals = async () => {
  isLoading.value = true;
  try {
    const response = await DealsAPI.get({ contactId: props.contactId });
    deals.value = response.data.data || response.data.payload || (Array.isArray(response.data) ? response.data : []);
  } catch (error) {
    deals.value = [];
  } finally {
    isLoading.value = false;
  }
};

const cleanTitle = title => {
  return title || '';
};

watch(
  () => props.contactId,
  newVal => {
    if (newVal) fetchDeals();
  },
  { immediate: true }
);

const goToDealDetails = deal => {
  router.push({
    name: 'deals_kanban',
    params: {
      accountId: route.params.accountId,
      pipelineId: deal.pipeline?.id || deal.pipeline_id,
    },
  });
};


</script>

<template>
  <!-- Loading -->
  <div
    v-if="isLoading"
    class="flex items-center justify-center py-10 text-n-slate-11"
  >
    <Spinner />
  </div>

  <!-- Lista de negócios -->
  <div
    v-else-if="deals.length > 0"
    class="px-6 py-4 divide-y divide-n-strong [&>*:hover]:!border-y-transparent [&>*:hover+*]:!border-t-transparent"
  >
    <div
      v-for="deal in deals"
      :key="deal.id"
      class="flex flex-col gap-2 p-4 cursor-pointer transition-all duration-200 rounded-none hover:rounded-xl hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3"
      @click="goToDealDetails(deal)"
    >
      <!-- Título e Status -->
      <div class="flex items-start justify-between w-full gap-2">
        <h5 class="text-sm font-semibold text-n-slate-12 truncate flex-1 m-0">
          {{ cleanTitle(deal.title) }}
        </h5>
        <span
          v-if="deal.status !== 'open'"
          class="text-[10px] font-semibold px-2 py-0.5 rounded leading-none shrink-0"
          :class="
            deal.status === 'won'
              ? 'bg-g-100 text-g-700 dark:bg-g-900/30 dark:text-g-400'
              : 'bg-r-100 text-r-700 dark:bg-r-900/30 dark:text-r-400'
          "
        >
          {{
            deal.status === 'won'
              ? $t('CRM.DEALS.STATUS_WON')
              : $t('CRM.DEALS.STATUS_LOST')
          }}
        </span>
      </div>



      <!-- Pipeline & Estágio -->
      <div class="flex flex-wrap items-center gap-3 text-xs text-n-slate-11">
        <span class="inline-flex items-center gap-1">
          <span class="i-ph-funnel text-n-slate-9 size-3.5" />
          {{ deal.pipeline?.name }}
        </span>
        <span class="inline-flex items-center gap-1">
          <span class="i-ph-git-branch text-n-slate-9 size-3.5" />
          {{ deal.stage?.name }}
        </span>
      </div>

      <!-- Responsável e Data -->
      <div
        class="flex items-center justify-between w-full mt-1 text-xs text-n-slate-10"
      >
        <div v-if="deal.assignee" class="flex items-center gap-1.5">
          <Avatar
            :src="deal.assignee.thumbnail"
            :name="deal.assignee.name"
            :size="18"
          />
          <span>{{ deal.assignee.name }}</span>
        </div>

      </div>
    </div>
  </div>

  <!-- Empty state -->
  <p
    v-else
    class="px-6 py-10 text-sm leading-6 text-center text-n-slate-11"
  >
    {{ t('CONTACTS_LAYOUT.SIDEBAR.DEALS.EMPTY_STATE') }}
  </p>
</template>
