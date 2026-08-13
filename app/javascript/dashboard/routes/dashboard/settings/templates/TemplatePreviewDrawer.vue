<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import {
  TemplateNormalizer,
  TemplatePreview,
} from 'dashboard/components-next/template-preview';
import { PLATFORMS } from 'dashboard/services/TemplateConstants';
import {
  formatTemplateDate,
  formatTemplateLabel,
  formatTemplateLanguage,
  templateStatusClasses,
  templateTypeKey,
} from './templateUtils';

const props = defineProps({
  template: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['deleted', 'edit']);

const { t } = useI18n();
const META_TEMPLATE_MANAGER_URL =
  'https://business.facebook.com/latest/whatsapp_manager/message_templates';
const TWILIO_TEMPLATE_MANAGER_URL =
  'https://console.twilio.com/us1/develop/sms/content-editor';

const panelRef = ref(null);

const platform = computed(() => props.template?.platform || PLATFORMS.WHATSAPP);
const normalizedTemplate = computed(() =>
  props.template
    ? TemplateNormalizer.normalize(props.template, platform.value)
    : null
);
const variables = computed(() => normalizedTemplate.value?.variables || {});
const managementUrl = computed(() => {
  if (platform.value === PLATFORMS.TWILIO) {
    return TWILIO_TEMPLATE_MANAGER_URL;
  }

  return props.template?.inboxes?.some(
    inbox => inbox.provider === 'whatsapp_cloud'
  )
    ? META_TEMPLATE_MANAGER_URL
    : null;
});
const managementLabel = computed(() =>
  platform.value === PLATFORMS.TWILIO
    ? t('WHATSAPP_TEMPLATE_MGMT.MANAGE_IN_TWILIO')
    : t('WHATSAPP_TEMPLATE_MGMT.MANAGE_IN_META')
);
// Only Cloud API inboxes can be deleted from here; a grouped template can span
// several inboxes, so we delete it on each one (they may sit on different WABAs).
const deletableInboxes = computed(() =>
  (props.template?.inboxes || []).filter(
    inbox => inbox.provider === 'whatsapp_cloud'
  )
);
const canDelete = computed(() => deletableInboxes.value.length > 0);

// Meta only accepts content edits on marketing templates, and never while a
// submission is still under review.
const canEdit = computed(
  () =>
    canDelete.value &&
    props.template?.category?.toUpperCase() === 'MARKETING' &&
    props.template?.status?.toUpperCase() !== 'PENDING'
);

const handleEdit = () => {
  emit('edit', {
    template: props.template,
    inboxId: deletableInboxes.value[0]?.id,
  });
  panelRef.value?.close();
};

const confirmDeleteDialogRef = ref(null);
const isDeleting = ref(false);

const handleDelete = async () => {
  isDeleting.value = true;
  try {
    const results = await Promise.allSettled(
      deletableInboxes.value.map(inbox =>
        InboxesAPI.deleteMessageTemplate(inbox.id, props.template.name)
      )
    );

    if (results.every(result => result.status === 'rejected')) {
      throw results[0].reason;
    }

    useAlert(t('WHATSAPP_TEMPLATE_MGMT.DELETE_SUCCESS'));
    confirmDeleteDialogRef.value?.close();
    panelRef.value?.close();
    emit('deleted');
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('WHATSAPP_TEMPLATE_MGMT.DELETE_ERROR')
    );
  } finally {
    isDeleting.value = false;
  }
};

const open = () => panelRef.value?.open();
const close = () => panelRef.value?.close();

defineExpose({ open, close });
</script>

<template>
  <SidePanel
    ref="panelRef"
    width="md"
    :title="template?.name"
    :description="$t('WHATSAPP_TEMPLATE_MGMT.PREVIEW.DESCRIPTION')"
  >
    <div v-if="template" class="flex flex-col gap-6">
      <div
        class="flex items-center justify-center px-6 py-10 border rounded-xl min-h-80 border-n-weak bg-n-alpha-1"
      >
        <TemplatePreview
          :template="template"
          :variables="variables"
          :platform="platform"
        />
      </div>

      <div>
        <h3 class="text-sm font-medium text-n-slate-12">
          {{ $t('WHATSAPP_TEMPLATE_MGMT.PREVIEW.DETAILS') }}
        </h3>
        <dl class="grid grid-cols-[8rem_1fr] gap-x-4 gap-y-3 mt-4 text-sm">
          <dt class="text-n-slate-10">
            {{ $t('WHATSAPP_TEMPLATE_MGMT.PREVIEW.STATUS') }}
          </dt>
          <dd>
            <span
              class="inline-flex px-2 py-0.5 text-xs font-medium rounded-md"
              :class="templateStatusClasses(template.status)"
            >
              {{ formatTemplateLabel(template.status) }}
            </span>
          </dd>
          <dt class="text-n-slate-10">
            {{ $t('WHATSAPP_TEMPLATE_MGMT.PREVIEW.TYPE') }}
          </dt>
          <dd class="text-n-slate-12">
            {{
              $t(`WHATSAPP_TEMPLATE_MGMT.TYPES.${templateTypeKey(template)}`)
            }}
          </dd>
          <dt class="text-n-slate-10">
            {{ $t('WHATSAPP_TEMPLATE_MGMT.PREVIEW.CATEGORY') }}
          </dt>
          <dd class="text-n-slate-12">
            {{ formatTemplateLabel(template.category) }}
          </dd>
          <dt class="text-n-slate-10">
            {{ $t('WHATSAPP_TEMPLATE_MGMT.PREVIEW.LANGUAGE') }}
          </dt>
          <dd class="text-n-slate-12">
            {{ formatTemplateLanguage(template.language) }}
          </dd>
          <dt class="text-n-slate-10">
            {{ $t('WHATSAPP_TEMPLATE_MGMT.PREVIEW.INBOXES') }}
          </dt>
          <dd class="text-n-slate-12">{{ template.inboxNames }}</dd>
          <dt class="text-n-slate-10">
            {{ $t('WHATSAPP_TEMPLATE_MGMT.PREVIEW.LAST_SYNC_ATTEMPT') }}
          </dt>
          <dd class="text-n-slate-12">
            {{ formatTemplateDate(template.lastUpdatedAt) }}
          </dd>
        </dl>
      </div>
    </div>

    <template v-if="managementUrl || canDelete || canEdit" #footer>
      <div class="flex flex-col w-full gap-2">
        <a
          v-if="managementUrl"
          :href="managementUrl"
          target="_blank"
          rel="noopener noreferrer"
        >
          <Button
            class="w-full"
            :label="managementLabel"
            icon="i-lucide-external-link"
            trailing-icon
          />
        </a>
        <Button
          v-if="canEdit"
          class="w-full"
          variant="faded"
          color="slate"
          icon="i-lucide-pencil"
          :label="$t('WHATSAPP_TEMPLATE_MGMT.EDIT.BUTTON')"
          @click="handleEdit"
        />
        <Button
          v-if="canDelete"
          class="w-full"
          variant="faded"
          color="ruby"
          icon="i-lucide-trash"
          :label="$t('WHATSAPP_TEMPLATE_MGMT.DELETE.BUTTON')"
          @click="confirmDeleteDialogRef?.open()"
        />
      </div>
    </template>

    <Dialog
      ref="confirmDeleteDialogRef"
      type="alert"
      :title="$t('WHATSAPP_TEMPLATE_MGMT.DELETE.TITLE')"
      :description="
        $t('WHATSAPP_TEMPLATE_MGMT.DELETE.DESCRIPTION', {
          name: template?.name,
        })
      "
      :confirm-button-label="$t('WHATSAPP_TEMPLATE_MGMT.DELETE.CONFIRM')"
      :is-loading="isDeleting"
      @confirm="handleDelete"
    />
  </SidePanel>
</template>
