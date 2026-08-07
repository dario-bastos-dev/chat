<template>
  <div class="flex flex-col gap-6 p-4">
    <ReportHeader :header-title="$t('CRM.REPORTS.TITLE')">
      <div class="flex items-center gap-2">
        <multiselect
          v-model="selectedPipeline"
          :options="pipelines"
          :placeholder="$t('CRM.REPORTS.SELECT_PIPELINE')"
          label="name"
          track-by="id"
          :allow-empty="true"
          :show-labels="false"
          class="min-w-[200px]"
          @select="onPipelineChange"
          @remove="onPipelineChange"
        />
        <V4Button
          :label="$t('CRM.REPORTS.DOWNLOAD')"
          icon="i-ph-download-simple"
          size="sm"
          @click="downloadReport"
        />
      </div>
    </ReportHeader>

    <div class="flex flex-col gap-6">
      <!-- Date Filter -->
      <ReportFilterSelector
        :show-agents-filter="false"
        :show-group-by-filter="true"
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
            class="p-0 text-xs font-semibold text-left bg-transparent border-0 underline cursor-pointer"
            @click="fetchAllData"
          >
            {{ $t('CRM.REPORTS.RETRY') }}
          </button>
        </div>
      </div>

      <!-- Summary Cards -->
      <section class="flex flex-col gap-3">
        <h3 class="m-0 text-sm font-semibold text-n-slate-12">
          {{ $t('CRM.REPORTS.SUMMARY') }}
        </h3>
        <div v-if="isLoading" class="flex items-center justify-center py-10">
          <spinner size="medium" />
        </div>
        <div
          v-else
          class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6"
        >
          <div
            v-for="card in summaryCards"
            :key="card.key"
            class="flex items-center gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-2"
          >
            <div
              class="flex items-center justify-center rounded-lg size-10 shrink-0"
              :class="card.iconClass"
            >
              <span :class="[card.icon, 'size-5']" />
            </div>
            <div class="flex flex-col min-w-0">
              <span class="text-lg font-semibold truncate text-n-slate-12">
                {{ card.value }}
              </span>
              <span class="text-xs truncate text-n-slate-11">
                {{ card.label }}
              </span>
            </div>
          </div>
        </div>
      </section>

      <!-- Funnel -->
      <section
        class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-2"
      >
        <h4 class="m-0 text-sm font-semibold text-n-slate-12">
          {{ $t('CRM.REPORTS.FUNNEL_TITLE') }}
        </h4>
        <div v-if="isLoading" class="flex items-center justify-center py-10">
          <spinner size="small" />
        </div>
        <p v-else-if="!funnelData.length" class="m-0 text-sm text-n-slate-11">
          {{ $t('CRM.REPORTS.NO_DATA') }}
        </p>
        <div v-else class="flex flex-col gap-2">
          <div
            v-for="(stage, index) in funnelData"
            :key="stage.id"
            class="flex items-center gap-3"
          >
            <!-- Rótulo em coluna fixa: antes ficava sobre a barra -->
            <div class="flex flex-col w-40 shrink-0">
              <span class="text-xs font-medium truncate text-n-slate-12">
                {{ stage.name }}
              </span>
              <span class="text-[11px] text-n-slate-11">
                {{ formatCurrency(stage.value) }}
              </span>
            </div>
            <div class="flex-1 h-7 rounded-md bg-n-alpha-1">
              <div
                class="flex items-center justify-end h-full px-2 transition-all duration-300 rounded-md min-w-8"
                :style="{
                  width: `${getFunnelWidth(stage, index)}%`,
                  backgroundColor: getStageColor(index),
                }"
              >
                <span class="text-xs font-semibold text-white">
                  {{ stage.count }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Charts -->
      <div class="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <section
          class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-2"
        >
          <h4 class="m-0 text-sm font-semibold text-n-slate-12">
            {{ $t('CRM.REPORTS.DEALS_OVER_TIME') }}
          </h4>
          <div v-if="isLoading" class="flex items-center justify-center h-64">
            <spinner size="small" />
          </div>
          <!-- Altura explícita: o canvas do Chart.js colapsava sem ela -->
          <div v-else class="relative h-64">
            <canvas ref="dealsChart" />
          </div>
        </section>

        <section
          class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-2"
        >
          <h4 class="m-0 text-sm font-semibold text-n-slate-12">
            {{ $t('CRM.REPORTS.WON_VS_LOST') }}
          </h4>
          <div v-if="isLoading" class="flex items-center justify-center h-64">
            <spinner size="small" />
          </div>
          <div v-else class="relative h-64">
            <canvas ref="wonLostChart" />
          </div>
        </section>
      </div>

      <!-- Agent Performance -->
      <section
        class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-2"
      >
        <h4 class="m-0 text-sm font-semibold text-n-slate-12">
          {{ $t('CRM.REPORTS.AGENT_PERFORMANCE') }}
        </h4>
        <div v-if="isLoading" class="flex items-center justify-center py-10">
          <spinner size="small" />
        </div>
        <div v-else class="overflow-x-auto">
          <table class="w-full text-sm border-collapse">
            <thead>
              <tr class="border-b border-n-weak">
                <th class="px-3 py-2 font-medium text-left text-n-slate-11">
                  {{ $t('CRM.REPORTS.AGENT') }}
                </th>
                <th class="px-3 py-2 font-medium text-right text-n-slate-11">
                  {{ $t('CRM.REPORTS.TOTAL_DEALS') }}
                </th>
                <th class="px-3 py-2 font-medium text-right text-n-slate-11">
                  {{ $t('CRM.REPORTS.WON_DEALS') }}
                </th>
                <th class="px-3 py-2 font-medium text-right text-n-slate-11">
                  {{ $t('CRM.REPORTS.TOTAL_VALUE') }}
                </th>
                <th class="px-3 py-2 font-medium text-right text-n-slate-11">
                  {{ $t('CRM.REPORTS.WIN_RATE') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="agent in agentPerformance"
                :key="agent.id"
                class="border-b border-n-weak/50 last:border-0"
              >
                <td class="px-3 py-2">
                  <div class="flex items-center gap-2 min-w-0">
                    <thumbnail
                      :src="agent.thumbnail"
                      :username="agent.name"
                      size="24px"
                    />
                    <span class="truncate text-n-slate-12">
                      {{ agent.name }}
                    </span>
                  </div>
                </td>
                <td class="px-3 py-2 text-right text-n-slate-12">
                  {{ agent.totalDeals }}
                </td>
                <td class="px-3 py-2 text-right text-n-slate-12">
                  {{ agent.wonDeals }}
                </td>
                <td
                  class="px-3 py-2 text-right whitespace-nowrap text-n-slate-12"
                >
                  {{ formatCurrency(agent.totalValue) }}
                </td>
                <td class="px-3 py-2 text-right">
                  <span
                    class="inline-flex px-2 py-0.5 text-xs font-semibold rounded-full"
                    :class="winRateBadgeClass(agent.winRate)"
                  >
                    {{ agent.winRate }}%
                  </span>
                </td>
              </tr>
              <tr v-if="agentPerformance.length === 0">
                <td colspan="5" class="px-3 py-6 text-center text-n-slate-11">
                  {{ $t('CRM.REPORTS.NO_DATA') }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <!-- Top Deals -->
      <section
        class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-2"
      >
        <h3 class="m-0 text-sm font-semibold text-n-slate-12">
          {{ $t('CRM.REPORTS.TOP_DEALS') }}
        </h3>
        <div v-if="isLoading" class="flex items-center justify-center py-10">
          <spinner size="small" />
        </div>
        <div v-else class="overflow-x-auto">
          <table class="w-full text-sm border-collapse">
            <thead>
              <tr class="border-b border-n-weak">
                <th class="px-3 py-2 font-medium text-left text-n-slate-11">
                  {{ $t('CRM.DEALS.TITLE') }}
                </th>
                <th class="px-3 py-2 font-medium text-left text-n-slate-11">
                  {{ $t('CRM.DEALS.CONTACT') }}
                </th>
                <th class="px-3 py-2 font-medium text-right text-n-slate-11">
                  {{ $t('CRM.DEALS.VALUE') }}
                </th>
                <th class="px-3 py-2 font-medium text-left text-n-slate-11">
                  {{ $t('CRM.DEALS.STAGE') }}
                </th>
                <th class="px-3 py-2 font-medium text-left text-n-slate-11">
                  {{ $t('CRM.DEALS.ASSIGNEE') }}
                </th>
                <th class="px-3 py-2 font-medium text-left text-n-slate-11">
                  {{ $t('CRM.DEALS.STATUS') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="deal in topDeals"
                :key="deal.id"
                class="border-b cursor-pointer border-n-weak/50 last:border-0 hover:bg-n-alpha-1"
                @click="goToDeal(deal)"
              >
                <td class="px-3 py-2 font-medium text-n-slate-12">
                  {{ deal.title }}
                </td>
                <td class="px-3 py-2 text-n-slate-11">
                  {{ deal.contact?.name || '-' }}
                </td>
                <td
                  class="px-3 py-2 font-semibold text-right whitespace-nowrap text-n-slate-12"
                >
                  {{ formatCurrency(deal.value) }}
                </td>
                <td class="px-3 py-2 text-n-slate-11">
                  {{ deal.stage?.name || '-' }}
                </td>
                <td class="px-3 py-2 text-n-slate-11">
                  {{ deal.assignee?.name || $t('CRM.DEALS.UNASSIGNED') }}
                </td>
                <td class="px-3 py-2">
                  <span
                    class="inline-flex px-2 py-0.5 text-xs font-semibold rounded-full"
                    :class="statusBadgeClass(deal.status)"
                  >
                    {{ getStatusLabel(deal.status) }}
                  </span>
                </td>
              </tr>
              <tr v-if="topDeals.length === 0">
                <td colspan="6" class="px-3 py-6 text-center text-n-slate-11">
                  {{ $t('CRM.REPORTS.NO_DATA') }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </div>
  </div>
</template>

<script>
import { mapGetters, mapActions } from 'vuex';

import Chart from 'chart.js/auto';
import Spinner from 'shared/components/Spinner.vue';

import V4Button from 'dashboard/components-next/button/Button.vue';
import ReportHeader from './components/ReportHeader.vue';
import ReportFilterSelector from './components/FilterSelector.vue';
import CrmReportsAPI from 'dashboard/api/crmReports';
import { formatDealValue } from 'dashboard/helper/crmCurrency';

export default {
  name: 'CrmReports',
  components: {
    Spinner,

    V4Button,
    ReportHeader,
    ReportFilterSelector,
  },
  data() {
    return {
      isLoading: false,
      hasError: false,
      currency: 'BRL',
      selectedPipeline: null,
      from: 0,
      to: 0,
      groupBy: 'day',
      summary: {
        totalDeals: 0,
        totalValue: 0,
        wonDeals: 0,
        lostDeals: 0,
        winRate: 0,
        avgCycleTime: 0,
      },
      funnelData: [],
      dealsOverTime: [],
      wonLostData: { won: 0, lost: 0 },
      agentPerformance: [],
      topDeals: [],
      dealsChartInstance: null,
      wonLostChartInstance: null,
    };
  },
  computed: {
    ...mapGetters({
      pipelines: 'pipelines/getPipelines',
    }),
    summaryCards() {
      return [
        {
          key: 'total',
          icon: 'i-ph-handshake',
          iconClass: 'bg-n-brand/15 text-n-brand',
          value: this.summary.totalDeals || 0,
          label: this.$t('CRM.REPORTS.TOTAL_DEALS'),
        },
        {
          key: 'value',
          icon: 'i-ph-currency-circle-dollar',
          iconClass: 'bg-n-teal-3 text-n-teal-11',
          value: this.formatCurrency(this.summary.totalValue),
          label: this.$t('CRM.REPORTS.TOTAL_VALUE'),
        },
        {
          key: 'won',
          icon: 'i-ph-trophy',
          iconClass: 'bg-n-teal-3 text-n-teal-11',
          value: this.summary.wonDeals || 0,
          label: this.$t('CRM.REPORTS.WON_DEALS'),
        },
        {
          key: 'lost',
          icon: 'i-ph-x-circle',
          iconClass: 'bg-n-ruby-3 text-n-ruby-11',
          value: this.summary.lostDeals || 0,
          label: this.$t('CRM.REPORTS.LOST_DEALS'),
        },
        {
          key: 'rate',
          icon: 'i-ph-chart-pie',
          iconClass: 'bg-n-amber-3 text-n-amber-11',
          value: `${this.summary.winRate || 0}%`,
          label: this.$t('CRM.REPORTS.WIN_RATE'),
        },
        {
          key: 'cycle',
          icon: 'i-ph-clock',
          iconClass: 'bg-n-alpha-2 text-n-slate-11',
          value: `${this.summary.avgCycleTime || 0} ${this.$t('CRM.REPORTS.DAYS')}`,
          label: this.$t('CRM.REPORTS.AVG_CYCLE_TIME'),
        },
      ];
    },
  },
  watch: {
    selectedPipeline() {
      this.fetchAllData();
    },
  },
  mounted() {
    this.fetchPipelines();
  },
  beforeUnmount() {
    if (this.dealsChartInstance) {
      this.dealsChartInstance.destroy();
    }
    if (this.wonLostChartInstance) {
      this.wonLostChartInstance.destroy();
    }
  },
  methods: {
    ...mapActions({
      fetchPipelines: 'pipelines/get',
    }),
    async fetchAllData() {
      this.isLoading = true;
      this.hasError = false;
      try {
        await Promise.all([
          this.fetchSummary(),
          this.fetchFunnel(),
          this.fetchDealsOverTime(),
          this.fetchWonLost(),
          this.fetchAgentPerformance(),
          this.fetchTopDeals(),
        ]);
      } catch (error) {
        this.hasError = true;
      } finally {
        this.isLoading = false;
      }
    },
    getRequestParams() {
      return {
        from: this.from,
        to: this.to,
        pipelineId: this.selectedPipeline?.id,
        groupBy: this.groupBy,
      };
    },
    async fetchSummary() {
      try {
        const response = await CrmReportsAPI.getSummary(
          this.getRequestParams()
        );
        this.summary = response.data || this.summary;
        this.currency = response.data?.currency || this.currency;
      } catch (error) {
        this.hasError = true;
      }
    },
    async fetchFunnel() {
      try {
        const response = await CrmReportsAPI.getFunnel(this.getRequestParams());
        this.funnelData = response.data || [];
      } catch (error) {
        this.hasError = true;
        this.funnelData = [];
      }
    },
    async fetchDealsOverTime() {
      try {
        const response = await CrmReportsAPI.getDealsOverTime(
          this.getRequestParams()
        );
        this.dealsOverTime = response.data || [];
        this.renderDealsChart();
      } catch (error) {
        this.hasError = true;
        this.dealsOverTime = [];
      }
    },
    async fetchWonLost() {
      try {
        const response = await CrmReportsAPI.getWonLostMetrics(
          this.getRequestParams()
        );
        this.wonLostData = response.data || { won: 0, lost: 0 };
        this.renderWonLostChart();
      } catch (error) {
        this.hasError = true;
        this.wonLostData = { won: 0, lost: 0 };
      }
    },
    async fetchAgentPerformance() {
      try {
        const response = await CrmReportsAPI.getAgentPerformance(
          this.getRequestParams()
        );
        this.agentPerformance = response.data || [];
      } catch (error) {
        this.hasError = true;
        this.agentPerformance = [];
      }
    },
    async fetchTopDeals() {
      try {
        const response = await CrmReportsAPI.getTopDeals({
          ...this.getRequestParams(),
          limit: 10,
        });
        this.topDeals = response.data || [];
      } catch (error) {
        this.hasError = true;
        this.topDeals = [];
      }
    },
    renderDealsChart() {
      if (!this.$refs.dealsChart) return;

      if (this.dealsChartInstance) {
        this.dealsChartInstance.destroy();
      }

      const ctx = this.$refs.dealsChart.getContext('2d');
      this.dealsChartInstance = new Chart(ctx, {
        type: 'line',
        data: {
          labels: this.dealsOverTime.map(d => d.date),
          datasets: [
            {
              label: this.$t('CRM.REPORTS.CREATED'),
              data: this.dealsOverTime.map(d => d.created),
              borderColor: '#1f77b4',
              backgroundColor: 'rgba(31, 119, 180, 0.1)',
              fill: true,
              tension: 0.4,
            },
            {
              label: this.$t('CRM.REPORTS.WON_DEALS'),
              data: this.dealsOverTime.map(d => d.won),
              borderColor: '#2ca02c',
              backgroundColor: 'rgba(44, 160, 44, 0.1)',
              fill: true,
              tension: 0.4,
            },
            {
              label: this.$t('CRM.REPORTS.LOST_DEALS'),
              data: this.dealsOverTime.map(d => d.lost),
              borderColor: '#d62728',
              backgroundColor: 'rgba(214, 39, 40, 0.1)',
              fill: true,
              tension: 0.4,
            },
          ],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: 'bottom',
            },
          },
          scales: {
            y: {
              beginAtZero: true,
            },
          },
        },
      });
    },
    renderWonLostChart() {
      if (!this.$refs.wonLostChart) return;

      if (this.wonLostChartInstance) {
        this.wonLostChartInstance.destroy();
      }

      const ctx = this.$refs.wonLostChart.getContext('2d');
      this.wonLostChartInstance = new Chart(ctx, {
        type: 'doughnut',
        data: {
          labels: [
            this.$t('CRM.REPORTS.WON_DEALS'),
            this.$t('CRM.REPORTS.LOST_DEALS'),
          ],
          datasets: [
            {
              data: [this.wonLostData.won, this.wonLostData.lost],
              backgroundColor: ['#2ca02c', '#d62728'],
              borderWidth: 0,
            },
          ],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: 'bottom',
            },
          },
        },
      });
    },
    onFilterChange({ from, to, groupBy }) {
      this.from = from;
      this.to = to;
      this.groupBy = groupBy?.period || 'day';
      this.fetchAllData();
    },
    onPipelineChange() {
      this.fetchAllData();
    },
    async downloadReport() {
      try {
        const response = await CrmReportsAPI.downloadReport({
          ...this.getRequestParams(),
          reportType: 'full',
        });

        const url = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement('a');
        link.href = url;
        link.setAttribute('download', `crm-report-${Date.now()}.csv`);
        document.body.appendChild(link);
        link.click();
        link.remove();
      } catch (error) {
        console.error('Error downloading report:', error);
        this.$toast.error(this.$t('CRM.REPORTS.DOWNLOAD_ERROR'));
      }
    },
    goToDeal(deal) {
      this.$router.push({
        name: 'deals_kanban',
        params: {
          accountId: this.$route.params.accountId,
          pipelineId: deal.pipeline_id,
        },
      });
    },
    formatCurrency(value) {
      return formatDealValue(value, this.currency);
    },
    getFunnelWidth(stage, index) {
      if (!this.funnelData.length) return 100;
      const maxCount = Math.max(...this.funnelData.map(s => s.count));
      const minWidth = 40;
      const calculated = (stage.count / maxCount) * 100;
      return Math.max(calculated, minWidth);
    },
    getStageColor(index) {
      const colors = [
        '#667eea',
        '#764ba2',
        '#f093fb',
        '#f5576c',
        '#4facfe',
        '#00f2fe',
      ];
      return colors[index % colors.length];
    },
    winRateBadgeClass(rate) {
      if (rate >= 70) return 'bg-n-teal-3 text-n-teal-11';
      if (rate >= 40) return 'bg-n-amber-3 text-n-amber-11';
      return 'bg-n-ruby-3 text-n-ruby-11';
    },
    statusBadgeClass(status) {
      if (status === 'won') return 'bg-n-teal-3 text-n-teal-11';
      if (status === 'lost') return 'bg-n-ruby-3 text-n-ruby-11';
      return 'bg-n-brand/15 text-n-brand';
    },
    getStatusLabel(status) {
      const labels = {
        open: this.$t('CRM.REPORTS.OPEN'),
        won: this.$t('CRM.DEALS.STATUS_WON'),
        lost: this.$t('CRM.DEALS.STATUS_LOST'),
      };
      return labels[status] || status;
    },
  },
};
</script>
