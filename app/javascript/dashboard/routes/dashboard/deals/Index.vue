<template>
  <div class="flex flex-col flex-1 h-full">
    <!-- Redirecting to default pipeline — show skeleton only -->
    <div v-if="uiFlags.isFetching || isRedirecting" class="flex flex-1 gap-4 p-4 animate-pulse">
      <div
        v-for="i in 5"
        :key="i"
        class="flex flex-col min-w-[280px] flex-1 rounded-xl border border-n-weak bg-n-solid-2"
      >
        <div class="px-3 py-3 border-b border-n-weak">
          <div class="h-4 w-24 bg-n-alpha-2 rounded" />
        </div>
        <div class="flex flex-col gap-3 p-3">
          <div
            v-for="j in (3 + i % 2)"
            :key="j"
            class="h-20 bg-n-alpha-2 rounded-lg"
          />
        </div>
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

export default {
  name: 'DealsIndex',
  data() {
    return {
      showCreateModal: false,
      isRedirecting: true,
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
  async mounted() {
    await this.fetchPipelines();
    this.redirectToDefaultPipeline();
  },
  methods: {
    ...mapActions({
      fetchPipelines: 'pipelines/get',
      createPipelineAction: 'pipelines/create',
    }),
    redirectToDefaultPipeline() {
      if (!this.pipelines.length) {
        this.isRedirecting = false;
        return;
      }

      const defaultPipeline =
        this.pipelines.find(p => p.is_default) || this.pipelines[0];
      this.openPipeline(defaultPipeline);
    },
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
