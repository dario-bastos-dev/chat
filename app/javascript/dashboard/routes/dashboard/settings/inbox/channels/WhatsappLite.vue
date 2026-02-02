<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Evolution from './Evolution.vue';
import ChannelSelector from 'dashboard/components/ChannelSelector.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const PROVIDER_TYPES = {
  EVOLUTION: 'evolution',
};

const selectedProvider = computed(() => route.query.provider);

const showProviderSelection = computed(() => !selectedProvider.value);

const showConfiguration = computed(() => Boolean(selectedProvider.value));

const availableProviders = computed(() => [
  {
    key: PROVIDER_TYPES.EVOLUTION,
    title: t('INBOX_MGMT.ADD.WHATSAPP_LITE.PROVIDERS.EVOLUTION'),
    description: t('INBOX_MGMT.ADD.WHATSAPP_LITE.PROVIDERS.EVOLUTION_DESC'),
    icon: 'i-evolution-fill',
  },
]);

const selectProvider = providerValue => {
  router.push({
    name: route.name,
    params: route.params,
    query: { provider: providerValue },
  });
};
</script>

<template>
  <div class="overflow-auto col-span-6 p-6 w-full h-full">
    <div v-if="showProviderSelection">
      <div class="mb-10 text-left">
        <h1 class="mb-2 text-lg font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_LITE.SELECT_PROVIDER.TITLE') }}
        </h1>
        <p class="text-sm leading-relaxed text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_LITE.SELECT_PROVIDER.DESCRIPTION') }}
        </p>
      </div>

      <div class="flex gap-6 justify-start">
        <ChannelSelector
          v-for="provider in availableProviders"
          :key="provider.key"
          :title="provider.title"
          :description="provider.description"
          :icon="provider.icon"
          @click="selectProvider(provider.key)"
        />
      </div>
    </div>

    <div v-else-if="showConfiguration">
      <div class="px-6 py-5 rounded-2xl border border-n-weak">
        <Evolution v-if="selectedProvider === PROVIDER_TYPES.EVOLUTION" />
      </div>
    </div>
  </div>
</template>
