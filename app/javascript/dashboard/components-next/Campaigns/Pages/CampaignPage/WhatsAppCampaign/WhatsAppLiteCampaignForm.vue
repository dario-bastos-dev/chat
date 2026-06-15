<script setup>
import { reactive, computed, watch, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, requiredIf } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';
import CampaignsAPI from 'dashboard/api/campaigns';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';


const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  inboxes: useMapGetter('inboxes/getWhatsAppLiteInboxes'),
};

const getInitialState = () => ({
  title: '',
  inboxId: null,
  message: '',
  scheduledAt: null,
  selectedAudience: [],
  targetType: 'contacts',
  isScheduled: false,
  file: null,
  cadenceInterval: 2,
  pauseAfter: null,
});

const state = reactive(getInitialState());

const audienceEstimate = ref(0);
const isLoadingEstimate = ref(false);

const rules = {
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  message: {
    required: requiredIf(() => !state.file),
  },
  scheduledAt: {
    required: requiredIf(() => state.isScheduled),
  },
  selectedAudience: { required },
};

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  // Added to disable the scheduled at field from being set to the current time
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const audienceList = computed(() =>
  mapToOptions(formState.labels.value, 'id', 'title')
);

const inboxOptions = computed(() =>
  mapToOptions(formState.inboxes.value, 'id', 'name')
);

const getErrorMessage = (field, errorKey) => {
  const baseKey = 'CAMPAIGN.WHATSAPP_LITE.CREATE.FORM';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  message: getErrorMessage('message', 'MESSAGE'),
  scheduledAt: getErrorMessage('scheduledAt', 'SCHEDULED_AT'),
  audience: getErrorMessage('selectedAudience', 'AUDIENCE'),
}));

const isSubmitDisabled = computed(() => v$.value.$invalid);

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const resetState = () => {
  Object.assign(state, getInitialState());
  v$.value.$reset();
};

const handleCancel = () => emit('cancel');

const handleFileUpload = event => {
  const file = event.target.files[0];
  if (file) {
    state.file = file;
  }
};

let estimateTimeout = null;
watch(
  () => [state.selectedAudience, state.inboxId, state.targetType],
  () => {
    if (estimateTimeout) clearTimeout(estimateTimeout);
    if (!state.inboxId || !state.selectedAudience?.length) {
      audienceEstimate.value = 0;
      return;
    }
    isLoadingEstimate.value = true;
    estimateTimeout = setTimeout(async () => {
      try {
        const response = await CampaignsAPI.getAudienceEstimate({
          inboxId: state.inboxId,
          targetType: state.targetType,
          labelIds: state.selectedAudience,
        });
        audienceEstimate.value = response.data.count;
      } catch {
        audienceEstimate.value = 0;
      } finally {
        isLoadingEstimate.value = false;
      }
    }, 500);
  },
  { deep: true }
);

const prepareCampaignDetails = () => {
  if (state.file) {
    const formData = new FormData();
    formData.append('campaign[title]', state.title);
    formData.append('campaign[message]', state.message);
    formData.append('campaign[inbox_id]', state.inboxId);
    formData.append('campaign[cadence_interval]', state.cadenceInterval);

    if (state.pauseAfter !== null && state.pauseAfter !== '') {
      formData.append('campaign[pause_after]', state.pauseAfter);
    }
    
    if (state.isScheduled && state.scheduledAt) {
      formData.append('campaign[scheduled_at]', formatToUTCString(state.scheduledAt));
    }

    formData.append('campaign[audience][0][type]', 'Target');
    formData.append('campaign[audience][0][value]', state.targetType);
    
    state.selectedAudience?.forEach((id, index) => {
      formData.append(`campaign[audience][${index + 1}][id]`, id);
      formData.append(`campaign[audience][${index + 1}][type]`, 'Label');
    });

    formData.append('campaign[attachments][]', state.file);
    return formData;
  }

  return {
    title: state.title,
    message: state.message,
    inbox_id: state.inboxId,
    cadence_interval: state.cadenceInterval,
    pause_after: state.pauseAfter !== null && state.pauseAfter !== '' ? state.pauseAfter : null,
    scheduled_at: state.isScheduled
      ? formatToUTCString(state.scheduledAt)
      : null,
    audience: [
      { type: 'Target', value: state.targetType },
      ...state.selectedAudience?.map(id => ({
        id,
        type: 'Label',
      }))
    ],
  };
};

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.TITLE.LABEL')"
      :placeholder="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.INBOX.PLACEHOLDER')"
        :message="formErrors.inbox"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <TextArea
      v-model="state.message"
      :label="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.MESSAGE.LABEL')"
      :placeholder="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.MESSAGE.PLACEHOLDER')"
      :message="formErrors.message"
      :message-type="formErrors.message ? 'error' : 'info'"
      class="min-h-[100px]"
    />

    <div class="flex flex-col gap-1">
      <label for="audience" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.AUDIENCE.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        v-model="state.selectedAudience"
        :options="audienceList"
        :label="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.AUDIENCE.LABEL')"
        :placeholder="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.AUDIENCE.PLACEHOLDER')"
        :has-error="!!formErrors.audience"
        :message="formErrors.audience"
        class="[&>div>button]:bg-n-alpha-black2"
      />
    </div>

    <div
      v-if="audienceEstimate > 0"
      class="flex items-center gap-2 px-3 py-2 rounded-lg bg-n-alpha-2"
    >
      <span class="i-lucide-users text-n-slate-11 size-4" />
      <span class="text-sm text-n-slate-11">
        {{ t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.AUDIENCE_ESTIMATE', { count: audienceEstimate }) }}
      </span>
    </div>

    <div class="flex flex-col gap-2 mt-2 mb-2">
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.TARGET_TYPE.LABEL') }}
      </label>
      <div class="flex gap-4">
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            v-model="state.targetType"
            type="radio"
            name="targetLiteType"
            value="contacts"
            class="size-4 accent-n-blue-9"
          />
          <span class="text-sm text-n-slate-12">
            {{ t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.TARGET_TYPE.CONTACTS') }}
          </span>
        </label>
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            v-model="state.targetType"
            type="radio"
            name="targetLiteType"
            value="conversations"
            class="size-4 accent-n-blue-9"
          />
          <span class="text-sm text-n-slate-12">
            {{ t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.TARGET_TYPE.CONVERSATIONS') }}
          </span>
        </label>
      </div>
    </div>

    <Input
      v-model.number="state.cadenceInterval"
      :label="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.CADENCE_INTERVAL.LABEL')"
      :placeholder="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.CADENCE_INTERVAL.PLACEHOLDER')"
      type="number"
      min="1"
    />

    <Input
      v-model.number="state.pauseAfter"
      :label="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.PAUSE_AFTER.LABEL')"
      :placeholder="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.PAUSE_AFTER.PLACEHOLDER')"
      type="number"
      min="1"
    />
    <p class="text-xs text-n-slate-10 -mt-2">
      {{ t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.PAUSE_AFTER.HINT') }}
    </p>

    <div class="flex flex-col gap-1">
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.ATTACHMENT.LABEL') }}
      </label>
      <input 
        type="file" 
        accept="image/*,audio/*,application/pdf"
        class="block w-full text-sm text-n-slate-11 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-n-alpha-2 file:text-n-slate-12 hover:file:bg-n-alpha-3"
        @change="handleFileUpload" 
      />
      <p class="text-xs text-n-slate-10 mt-1">
        {{ t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.ATTACHMENT.HINT') }}
      </p>
    </div>

    <div class="flex items-center gap-3">
      <Switch v-model="state.isScheduled" />
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.SCHEDULE_CAMPAIGN') }}
      </label>
    </div>

    <Input
      v-if="state.isScheduled"
      v-model="state.scheduledAt"
      :label="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.SCHEDULED_AT.LABEL')"
      type="datetime-local"
      :min="currentDateTime"
      :placeholder="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')"
      :message="formErrors.scheduledAt"
      :message-type="formErrors.scheduledAt ? 'error' : 'info'"
    />

    <div class="flex gap-3 justify-between items-center w-full">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.BUTTONS.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-text hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        :label="t('CAMPAIGN.WHATSAPP_LITE.CREATE.FORM.BUTTONS.CREATE')"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
