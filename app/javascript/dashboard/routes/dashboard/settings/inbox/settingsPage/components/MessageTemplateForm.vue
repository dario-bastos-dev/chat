<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';
import MessageTemplatePreview from './MessageTemplatePreview.vue';

const props = defineProps({
  inboxId: { type: [Number, String], required: true },
  isSubmitting: { type: Boolean, default: false },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

// AUTHENTICATION is intentionally absent: Meta only accepts it with an OTP
// button, which is not supported here yet.
const CATEGORIES = ['UTILITY', 'MARKETING'];
const BUTTON_TEXT_MAX_LENGTH = 25;
const LANGUAGES = ['pt_BR', 'en', 'en_US', 'es', 'es_ES'];
const BUTTON_TYPES = ['QUICK_REPLY', 'URL', 'PHONE_NUMBER'];
const HEADER_FORMATS = ['TEXT', 'IMAGE', 'VIDEO', 'DOCUMENT'];
const MEDIA_ACCEPT = {
  IMAGE: 'image/jpeg,image/png',
  VIDEO: 'video/mp4,video/3gpp',
  DOCUMENT: 'application/pdf',
};

const buildInitialState = () => ({
  name: '',
  category: 'UTILITY',
  language: 'pt_BR',
  headerFormat: 'TEXT',
  headerText: '',
  headerExample: '',
  mediaHandle: '',
  mediaFileName: '',
  bodyText: '',
  bodyExample: '',
  footerText: '',
  buttons: [],
});

const form = reactive(buildInitialState());
const errorMessage = ref('');
const isUploading = ref(false);
const fileInputRef = ref(null);

const isMediaHeader = computed(() => form.headerFormat !== 'TEXT');
const mediaAccept = computed(() => MEDIA_ACCEPT[form.headerFormat] || '');

const categoryOptions = computed(() =>
  CATEGORIES.map(value => ({
    value,
    label: t(`INBOX_MGMT.MESSAGE_TEMPLATES.CATEGORIES.${value}`),
  }))
);
const languageOptions = computed(() =>
  LANGUAGES.map(value => ({ value, label: value }))
);
const headerFormatOptions = computed(() =>
  HEADER_FORMATS.map(value => ({
    value,
    label: t(`INBOX_MGMT.MESSAGE_TEMPLATES.HEADER_FORMATS.${value}`),
  }))
);
const buttonTypeOptions = computed(() =>
  BUTTON_TYPES.map(value => ({
    value,
    label: t(`INBOX_MGMT.MESSAGE_TEMPLATES.BUTTON_TYPES.${value}`),
  }))
);

const countVariables = text => (text.match(/\{\{\d+\}\}/g) || []).length;

const splitExamples = value =>
  value
    .split('|')
    .map(sample => sample.trim())
    .filter(Boolean);

const bodyVariableCount = computed(() => countVariables(form.bodyText));
const headerVariableCount = computed(() => countVariables(form.headerText));

const previewHeader = computed(() => ({
  format: form.headerFormat,
  text: form.headerText,
  example: splitExamples(form.headerExample),
  fileName: form.mediaFileName,
}));
const previewBody = computed(() => ({
  text: form.bodyText,
  example: splitExamples(form.bodyExample),
}));
const previewFooter = computed(() => ({ text: form.footerText }));

const addButton = () => {
  form.buttons.push({
    type: 'QUICK_REPLY',
    text: '',
    url: '',
    phone_number: '',
  });
};

const removeButton = index => {
  form.buttons.splice(index, 1);
};

const handleHeaderFormatChange = () => {
  form.mediaHandle = '';
  form.mediaFileName = '';
  if (isMediaHeader.value) {
    form.headerText = '';
    form.headerExample = '';
  }
};

const handleFileSelect = async event => {
  const [file] = event.target.files || [];
  if (!file) return;

  isUploading.value = true;
  try {
    const { data } = await InboxesAPI.uploadMessageTemplateMedia(
      props.inboxId,
      file,
      form.headerFormat
    );
    form.mediaHandle = data.handle;
    form.mediaFileName = file.name;
  } catch (error) {
    form.mediaHandle = '';
    form.mediaFileName = '';
    useAlert(
      error?.response?.data?.error ||
        t('INBOX_MGMT.MESSAGE_TEMPLATES.ERRORS.UPLOAD_FAILED')
    );
  } finally {
    isUploading.value = false;
    if (fileInputRef.value) fileInputRef.value.value = '';
  }
};

// Meta accepts at most one variable per URL button, and only at the very end.
const isValidButtonUrl = url => {
  if (!url?.trim()) return false;
  const variables = url.match(/\{\{\d+\}\}/g) || [];
  if (!variables.length) return true;
  return variables.length === 1 && url.endsWith(variables[0]);
};

const validate = () => {
  if (!/^[a-z0-9_]{1,512}$/.test(form.name)) {
    return t('INBOX_MGMT.MESSAGE_TEMPLATES.ERRORS.INVALID_NAME');
  }
  if (!form.bodyText.trim()) {
    return t('INBOX_MGMT.MESSAGE_TEMPLATES.ERRORS.BODY_REQUIRED');
  }
  if (splitExamples(form.bodyExample).length !== bodyVariableCount.value) {
    return t('INBOX_MGMT.MESSAGE_TEMPLATES.ERRORS.BODY_EXAMPLE_MISMATCH');
  }
  if (isMediaHeader.value && !form.mediaHandle) {
    return t('INBOX_MGMT.MESSAGE_TEMPLATES.ERRORS.MEDIA_REQUIRED');
  }
  if (
    !isMediaHeader.value &&
    splitExamples(form.headerExample).length !== headerVariableCount.value
  ) {
    return t('INBOX_MGMT.MESSAGE_TEMPLATES.ERRORS.HEADER_EXAMPLE_MISMATCH');
  }
  if (form.buttons.some(button => !button.text.trim())) {
    return t('INBOX_MGMT.MESSAGE_TEMPLATES.ERRORS.BUTTON_LABEL_REQUIRED');
  }
  if (
    form.buttons.some(button => button.text.length > BUTTON_TEXT_MAX_LENGTH)
  ) {
    return t('INBOX_MGMT.MESSAGE_TEMPLATES.ERRORS.BUTTON_LABEL_TOO_LONG');
  }
  const invalidUrlButton = form.buttons.find(
    button => button.type === 'URL' && !isValidButtonUrl(button.url)
  );
  if (invalidUrlButton) {
    return t('INBOX_MGMT.MESSAGE_TEMPLATES.ERRORS.INVALID_BUTTON_URL');
  }
  return '';
};

const buildPayload = () => {
  const payload = {
    name: form.name,
    category: form.category,
    language: form.language,
    body: { text: form.bodyText, example: splitExamples(form.bodyExample) },
  };

  if (isMediaHeader.value) {
    payload.header = {
      format: form.headerFormat,
      media_handle: form.mediaHandle,
    };
  } else if (form.headerText.trim()) {
    payload.header = {
      format: 'TEXT',
      text: form.headerText,
      example: splitExamples(form.headerExample),
    };
  }
  if (form.footerText.trim()) {
    payload.footer = { text: form.footerText };
  }
  if (form.buttons.length) {
    payload.buttons = form.buttons.map(button => {
      if (button.type === 'URL') {
        // Meta expects the sample as the full URL with the variable filled in.
        const example = countVariables(button.url)
          ? [button.url.replace(/\{\{\d+\}\}/, '123')]
          : [];
        return { type: 'URL', text: button.text, url: button.url, example };
      }
      if (button.type === 'PHONE_NUMBER') {
        return {
          type: 'PHONE_NUMBER',
          text: button.text,
          phone_number: button.phone_number,
        };
      }
      return { type: 'QUICK_REPLY', text: button.text };
    });
  }

  return payload;
};

const handleSubmit = () => {
  errorMessage.value = validate();
  if (errorMessage.value) return;

  emit('submit', buildPayload());
};

const reset = () => {
  Object.assign(form, buildInitialState());
  errorMessage.value = '';
};

defineExpose({ reset });
</script>

<template>
  <div class="flex flex-col gap-5">
    <div class="grid gap-4 sm:grid-cols-3">
      <Input
        v-model="form.name"
        :label="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.NAME.LABEL')"
        :placeholder="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.NAME.PLACEHOLDER')"
        :message="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.NAME.HELP')"
      />
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.CATEGORY.LABEL') }}
        </label>
        <Select v-model="form.category" :options="categoryOptions" />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.LANGUAGE.LABEL') }}
        </label>
        <Select v-model="form.language" :options="languageOptions" />
      </div>
    </div>

    <div class="flex flex-col gap-3">
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.HEADER_FORMAT.LABEL') }}
        </label>
        <Select
          v-model="form.headerFormat"
          :options="headerFormatOptions"
          @update:model-value="handleHeaderFormatChange"
        />
      </div>

      <div v-if="isMediaHeader" class="flex gap-3 items-center">
        <input
          ref="fileInputRef"
          type="file"
          class="text-sm text-n-slate-11 file:mr-3 file:px-3 file:py-1.5 file:rounded-lg file:border-0 file:bg-n-slate-3 file:text-n-slate-12"
          :accept="mediaAccept"
          :disabled="isUploading"
          @change="handleFileSelect"
        />
        <span v-if="isUploading" class="text-sm text-n-slate-11">
          {{ $t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.UPLOADING') }}
        </span>
        <span v-else-if="form.mediaFileName" class="text-sm text-n-teal-11">
          {{ form.mediaFileName }}
        </span>
      </div>

      <div v-else class="grid gap-4 sm:grid-cols-2">
        <Input
          v-model="form.headerText"
          :label="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.HEADER.LABEL')"
          :placeholder="
            $t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.HEADER.PLACEHOLDER')
          "
        />
        <Input
          v-if="headerVariableCount"
          v-model="form.headerExample"
          :label="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.HEADER_EXAMPLE.LABEL')"
          :message="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.EXAMPLE_HELP')"
        />
      </div>
    </div>

    <TextArea
      v-model="form.bodyText"
      :label="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.BODY.LABEL')"
      :placeholder="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.BODY.PLACEHOLDER')"
      :max-length="1024"
      show-character-count
      auto-height
      resize
    />

    <Input
      v-if="bodyVariableCount"
      v-model="form.bodyExample"
      :label="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.BODY_EXAMPLE.LABEL')"
      :message="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.EXAMPLE_HELP')"
    />

    <Input
      v-model="form.footerText"
      :label="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.FOOTER.LABEL')"
      :placeholder="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.FOOTER.PLACEHOLDER')"
    />

    <div class="flex flex-col gap-3">
      <div class="flex justify-between items-center">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.BUTTONS.LABEL') }}
        </span>
        <NextButton
          variant="faded"
          color="slate"
          size="sm"
          icon="i-lucide-plus"
          :label="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.BUTTONS.ADD')"
          @click="addButton"
        />
      </div>
      <div
        v-for="(button, index) in form.buttons"
        :key="index"
        class="grid gap-3 items-end sm:grid-cols-[10rem_1fr_1fr_auto]"
      >
        <Select v-model="button.type" :options="buttonTypeOptions" />
        <Input
          v-model="button.text"
          :placeholder="
            $t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.BUTTONS.TEXT_PLACEHOLDER')
          "
        />
        <Input
          v-if="button.type === 'URL'"
          v-model="button.url"
          :placeholder="
            $t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.BUTTONS.URL_PLACEHOLDER')
          "
        />
        <Input
          v-else-if="button.type === 'PHONE_NUMBER'"
          v-model="button.phone_number"
          :placeholder="
            $t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.BUTTONS.PHONE_PLACEHOLDER')
          "
        />
        <span v-else />
        <NextButton
          variant="ghost"
          color="ruby"
          size="sm"
          icon="i-lucide-trash"
          @click="removeButton(index)"
        />
      </div>
    </div>

    <div class="flex flex-col gap-2">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.PREVIEW') }}
      </span>
      <MessageTemplatePreview
        :header="previewHeader"
        :body="previewBody"
        :footer="previewFooter"
        :buttons="form.buttons"
      />
    </div>

    <span v-if="errorMessage" class="text-sm text-n-ruby-9">
      {{ errorMessage }}
    </span>

    <div class="flex gap-2 justify-end">
      <NextButton
        variant="faded"
        color="slate"
        :label="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.CANCEL')"
        @click="emit('cancel')"
      />
      <NextButton
        :label="$t('INBOX_MGMT.MESSAGE_TEMPLATES.FORM.SUBMIT')"
        :is-loading="isSubmitting"
        @click="handleSubmit"
      />
    </div>
  </div>
</template>
