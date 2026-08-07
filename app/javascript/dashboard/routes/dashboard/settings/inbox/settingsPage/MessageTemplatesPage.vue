<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import MessageTemplateList from './components/MessageTemplateList.vue';
import MessageTemplateForm from './components/MessageTemplateForm.vue';

const props = defineProps({
  inbox: { type: Object, default: () => ({}) },
});

const { t } = useI18n();

const templates = ref([]);
const isLoading = ref(false);
const isSubmitting = ref(false);
const isFormVisible = ref(false);
const formRef = ref(null);

const hasTemplates = computed(() => templates.value.length > 0);

const fetchTemplates = async () => {
  isLoading.value = true;
  try {
    const { data } = await InboxesAPI.getMessageTemplates(props.inbox.id);
    templates.value = data.payload || [];
  } catch (_) {
    useAlert(t('INBOX_MGMT.MESSAGE_TEMPLATES.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const showForm = () => {
  formRef.value?.reset();
  isFormVisible.value = true;
};

const handleSubmit = async payload => {
  isSubmitting.value = true;
  try {
    await InboxesAPI.createMessageTemplate(props.inbox.id, payload);
    useAlert(t('INBOX_MGMT.MESSAGE_TEMPLATES.CREATE_SUCCESS'));
    isFormVisible.value = false;
    await fetchTemplates();
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('INBOX_MGMT.MESSAGE_TEMPLATES.CREATE_ERROR')
    );
  } finally {
    isSubmitting.value = false;
  }
};

const handleDelete = async template => {
  try {
    await InboxesAPI.deleteMessageTemplate(props.inbox.id, template.name);
    useAlert(t('INBOX_MGMT.MESSAGE_TEMPLATES.DELETE_SUCCESS'));
    await fetchTemplates();
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('INBOX_MGMT.MESSAGE_TEMPLATES.DELETE_ERROR')
    );
  }
};

onMounted(fetchTemplates);
</script>

<template>
  <div class="flex flex-col gap-6 mx-6 max-w-4xl">
    <div class="flex gap-4 justify-between items-start">
      <div class="flex flex-col gap-1">
        <h3 class="text-base font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.MESSAGE_TEMPLATES.TITLE') }}
        </h3>
        <span class="text-sm text-n-slate-11">
          {{ $t('INBOX_MGMT.MESSAGE_TEMPLATES.DESCRIPTION') }}
        </span>
      </div>
      <NextButton
        v-if="!isFormVisible"
        icon="i-lucide-plus"
        :label="$t('INBOX_MGMT.MESSAGE_TEMPLATES.NEW_TEMPLATE')"
        @click="showForm"
      />
    </div>

    <MessageTemplateForm
      v-show="isFormVisible"
      ref="formRef"
      :inbox-id="inbox.id"
      :is-submitting="isSubmitting"
      @submit="handleSubmit"
      @cancel="isFormVisible = false"
    />

    <div v-if="isLoading" class="flex justify-center py-8">
      <Spinner class="size-5 text-n-slate-11" />
    </div>
    <MessageTemplateList
      v-else-if="hasTemplates"
      :templates="templates"
      @delete="handleDelete"
    />
    <span v-else class="py-8 text-sm text-center text-n-slate-11">
      {{ $t('INBOX_MGMT.MESSAGE_TEMPLATES.EMPTY_STATE') }}
    </span>
  </div>
</template>
