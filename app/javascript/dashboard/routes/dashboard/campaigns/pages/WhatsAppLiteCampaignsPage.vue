<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';
import WhatsAppLiteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppLiteCampaignDialog.vue';
import ConfirmDeleteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ConfirmDeleteCampaignDialog.vue';
import WhatsAppCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/WhatsAppCampaignEmptyState.vue';

const { t } = useI18n();
const getters = useStoreGetters();

const selectedCampaign = ref(null);
const [showWhatsAppLiteCampaignDialog, toggleWhatsAppLiteCampaignDialog] = useToggle();

const uiFlags = useMapGetter('campaigns/getUIFlags');
const isFetchingCampaigns = computed(() => uiFlags.value.isFetching);

const confirmDeleteCampaignDialogRef = ref(null);

// Use the new getter for Lite campaigns
const WhatsAppLiteCampaigns = computed(
  () => getters['campaigns/getWhatsAppLiteCampaigns'].value
);

const hasNoWhatsAppLiteCampaigns = computed(
  () => WhatsAppLiteCampaigns.value?.length === 0 && !isFetchingCampaigns.value
);

const handleDelete = campaign => {
  selectedCampaign.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
};
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.WHATSAPP_LITE.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.WHATSAPP_LITE.NEW_CAMPAIGN')"
    @click="toggleWhatsAppLiteCampaignDialog()"
    @close="toggleWhatsAppLiteCampaignDialog(false)"
  >
    <template #action>
      <WhatsAppLiteCampaignDialog
        v-if="showWhatsAppLiteCampaignDialog"
        @close="toggleWhatsAppLiteCampaignDialog(false)"
      />
    </template>
    <div
      v-if="isFetchingCampaigns"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <CampaignList
      v-else-if="!hasNoWhatsAppLiteCampaigns"
      :campaigns="WhatsAppLiteCampaigns"
      @delete="handleDelete"
    />
    <WhatsAppCampaignEmptyState
      v-else
      :title="t('CAMPAIGN.WHATSAPP_LITE.EMPTY_STATE.TITLE')"
      :subtitle="t('CAMPAIGN.WHATSAPP_LITE.EMPTY_STATE.SUBTITLE')"
      class="pt-14"
    />
    <ConfirmDeleteCampaignDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaign"
    />
  </CampaignLayout>
</template>
