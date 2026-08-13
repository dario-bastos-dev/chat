<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TemplateForm from './TemplateForm.vue';

const props = defineProps({
  // Only whatsapp_cloud inboxes can manage templates through the Cloud API.
  inboxes: { type: Array, default: () => [] },
});

const emit = defineEmits(['saved']);

const { t } = useI18n();

const panelRef = ref(null);
const formRef = ref(null);
const isSubmitting = ref(false);
const selectedInboxId = ref(null);
const editingTemplate = ref(null);

const isEditing = computed(() => Boolean(editingTemplate.value));

const inboxOptions = computed(() =>
  props.inboxes.map(inbox => ({ value: inbox.id, label: inbox.name }))
);

// Keep a valid inbox selected as the list loads or changes.
watch(
  () => props.inboxes,
  list => {
    if (isEditing.value) return;
    const stillThere = list.some(inbox => inbox.id === selectedInboxId.value);
    if (!stillThere) selectedInboxId.value = list[0]?.id ?? null;
  },
  { immediate: true }
);

const handleSubmit = async payload => {
  if (!selectedInboxId.value) return;

  isSubmitting.value = true;
  try {
    if (isEditing.value) {
      await InboxesAPI.updateMessageTemplate(
        selectedInboxId.value,
        editingTemplate.value.name,
        editingTemplate.value.language,
        payload
      );
      useAlert(t('WHATSAPP_TEMPLATE_MGMT.UPDATE_SUCCESS'));
    } else {
      await InboxesAPI.createMessageTemplate(selectedInboxId.value, payload);
      useAlert(t('WHATSAPP_TEMPLATE_MGMT.CREATE_SUCCESS'));
    }
    panelRef.value?.close();
    emit('saved');
  } catch (error) {
    const fallback = isEditing.value
      ? 'WHATSAPP_TEMPLATE_MGMT.UPDATE_ERROR'
      : 'WHATSAPP_TEMPLATE_MGMT.CREATE_ERROR';
    useAlert(error?.response?.data?.error || t(fallback));
  } finally {
    isSubmitting.value = false;
  }
};

// Called with a template to edit it, or with nothing to create a new one.
const open = (template = null, inboxId = null) => {
  editingTemplate.value = template;
  if (inboxId) selectedInboxId.value = inboxId;
  formRef.value?.load(template);
  panelRef.value?.open();
};
const close = () => panelRef.value?.close();

defineExpose({ open, close });
</script>

<template>
  <SidePanel
    ref="panelRef"
    width="2xl"
    :title="
      isEditing
        ? $t('WHATSAPP_TEMPLATE_MGMT.EDIT.TITLE')
        : $t('WHATSAPP_TEMPLATE_MGMT.CREATE.TITLE')
    "
    :description="
      isEditing
        ? $t('WHATSAPP_TEMPLATE_MGMT.EDIT.DESCRIPTION')
        : $t('WHATSAPP_TEMPLATE_MGMT.CREATE.DESCRIPTION')
    "
  >
    <div class="flex flex-col gap-5">
      <div v-if="!isEditing" class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('WHATSAPP_TEMPLATE_MGMT.CREATE.INBOX') }}
        </label>
        <Select v-model="selectedInboxId" :options="inboxOptions" />
      </div>

      <TemplateForm
        v-if="selectedInboxId"
        ref="formRef"
        :inbox-id="selectedInboxId"
        :template="editingTemplate"
        :is-submitting="isSubmitting"
        @submit="handleSubmit"
        @cancel="close"
      />
    </div>
  </SidePanel>
</template>
