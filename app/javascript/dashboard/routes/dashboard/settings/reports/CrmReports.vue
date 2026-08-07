<template>
  <div class="crm-reports">
    <ReportHeader :header-title="$t('CRM.REPORTS.TITLE')">
      <div class="header-actions">
        <multiselect
          v-model="selectedPipeline"
          :options="pipelines"
          :placeholder="$t('CRM.REPORTS.SELECT_PIPELINE')"
          label="name"
          track-by="id"
          :allow-empty="true"
          :show-labels="false"
          class="pipeline-select"
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

    <div class="reports-content">
      <!-- Date Filter -->
      <div class="filter-section">
        <ReportFilterSelector
          :show-agents-filter="false"
          :show-group-by-filter="true"
          @filter-change="onFilterChange"
        />
      </div>

      <!-- Falha de carregamento: nunca substituir por dado fabricado -->
      <div
        v-if="hasError"
        class="flex items-center gap-3 p-4 mb-4 border rounded-xl border-n-ruby-5 bg-n-ruby-3 text-n-ruby-11"
      >
        <span class="i-ph-warning-circle size-5 shrink-0" />
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium">
            {{ $t('CRM.REPORTS.LOAD_ERROR') }}
          </span>
          <button
            class="text-xs font-semibold underline cursor-pointer border-0 bg-transparent p-0 text-left"
            @click="fetchAllData"
          >
            {{ $t('CRM.REPORTS.RETRY') }}
          </button>
        </div>
      </div>

      <!-- Summary Cards -->
      <div class="summary-section">
        <h3 class="section-title">{{ $t('CRM.REPORTS.SUMMARY') }}</h3>
        <div v-if="isLoading" class="loading-state">
          <spinner size="medium" />
        </div>
        <div v-else class="summary-cards">
          <div class="summary-card">
            <div class="card-icon total">
              <span class="i-ph-handshake size-6" />
            </div>
            <div class="card-content">
              <span class="card-value">{{ summary.totalDeals || 0 }}</span>
              <span class="card-label">{{
                $t('CRM.REPORTS.TOTAL_DEALS')
              }}</span>
            </div>
          </div>

          <div class="summary-card">
            <div class="card-icon value">
              <span class="i-ph-currency-circle-dollar size-6" />
            </div>
            <div class="card-content">
              <span class="card-value">{{
                formatCurrency(summary.totalValue)
              }}</span>
              <span class="card-label">{{
                $t('CRM.REPORTS.TOTAL_VALUE')
              }}</span>
            </div>
          </div>

          <div class="summary-card">
            <div class="card-icon won">
              <span class="i-ph-trophy size-6" />
            </div>
            <div class="card-content">
              <span class="card-value">{{ summary.wonDeals || 0 }}</span>
              <span class="card-label">{{ $t('CRM.REPORTS.WON_DEALS') }}</span>
            </div>
          </div>

          <div class="summary-card">
            <div class="card-icon lost">
              <span class="i-ph-x-circle size-6" />
            </div>
            <div class="card-content">
              <span class="card-value">{{ summary.lostDeals || 0 }}</span>
              <span class="card-label">{{ $t('CRM.REPORTS.LOST_DEALS') }}</span>
            </div>
          </div>

          <div class="summary-card">
            <div class="card-icon rate">
              <span class="i-ph-chart-pie size-6" />
            </div>
            <div class="card-content">
              <span class="card-value">{{ summary.winRate || 0 }}%</span>
              <span class="card-label">{{ $t('CRM.REPORTS.WIN_RATE') }}</span>
            </div>
          </div>

          <div class="summary-card">
            <div class="card-icon avg">
              <span class="i-ph-clock size-6" />
            </div>
            <div class="card-content">
              <span class="card-value"
                >{{ summary.avgCycleTime || 0 }}
                {{ $t('CRM.REPORTS.DAYS') }}</span
              >
              <span class="card-label">{{
                $t('CRM.REPORTS.AVG_CYCLE_TIME')
              }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Charts Section -->
      <div class="charts-section">
        <!-- Funnel Chart -->
        <div class="chart-card funnel-chart">
          <h4 class="chart-title">{{ $t('CRM.REPORTS.FUNNEL_TITLE') }}</h4>
          <div v-if="isLoading" class="chart-loading">
            <spinner size="small" />
          </div>
          <div v-else class="funnel-container">
            <div
              v-for="(stage, index) in funnelData"
              :key="stage.id"
              class="funnel-stage"
              :style="{ width: getFunnelWidth(stage, index) + '%' }"
            >
              <div
                class="stage-bar"
                :style="{ backgroundColor: getStageColor(index) }"
              >
                <span class="stage-count">{{ stage.count }}</span>
              </div>
              <div class="stage-info">
                <span class="stage-name">{{ stage.name }}</span>
                <span class="stage-value">{{
                  formatCurrency(stage.value)
                }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Deals Over Time Chart -->
        <div class="chart-card timeline-chart">
          <h4 class="chart-title">{{ $t('CRM.REPORTS.DEALS_OVER_TIME') }}</h4>
          <div v-if="isLoading" class="chart-loading">
            <spinner size="small" />
          </div>
          <div v-else class="chart-container">
            <canvas ref="dealsChart" />
          </div>
        </div>

        <!-- Won vs Lost Chart -->
        <div class="chart-card pie-chart">
          <h4 class="chart-title">{{ $t('CRM.REPORTS.WON_VS_LOST') }}</h4>
          <div v-if="isLoading" class="chart-loading">
            <spinner size="small" />
          </div>
          <div v-else class="chart-container">
            <canvas ref="wonLostChart" />
          </div>
        </div>

        <!-- Agent Performance -->
        <div class="chart-card agent-chart">
          <h4 class="chart-title">{{ $t('CRM.REPORTS.AGENT_PERFORMANCE') }}</h4>
          <div v-if="isLoading" class="chart-loading">
            <spinner size="small" />
          </div>
          <div v-else class="agent-table">
            <table>
              <thead>
                <tr>
                  <th>{{ $t('CRM.REPORTS.AGENT') }}</th>
                  <th>{{ $t('CRM.REPORTS.TOTAL_DEALS') }}</th>
                  <th>{{ $t('CRM.REPORTS.WON_DEALS') }}</th>
                  <th>{{ $t('CRM.REPORTS.TOTAL_VALUE') }}</th>
                  <th>{{ $t('CRM.REPORTS.WIN_RATE') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="agent in agentPerformance" :key="agent.id">
                  <td class="agent-cell">
                    <thumbnail
                      :src="agent.thumbnail"
                      :username="agent.name"
                      size="24px"
                    />
                    <span>{{ agent.name }}</span>
                  </td>
                  <td>{{ agent.totalDeals }}</td>
                  <td>{{ agent.wonDeals }}</td>
                  <td>{{ formatCurrency(agent.totalValue) }}</td>
                  <td>
                    <span
                      class="win-rate-badge"
                      :class="getWinRateClass(agent.winRate)"
                    >
                      {{ agent.winRate }}%
                    </span>
                  </td>
                </tr>
                <tr v-if="agentPerformance.length === 0">
                  <td colspan="5" class="empty-row">
                    {{ $t('CRM.REPORTS.NO_DATA') }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Top Deals -->
      <div class="top-deals-section">
        <h3 class="section-title">{{ $t('CRM.REPORTS.TOP_DEALS') }}</h3>
        <div v-if="isLoading" class="loading-state">
          <spinner size="small" />
        </div>
        <div v-else class="deals-table">
          <table>
            <thead>
              <tr>
                <th>{{ $t('CRM.DEALS.TITLE') }}</th>
                <th>{{ $t('CRM.DEALS.CONTACT') }}</th>
                <th>{{ $t('CRM.DEALS.VALUE') }}</th>
                <th>{{ $t('CRM.DEALS.STAGE') }}</th>
                <th>{{ $t('CRM.DEALS.ASSIGNEE') }}</th>
                <th>{{ $t('CRM.DEALS.STATUS_WON') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="deal in topDeals"
                :key="deal.id"
                @click="goToDeal(deal)"
              >
                <td class="deal-title-cell">{{ deal.title }}</td>
                <td>{{ deal.contact?.name || '-' }}</td>
                <td class="value-cell">{{ formatCurrency(deal.value) }}</td>
                <td>{{ deal.stage?.name || '-' }}</td>
                <td>{{ deal.assignee?.name || $t('CRM.DEALS.UNASSIGNED') }}</td>
                <td>
                  <span class="status-badge" :class="deal.status">
                    {{ getStatusLabel(deal.status) }}
                  </span>
                </td>
              </tr>
              <tr v-if="topDeals.length === 0">
                <td colspan="6" class="empty-row">
                  {{ $t('CRM.REPORTS.NO_DATA') }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
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
    getWinRateClass(rate) {
      if (rate >= 70) return 'high';
      if (rate >= 40) return 'medium';
      return 'low';
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

<style lang="scss" scoped>
.crm-reports {
  padding: var(--space-normal);
}

.header-actions {
  display: flex;
  align-items: center;
  gap: var(--space-small);
}

.pipeline-select {
  min-width: 200px;
}

.reports-content {
  display: flex;
  flex-direction: column;
  gap: var(--space-large);
}

.filter-section {
  margin-bottom: var(--space-normal);
}

.section-title {
  font-size: var(--font-size-medium);
  font-weight: var(--font-weight-bold);
  color: var(--color-heading);
  margin-bottom: var(--space-normal);
}

.loading-state,
.chart-loading {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: var(--space-large);
}

// Summary Cards
.summary-cards {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: var(--space-normal);
}

.summary-card {
  display: flex;
  align-items: center;
  gap: var(--space-small);
  padding: var(--space-normal);
  background: var(--white);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-medium);
  box-shadow: var(--shadow-small);
}

.card-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 48px;
  border-radius: var(--border-radius-medium);
  color: var(--white);

  &.total {
    background: linear-gradient(135deg, #667eea, #764ba2);
  }
  &.value {
    background: linear-gradient(135deg, #11998e, #38ef7d);
  }
  &.won {
    background: linear-gradient(135deg, #56ab2f, #a8e063);
  }
  &.lost {
    background: linear-gradient(135deg, #eb3349, #f45c43);
  }
  &.rate {
    background: linear-gradient(135deg, #4facfe, #00f2fe);
  }
  &.avg {
    background: linear-gradient(135deg, #fa709a, #fee140);
  }
}

.card-content {
  display: flex;
  flex-direction: column;
}

.card-value {
  font-size: var(--font-size-large);
  font-weight: var(--font-weight-bold);
  color: var(--color-heading);
}

.card-label {
  font-size: var(--font-size-small);
  color: var(--color-body);
}

// Charts Section
.charts-section {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--space-normal);

  @media (max-width: 1024px) {
    grid-template-columns: 1fr;
  }
}

.chart-card {
  background: var(--white);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-medium);
  padding: var(--space-normal);
  box-shadow: var(--shadow-small);

  &.funnel-chart {
    grid-column: 1 / -1;
  }

  &.agent-chart {
    grid-column: 1 / -1;
  }
}

.chart-title {
  font-size: var(--font-size-default);
  font-weight: var(--font-weight-medium);
  color: var(--color-heading);
  margin-bottom: var(--space-normal);
}

.chart-container {
  height: 300px;
}

// Funnel Chart
.funnel-container {
  display: flex;
  flex-direction: column;
  gap: var(--space-small);
}

.funnel-stage {
  display: flex;
  align-items: center;
  gap: var(--space-small);
  margin: 0 auto;
  transition: width 0.3s ease;
}

.stage-bar {
  height: 40px;
  border-radius: var(--border-radius-small);
  display: flex;
  align-items: center;
  justify-content: center;
  flex: 1;
  transition: all 0.3s ease;

  &:hover {
    transform: scale(1.02);
  }
}

.stage-count {
  color: var(--white);
  font-weight: var(--font-weight-bold);
  font-size: var(--font-size-medium);
}

.stage-info {
  display: flex;
  flex-direction: column;
  min-width: 150px;
}

.stage-name {
  font-size: var(--font-size-small);
  font-weight: var(--font-weight-medium);
  color: var(--color-heading);
}

.stage-value {
  font-size: var(--font-size-mini);
  color: var(--color-body);
}

// Tables
.agent-table,
.deals-table {
  overflow-x: auto;
}

table {
  width: 100%;
  border-collapse: collapse;

  th,
  td {
    padding: var(--space-small);
    text-align: left;
    border-bottom: 1px solid var(--color-border);
  }

  th {
    font-weight: var(--font-weight-medium);
    color: var(--color-heading);
    background: var(--s-50);
  }

  tr:hover {
    background: var(--s-25);
  }
}

.agent-cell {
  display: flex;
  align-items: center;
  gap: var(--space-smaller);
}

.deal-title-cell {
  max-width: 250px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.value-cell {
  font-weight: var(--font-weight-bold);
  color: var(--g-600);
}

.win-rate-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: var(--border-radius-small);
  font-size: var(--font-size-mini);
  font-weight: var(--font-weight-medium);

  &.high {
    background: var(--g-100);
    color: var(--g-700);
  }

  &.medium {
    background: var(--y-100);
    color: var(--y-700);
  }

  &.low {
    background: var(--r-100);
    color: var(--r-700);
  }
}

.status-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: var(--border-radius-small);
  font-size: var(--font-size-mini);
  font-weight: var(--font-weight-medium);

  &.open {
    background: var(--b-100);
    color: var(--b-700);
  }

  &.won {
    background: var(--g-100);
    color: var(--g-700);
  }

  &.lost {
    background: var(--r-100);
    color: var(--r-700);
  }
}

.empty-row {
  text-align: center;
  color: var(--color-body);
  padding: var(--space-large) !important;
}

.deals-table tr {
  cursor: pointer;
}
</style>
