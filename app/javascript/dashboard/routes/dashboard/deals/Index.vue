<template>
  <div class="h-full overflow-y-auto bg-n-background p-4 md:p-6">
    <!-- Header Section -->
    <header
      class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6 pb-4 border-b border-n-weak"
    >
      <div class="flex items-center gap-3">
        <div
          class="w-10 h-10 rounded-xl bg-n-brand flex items-center justify-center text-white shadow-md"
        >
          <fluent-icon icon="board" size="20" />
        </div>
        <div>
          <h1 class="text-lg font-semibold text-n-slate-12 m-0">
            {{ $t('CRM.TITLE') }}
          </h1>
          <p class="text-sm text-n-slate-11 m-0">
            Gerencie seus pipelines e negócios
          </p>
        </div>
      </div>
      <woot-button
        color-scheme="primary"
        icon="add"
        size="small"
        @click="openCreatePipelineModal"
      >
        {{ $t('CRM.PIPELINES.CREATE') }}
      </woot-button>
    </header>

    <!-- Loading State -->
    <div
      v-if="uiFlags.isFetching"
      class="flex items-center justify-center h-[calc(100vh-200px)]"
    >
      <div class="flex flex-col items-center gap-3 text-n-slate-11">
        <spinner size="large" />
        <p class="m-0 text-sm">Carregando pipelines...</p>
      </div>
    </div>

    <!-- Empty State -->
    <div
      v-else-if="pipelines.length === 0"
      class="flex items-center justify-center h-[calc(100vh-200px)]"
    >
      <div
        class="flex flex-col items-center text-center max-w-md p-8 bg-n-solid-2 rounded-2xl border border-n-weak shadow-lg animate-fadeIn"
      >
        <div
          class="w-20 h-20 rounded-full bg-n-blue-3 text-n-blue-11 flex items-center justify-center mb-4 shadow-md"
        >
          <fluent-icon icon="board" size="36" />
        </div>
        <h2 class="text-base font-semibold text-n-slate-12 m-0 mb-2">
          {{ $t('CRM.PIPELINES.EMPTY.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11 m-0 mb-6 leading-relaxed">
          {{ $t('CRM.PIPELINES.EMPTY.DESCRIPTION') }}
        </p>
        <woot-button
          color-scheme="primary"
          icon="add"
          @click="openCreatePipelineModal"
        >
          {{ $t('CRM.PIPELINES.CREATE') }}
        </woot-button>
      </div>
    </div>

    <!-- Pipelines Grid -->
    <div v-else class="animate-fadeIn">
      <div class="flex items-center justify-between mb-4">
        <h2
          class="flex items-center gap-2 text-sm font-semibold text-n-slate-12 m-0"
        >
          <fluent-icon icon="board" size="18" class="text-n-brand" />
          Seus Pipelines
        </h2>
        <span
          class="text-xs text-n-slate-11 bg-n-solid-2 px-3 py-1 rounded-full"
        >
          {{ pipelines.length }} pipeline(s)
        </span>
      </div>

      <div class="grid gap-4 grid-cols-1 md:grid-cols-2 xl:grid-cols-3">
        <div
          v-for="pipeline in pipelines"
          :key="pipeline.id"
          class="group relative bg-n-solid-2 border border-n-weak rounded-xl overflow-hidden cursor-pointer transition-all duration-300 hover:border-n-brand hover:shadow-xl hover:-translate-y-1"
          @click="openPipeline(pipeline)"
        >
          <!-- Card Gradient Accent -->
          <div
            class="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-n-blue-9 to-n-iris-9 transition-all duration-300 group-hover:h-1.5"
          ></div>

          <!-- Card Content -->
          <div class="p-4">
            <!-- Header -->
            <div class="flex items-start justify-between mb-4">
              <div class="flex flex-col gap-1">
                <h3 class="text-base font-semibold text-n-slate-12 m-0">
                  {{ pipeline.name }}
                </h3>
                <span
                  v-if="pipeline.is_default"
                  class="inline-flex items-center gap-1 text-xs font-medium text-n-amber-11 bg-n-amber-3 px-2 py-0.5 rounded-full w-fit"
                >
                  <fluent-icon icon="star" size="10" />
                  Padrão
                </span>
              </div>
              <div
                class="text-n-slate-9 opacity-50 transition-all duration-300 group-hover:opacity-100 group-hover:translate-x-1"
              >
                <fluent-icon icon="chevron-right" size="18" />
              </div>
            </div>

            <!-- Stats Row -->
            <div
              class="grid grid-cols-3 gap-2 mb-4 p-3 bg-n-alpha-1 rounded-lg"
            >
              <div class="flex items-center gap-2">
                <div
                  class="w-8 h-8 rounded-lg bg-n-blue-3 text-n-blue-11 flex items-center justify-center flex-shrink-0"
                >
                  <fluent-icon icon="document" size="14" />
                </div>
                <div class="flex flex-col min-w-0">
                  <span
                    class="text-sm font-semibold text-n-slate-12 truncate"
                    >{{ pipeline.total_deals_count || 0 }}</span
                  >
                  <span
                    class="text-[10px] uppercase tracking-wide text-n-slate-10"
                    >Negócios</span
                  >
                </div>
              </div>
              <div class="flex items-center gap-2">
                <div
                  class="w-8 h-8 rounded-lg bg-n-teal-3 text-n-teal-11 flex items-center justify-center flex-shrink-0"
                >
                  <fluent-icon icon="money" size="14" />
                </div>
                <div class="flex flex-col min-w-0">
                  <span
                    class="text-sm font-semibold text-n-slate-12 truncate"
                    >{{ formatCurrency(pipeline.total_value || 0) }}</span
                  >
                  <span
                    class="text-[10px] uppercase tracking-wide text-n-slate-10"
                    >Valor</span
                  >
                </div>
              </div>
              <div class="flex items-center gap-2">
                <div
                  class="w-8 h-8 rounded-lg bg-n-iris-3 text-n-iris-11 flex items-center justify-center flex-shrink-0"
                >
                  <fluent-icon icon="list" size="14" />
                </div>
                <div class="flex flex-col min-w-0">
                  <span
                    class="text-sm font-semibold text-n-slate-12 truncate"
                    >{{ pipeline.stages?.length || 0 }}</span
                  >
                  <span
                    class="text-[10px] uppercase tracking-wide text-n-slate-10"
                    >Etapas</span
                  >
                </div>
              </div>
            </div>

            <!-- Stages Preview -->
            <div class="flex flex-col gap-2">
              <span
                class="text-[10px] uppercase tracking-wider text-n-slate-10 font-medium"
                >Etapas do funil:</span
              >
              <div class="flex flex-wrap gap-1.5">
                <span
                  v-for="stage in pipeline.stages?.slice(0, 4)"
                  :key="stage.id"
                  class="text-xs font-medium text-n-slate-11 bg-n-solid-3 px-2.5 py-1 rounded-full"
                >
                  {{ stage.name }}
                </span>
                <span
                  v-if="pipeline.stages?.length > 4"
                  class="text-xs font-medium text-n-slate-10 px-2.5 py-1"
                >
                  +{{ pipeline.stages.length - 4 }} mais
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Create Pipeline Modal -->
    <woot-modal v-model:show="showCreateModal" :on-close="closeCreateModal">
      <div class="p-4 min-w-[350px] sm:min-w-[400px]">
        <woot-modal-header
          :header-title="$t('CRM.PIPELINES.CREATE')"
          :header-content="$t('CRM.PIPELINES.CREATE_DESCRIPTION')"
        />
        <form @submit.prevent="createPipeline" class="mt-4">
          <div class="mb-4">
            <label class="block text-sm font-medium text-n-slate-12 mb-1.5">
              {{ $t('CRM.PIPELINES.FORM.NAME') }}
            </label>
            <input
              v-model="newPipeline.name"
              type="text"
              class="w-full px-3 py-2.5 text-sm border border-n-weak rounded-lg bg-n-solid-2 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20 transition-all"
              :placeholder="$t('CRM.PIPELINES.FORM.NAME_PLACEHOLDER')"
              required
            />
          </div>
          <div class="flex items-center gap-2 mb-4">
            <input
              v-model="newPipeline.is_default"
              type="checkbox"
              id="is_default"
              class="w-4 h-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
            />
            <label
              for="is_default"
              class="text-sm font-medium text-n-slate-11 cursor-pointer m-0"
            >
              {{ $t('CRM.PIPELINES.FORM.IS_DEFAULT') }}
            </label>
          </div>
          <div class="flex justify-end gap-2 pt-4 border-t border-n-weak">
            <woot-button variant="clear" @click.prevent="closeCreateModal">
              {{ $t('CRM.CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              color-scheme="primary"
              :is-loading="uiFlags.isCreating"
            >
              {{ $t('CRM.CREATE') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>
  </div>
</template>

<script>
import { mapGetters, mapActions } from 'vuex';
import Spinner from 'shared/components/Spinner.vue';

export default {
  name: 'DealsIndex',
  components: {
    Spinner,
  },
  data() {
    return {
      showCreateModal: false,
      newPipeline: {
        name: '',
        is_default: false,
      },
    };
  },
  computed: {
    ...mapGetters({
      pipelines: 'pipelines/getPipelines',
      uiFlags: 'pipelines/getUIFlags',
    }),
  },
  mounted() {
    this.fetchPipelines();
  },
  methods: {
    ...mapActions({
      fetchPipelines: 'pipelines/get',
      createPipelineAction: 'pipelines/create',
    }),
    openPipeline(pipeline) {
      this.$router.push({
        name: 'deals_kanban',
        params: {
          accountId: this.$route.params.accountId,
          pipelineId: pipeline.id,
        },
      });
    },
    openCreatePipelineModal() {
      this.showCreateModal = true;
    },
    closeCreateModal() {
      this.showCreateModal = false;
      this.newPipeline = { name: '', is_default: false };
    },
    async createPipeline() {
      try {
        const pipeline = await this.createPipelineAction(this.newPipeline);
        this.closeCreateModal();
        this.openPipeline(pipeline);
      } catch (error) {
        this.$toast.error(
          error.message || this.$t('CRM.PIPELINES.CREATE_ERROR')
        );
      }
    },
    formatCurrency(value) {
      if (value >= 1000) {
        return 'R$ ' + (value / 1000).toFixed(1) + 'k';
      }
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL',
        minimumFractionDigits: 0,
        maximumFractionDigits: 0,
      }).format(value);
    },
  },
};
</script>

<style scoped>
.animate-fadeIn {
  animation: fadeIn 0.4s ease-out;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>
