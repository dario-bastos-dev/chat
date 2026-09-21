<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';

import Spinner from 'shared/components/Spinner.vue';
import BarChart from 'shared/components/charts/BarChart.vue';
import V4Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import ReportHeader from './components/ReportHeader.vue';
import ReportFilters from './components/ReportFilters.vue';
import CrmReportsAPI from 'dashboard/api/crmReports';
import { formatDealValue } from 'dashboard/helper/crmCurrency';

// Mesmas cores das legendas (bg-n-brand, bg-n-teal-9, bg-n-ruby-9): o Chart.js
// desenha em canvas e não enxerga as classes do Tailwind.
const SERIES_COLORS = {
  created: '#1f93ff',
  won: '#12a594',
  lost: '#e5484d',
};

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const pipelines = useMapGetter('pipelines/getPipelines');

const selectedPipelineId = ref(null);
const filters = ref(null);
const isLoading = ref(false);
const hasError = ref(false);
const report = ref(null);
let latestRequest = 0;

const currency = computed(() => report.value?.currency);
const summary = computed(() => report.value?.summary || {});
const openPipeline = computed(() => report.value?.openPipeline || []);
const agents = computed(() => report.value?.agents || []);
const topOpenDeals = computed(() => report.value?.topOpenDeals || []);
const timeline = computed(() => report.value?.timeline || []);

const requestParams = computed(() => ({
  ...filters.value,
  pipelineId: selectedPipelineId.value,
}));

const formatCurrency = value => formatDealValue(value, currency.value);

const formatPercent = value =>
  value === null || value === undefined
    ? '—'
    : `${new Intl.NumberFormat(undefined, { maximumFractionDigits: 1 }).format(value)}%`;

// Ciclos curtos em horas: "0,1 dias" é impreciso de ler.
const formatCycle = days => {
  if (days === null || days === undefined) return '—';
  if (days < 1) {
    return t('CRM.REPORTS.HOURS', {
      count: Math.max(Math.round(days * 24), 1),
    });
  }
  return t('CRM.REPORTS.DAYS', {
    count: new Intl.NumberFormat(undefined, {
      maximumFractionDigits: 1,
    }).format(days),
  });
};

const summaryCards = computed(() => {
  const s = summary.value;
  const closed = (s.wonDeals || 0) + (s.lostDeals || 0);

  return [
    {
      key: 'new',
      label: t('CRM.REPORTS.NEW_DEALS'),
      value: s.newDeals ?? 0,
      hint: t('CRM.REPORTS.NEW_DEALS_HINT'),
    },
    {
      key: 'won',
      label: t('CRM.REPORTS.WON_DEALS'),
      value: s.wonDeals ?? 0,
      hint: formatCurrency(s.wonValue),
      valueClass: 'text-n-teal-11',
    },
    {
      key: 'lost',
      label: t('CRM.REPORTS.LOST_DEALS'),
      value: s.lostDeals ?? 0,
      hint: formatCurrency(s.lostValue),
      valueClass: 'text-n-ruby-11',
    },
    {
      key: 'rate',
      label: t('CRM.REPORTS.WIN_RATE'),
      value: formatPercent(s.winRate),
      hint: t('CRM.REPORTS.WIN_RATE_HINT', {
        won: s.wonDeals ?? 0,
        closed,
      }),
    },
    {
      key: 'cycle',
      label: t('CRM.REPORTS.AVG_CYCLE_TIME'),
      value: formatCycle(s.avgCycleDays),
      hint: t('CRM.REPORTS.AVG_CYCLE_TIME_HINT'),
    },
    {
      key: 'open',
      label: t('CRM.REPORTS.OPEN_NOW'),
      value: s.openDeals ?? 0,
      hint: formatCurrency(s.openValue),
    },
  ];
});

const dateLabelFormat = computed(() => {
  const period = filters.value?.groupBy;
  if (period === 'year') return { year: 'numeric' };
  if (period === 'month') return { month: 'short', year: '2-digit' };
  return { day: '2-digit', month: '2-digit' };
});

const hasTimelineData = computed(() =>
  timeline.value.some(point => point.created || point.won || point.lost)
);

const timelineChart = computed(() => {
  const formatter = new Intl.DateTimeFormat(undefined, dateLabelFormat.value);
  const series = [
    ['created', t('CRM.REPORTS.NEW_DEALS')],
    ['won', t('CRM.REPORTS.WON_DEALS')],
    ['lost', t('CRM.REPORTS.LOST_DEALS')],
  ];

  return {
    labels: timeline.value.map(point =>
      formatter.format(new Date(`${point.date}T00:00:00`))
    ),
    datasets: series.map(([key, label]) => ({
      label,
      data: timeline.value.map(point => point[key]),
      backgroundColor: SERIES_COLORS[key],
      borderRadius: 2,
    })),
  };
});

const timelineChartOptions = {
  datasets: { bar: { barPercentage: 0.8, categoryPercentage: 0.8 } },
  scales: {
    y: { beginAtZero: true, ticks: { precision: 0 } },
  },
};

const maxStageCount = computed(() =>
  Math.max(...openPipeline.value.map(stage => stage.count), 0)
);

const stageWidth = stage => {
  if (!maxStageCount.value || !stage.count) return 0;
  return Math.max((stage.count / maxStageCount.value) * 100, 2);
};

const stageShare = stage => {
  const total = summary.value.openDeals;
  if (!total) return '0%';
  return formatPercent((stage.count * 100) / total);
};

// Etapa sem valor mostra "—" em vez de "R$ 0,00" repetido em toda linha.
const formatStageValue = stage =>
  stage.value ? formatCurrency(stage.value) : '—';

const fetchReport = async () => {
  if (!selectedPipelineId.value || !filters.value) return;

  latestRequest += 1;
  const requestId = latestRequest;
  isLoading.value = true;
  hasError.value = false;

  try {
    const { data } = await CrmReportsAPI.getOverview(requestParams.value);
    // Resposta de um filtro anterior que chegou depois: descartar.
    if (requestId !== latestRequest) return;
    report.value = data;
  } catch (error) {
    if (requestId !== latestRequest) return;
    hasError.value = true;
    report.value = null;
  } finally {
    if (requestId === latestRequest) isLoading.value = false;
  }
};

const onFilterChange = ({ from, to, groupBy }) => {
  filters.value = { from, to, groupBy: groupBy?.period || 'day' };
};

const downloadReport = async () => {
  try {
    const response = await CrmReportsAPI.downloadReport(requestParams.value);
    const url = window.URL.createObjectURL(new Blob([response.data]));
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `crm-report-${Date.now()}.csv`);
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.URL.revokeObjectURL(url);
  } catch (error) {
    useAlert(t('CRM.REPORTS.DOWNLOAD_ERROR'));
  }
};

const goToPipeline = () => {
  router.push({
    name: 'deals_kanban',
    params: {
      accountId: route.params.accountId,
      pipelineId: selectedPipelineId.value,
    },
  });
};

// O relatório é sempre de um funil: agregar vários mistura etapas de funis
// diferentes e torna o ciclo médio sem sentido.
watch(
  pipelines,
  list => {
    if (selectedPipelineId.value || !list?.length) return;
    const fallback = list.find(pipeline => pipeline.is_default) || list[0];
    selectedPipelineId.value = fallback.id;
  },
  { immediate: true }
);

watch([selectedPipelineId, filters], fetchReport);

onMounted(() => {
  store.dispatch('pipelines/get');
});
</script>

<template>
  <div class="flex flex-col gap-6 p-4">
    <ReportHeader :header-title="$t('CRM.REPORTS.TITLE')">
      <div class="flex flex-wrap items-center justify-end gap-2">
        <select
          v-model="selectedPipelineId"
          class="h-8 min-w-[200px] px-3 text-sm border rounded-lg cursor-pointer bg-n-alpha-1 border-n-weak text-n-slate-12 focus:border-n-brand focus:ring-1 focus:ring-n-brand"
        >
          <option v-if="!pipelines.length" :value="null" disabled>
            {{ $t('CRM.REPORTS.SELECT_PIPELINE') }}
          </option>
          <option
            v-for="pipeline in pipelines"
            :key="pipeline.id"
            :value="pipeline.id"
          >
            {{ pipeline.name }}
          </option>
        </select>
        <V4Button
          :label="$t('CRM.REPORTS.EXPORT_CSV')"
          icon="i-ph-download-simple"
          size="sm"
          class="shrink-0"
          :disabled="!report"
          @click="downloadReport"
        />
      </div>
    </ReportHeader>

    <ReportFilters
      :show-entity-filter="false"
      :show-business-hours="false"
      show-group-by
      @filter-change="onFilterChange"
    />

    <!-- Falha de carregamento: nunca substituir por dado fabricado -->
    <div
      v-if="hasError"
      class="flex items-center gap-3 p-4 border rounded-xl border-n-ruby-5 bg-n-ruby-3 text-n-ruby-11"
    >
      <span class="i-ph-warning-circle size-5 shrink-0" />
      <div class="flex flex-col gap-1">
        <span class="text-sm font-medium">
          {{ $t('CRM.REPORTS.LOAD_ERROR') }}
        </span>
        <button
          class="p-0 text-xs font-semibold text-left underline bg-transparent border-0 cursor-pointer"
          @click="fetchReport"
        >
          {{ $t('CRM.REPORTS.RETRY') }}
        </button>
      </div>
    </div>

    <div v-if="isLoading" class="flex items-center justify-center py-20">
      <Spinner size="medium" />
    </div>

    <template v-else-if="report">
      <!-- Resumo do período -->
      <section
        class="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6"
        :aria-label="$t('CRM.REPORTS.SUMMARY')"
      >
        <div
          v-for="card in summaryCards"
          :key="card.key"
          class="flex flex-col gap-1 p-4 border rounded-xl border-n-weak bg-n-solid-2"
        >
          <span class="text-xs font-medium text-n-slate-11">
            {{ card.label }}
          </span>
          <span
            class="text-xl font-semibold break-words"
            :class="card.valueClass || 'text-n-slate-12'"
          >
            {{ card.value }}
          </span>
          <span class="text-xs break-words text-n-slate-10">
            {{ card.hint }}
          </span>
        </div>
      </section>

      <!-- Evolução no período -->
      <section
        class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-2"
      >
        <div class="flex flex-wrap items-center justify-between gap-2">
          <h4 class="m-0 text-sm font-semibold text-n-slate-12">
            {{ $t('CRM.REPORTS.DEALS_OVER_TIME') }}
          </h4>
          <div class="flex items-center gap-4 text-xs text-n-slate-11">
            <span class="flex items-center gap-1.5">
              <span class="rounded-sm size-2.5 bg-n-brand" />
              {{ $t('CRM.REPORTS.NEW_DEALS') }}
            </span>
            <span class="flex items-center gap-1.5">
              <span class="rounded-sm size-2.5 bg-n-teal-9" />
              {{ $t('CRM.REPORTS.WON_DEALS') }}
            </span>
            <span class="flex items-center gap-1.5">
              <span class="rounded-sm size-2.5 bg-n-ruby-9" />
              {{ $t('CRM.REPORTS.LOST_DEALS') }}
            </span>
          </div>
        </div>
        <div v-if="hasTimelineData" class="h-64">
          <BarChart
            :collection="timelineChart"
            :chart-options="timelineChartOptions"
          />
        </div>
        <p v-else class="m-0 text-sm text-n-slate-11">
          {{ $t('CRM.REPORTS.NO_DATA') }}
        </p>
      </section>

      <!-- Situação atual do funil -->
      <section
        class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-2"
      >
        <div class="flex flex-col gap-0.5">
          <h4 class="m-0 text-sm font-semibold text-n-slate-12">
            {{ $t('CRM.REPORTS.OPEN_PIPELINE') }}
          </h4>
          <span class="text-xs text-n-slate-11">
            {{ $t('CRM.REPORTS.OPEN_PIPELINE_HINT') }}
          </span>
        </div>
        <p v-if="!openPipeline.length" class="m-0 text-sm text-n-slate-11">
          {{ $t('CRM.REPORTS.NO_DATA') }}
        </p>
        <div v-else class="flex flex-col gap-2">
          <div
            v-for="stage in openPipeline"
            :key="stage.id"
            class="flex items-center gap-3"
          >
            <span
              class="w-40 text-xs font-medium truncate sm:w-56 shrink-0 text-n-slate-12"
              :title="stage.name"
            >
              {{ stage.name }}
            </span>
            <div class="flex-1 h-5 overflow-hidden rounded-md bg-n-alpha-1">
              <div
                class="h-full rounded-md"
                :style="{
                  width: `${stageWidth(stage)}%`,
                  backgroundColor: stage.color,
                }"
              />
            </div>
            <span
              class="w-24 text-xs text-right shrink-0"
              :class="stage.count ? 'text-n-slate-12' : 'text-n-slate-10'"
            >
              <span class="font-semibold">{{ stage.count }}</span>
              <span class="ml-1 text-n-slate-10">
                {{ stageShare(stage) }}
              </span>
            </span>
            <span
              class="hidden w-28 text-xs text-right sm:block shrink-0 text-n-slate-11"
            >
              {{ formatStageValue(stage) }}
            </span>
          </div>
        </div>
      </section>

      <!-- Desempenho por responsável -->
      <section
        class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-2"
      >
        <h4 class="m-0 text-sm font-semibold text-n-slate-12">
          {{ $t('CRM.REPORTS.AGENT_PERFORMANCE') }}
        </h4>
        <div class="overflow-x-auto">
          <table class="w-full text-sm border-collapse">
            <thead>
              <tr class="border-b border-n-weak">
                <th class="px-3 py-2 font-medium text-left text-n-slate-11">
                  {{ $t('CRM.REPORTS.AGENT') }}
                </th>
                <th class="px-3 py-2 font-medium text-right text-n-slate-11">
                  {{ $t('CRM.REPORTS.NEW_DEALS') }}
                </th>
                <th class="px-3 py-2 font-medium text-right text-n-slate-11">
                  {{ $t('CRM.REPORTS.WON_DEALS') }}
                </th>
                <th class="px-3 py-2 font-medium text-right text-n-slate-11">
                  {{ $t('CRM.REPORTS.LOST_DEALS') }}
                </th>
                <th class="px-3 py-2 font-medium text-right text-n-slate-11">
                  {{ $t('CRM.REPORTS.WIN_RATE') }}
                </th>
                <th class="px-3 py-2 font-medium text-right text-n-slate-11">
                  {{ $t('CRM.REPORTS.WON_VALUE') }}
                </th>
                <th class="px-3 py-2 font-medium text-right text-n-slate-11">
                  {{ $t('CRM.REPORTS.OPEN_NOW') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="agent in agents"
                :key="agent.id ?? 'unassigned'"
                class="border-b border-n-weak/50 last:border-0"
              >
                <td class="px-3 py-2">
                  <div class="flex items-center gap-2 min-w-0">
                    <Avatar
                      v-if="agent.id"
                      :src="agent.thumbnail"
                      :name="agent.name"
                      :size="24"
                    />
                    <span
                      class="truncate"
                      :class="
                        agent.id ? 'text-n-slate-12' : 'text-n-slate-11 italic'
                      "
                    >
                      {{ agent.name || $t('CRM.DEALS.UNASSIGNED') }}
                    </span>
                  </div>
                </td>
                <td class="px-3 py-2 text-right text-n-slate-12">
                  {{ agent.newDeals }}
                </td>
                <td class="px-3 py-2 text-right text-n-slate-12">
                  {{ agent.wonDeals }}
                </td>
                <td class="px-3 py-2 text-right text-n-slate-12">
                  {{ agent.lostDeals }}
                </td>
                <td class="px-3 py-2 text-right text-n-slate-12">
                  {{ formatPercent(agent.winRate) }}
                </td>
                <td
                  class="px-3 py-2 text-right whitespace-nowrap text-n-slate-12"
                >
                  {{ formatCurrency(agent.wonValue) }}
                </td>
                <td class="px-3 py-2 text-right text-n-slate-12">
                  {{ agent.openDeals }}
                </td>
              </tr>
              <tr v-if="!agents.length">
                <td colspan="7" class="px-3 py-6 text-center text-n-slate-11">
                  {{ $t('CRM.REPORTS.NO_DATA') }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <!-- Maiores oportunidades abertas: só aparece se há negócio com valor -->
      <section
        v-if="topOpenDeals.length"
        class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-2"
      >
        <h4 class="m-0 text-sm font-semibold text-n-slate-12">
          {{ $t('CRM.REPORTS.TOP_OPEN_DEALS') }}
        </h4>
        <div class="overflow-x-auto">
          <table class="w-full text-sm border-collapse">
            <thead>
              <tr class="border-b border-n-weak">
                <th class="px-3 py-2 font-medium text-left text-n-slate-11">
                  {{ $t('CRM.DEALS.TITLE') }}
                </th>
                <th class="px-3 py-2 font-medium text-left text-n-slate-11">
                  {{ $t('CRM.DEALS.STAGE') }}
                </th>
                <th class="px-3 py-2 font-medium text-left text-n-slate-11">
                  {{ $t('CRM.DEALS.ASSIGNEE') }}
                </th>
                <th class="px-3 py-2 font-medium text-right text-n-slate-11">
                  {{ $t('CRM.DEALS.VALUE') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="deal in topOpenDeals"
                :key="deal.id"
                class="border-b cursor-pointer border-n-weak/50 last:border-0 hover:bg-n-alpha-1"
                @click="goToPipeline"
              >
                <td class="px-3 py-2">
                  <div class="flex flex-col min-w-0">
                    <span class="font-medium truncate text-n-slate-12">
                      {{ deal.title }}
                    </span>
                    <span
                      v-if="deal.contactName && deal.contactName !== deal.title"
                      class="text-xs truncate text-n-slate-11"
                    >
                      {{ deal.contactName }}
                    </span>
                  </div>
                </td>
                <td class="px-3 py-2 text-n-slate-11">
                  {{ deal.stageName || '—' }}
                </td>
                <td class="px-3 py-2 text-n-slate-11">
                  {{ deal.assigneeName || $t('CRM.DEALS.UNASSIGNED') }}
                </td>
                <td
                  class="px-3 py-2 font-semibold text-right whitespace-nowrap text-n-slate-12"
                >
                  {{ formatCurrency(deal.value) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </template>
  </div>
</template>
