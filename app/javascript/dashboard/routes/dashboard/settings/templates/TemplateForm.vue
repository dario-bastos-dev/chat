<script setup>
import { computed, onBeforeUnmount, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';
import TemplateFormPreview from './TemplateFormPreview.vue';
import { templateToForm } from './templateFormMapper';

const props = defineProps({
  inboxId: { type: [Number, String], required: true },
  isSubmitting: { type: Boolean, default: false },
  // Present when editing: name and language are immutable on Meta's side.
  template: { type: Object, default: null },
});

const isEditing = computed(() => Boolean(props.template));

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

// AUTHENTICATION is intentionally absent: Meta only accepts it with an OTP
// button, which is not supported here yet.
const CATEGORIES = ['UTILITY', 'MARKETING'];
const BUTTON_TEXT_MAX_LENGTH = 25;
const TEMPLATE_NAME_MAX_LENGTH = 512;
const LANGUAGES = ['pt_BR', 'en', 'en_US', 'es', 'es_ES'];
const BUTTON_TYPES = [
  'QUICK_REPLY',
  'URL',
  'PHONE_NUMBER',
  'COPY_CODE',
  'ORDER_DETAILS',
];
// Meta renders its own label on these, so the text field is hidden for them.
const LABELLESS_BUTTON_TYPES = ['COPY_CODE'];
const COPY_CODE_MAX_LENGTH = 15;
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
  headerExamples: [],
  mediaHandle: '',
  mediaBlobId: '',
  mediaFileName: '',
  bodyText: '',
  bodyExamples: [],
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
    label: t(`WHATSAPP_TEMPLATE_MGMT.CATEGORIES.${value}`),
  }))
);
const languageOptions = computed(() =>
  LANGUAGES.map(value => ({ value, label: value }))
);
const headerFormatOptions = computed(() =>
  HEADER_FORMATS.map(value => ({
    value,
    label: t(`WHATSAPP_TEMPLATE_MGMT.HEADER_FORMATS.${value}`),
  }))
);
const buttonTypeOptions = computed(() =>
  BUTTON_TYPES.map(value => ({
    value,
    label: t(`WHATSAPP_TEMPLATE_MGMT.BUTTON_TYPES.${value}`),
  }))
);

// Placeholders can be numbered ({{1}}) or named ({{order_id}}); returns the
// distinct names in the order they first appear.
const VARIABLE_PATTERN = /\{\{\s*([A-Za-z0-9_]+)\s*\}\}/g;
const NAMED_VARIABLE_FORMAT = /^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/;

const extractVariables = text => [
  ...new Set([...(text || '').matchAll(VARIABLE_PATTERN)].map(match => match[1])),
];

const isNamedVariable = variable => !/^\d+$/.test(variable);
const hasNamedVariables = variables => variables.some(isNamedVariable);

// Meta only accepts [a-z0-9_] in template names, so the field is normalised as
// the user types: accents are stripped and every other run of characters
// collapses into a single underscore. A trailing underscore is kept while
// typing (so "order_" can still become "order_confirmed") and trimmed on blur.
const sanitizeName = value =>
  value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, '_')
    .replace(/_{2,}/g, '_')
    .replace(/^_+/, '')
    .slice(0, TEMPLATE_NAME_MAX_LENGTH);

const templateName = computed({
  get: () => form.name,
  set: value => {
    form.name = sanitizeName(value);
  },
});

const handleNameBlur = () => {
  form.name = form.name.replace(/_+$/, '');
};

// One input per placeholder, resized as the text changes, so the fields never
// depend on a delimiter the user has to type.
const syncExamples = (list, count) => {
  while (list.length < count) list.push('');
  if (list.length > count) list.splice(count);
};

const bodyVariables = computed(() => extractVariables(form.bodyText));
const headerVariables = computed(() => extractVariables(form.headerText));

// Watch the count, not the array: the computed returns a fresh array on every
// keystroke and would otherwise re-run the sync needlessly.
watch(
  () => bodyVariables.value.length,
  count => syncExamples(form.bodyExamples, count),
  { immediate: true }
);
watch(
  () => headerVariables.value.length,
  count => syncExamples(form.headerExamples, count),
  { immediate: true }
);

// Object URL for the file just picked, so the preview shows the real media
// instead of a placeholder. Kept out of `form` because `load` replaces that
// wholesale and the URL has to be revoked, not copied.
const mediaPreviewUrl = ref('');

const setMediaPreview = file => {
  if (mediaPreviewUrl.value.startsWith('blob:')) {
    URL.revokeObjectURL(mediaPreviewUrl.value);
  }
  mediaPreviewUrl.value = file ? URL.createObjectURL(file) : '';
};

const previewHeader = computed(() => ({
  format: form.headerFormat,
  text: form.headerText,
  example: form.headerExamples,
  fileName: form.mediaFileName,
  mediaUrl: mediaPreviewUrl.value,
}));
const previewBody = computed(() => ({
  text: form.bodyText,
  example: form.bodyExamples,
}));
const previewFooter = computed(() => ({ text: form.footerText }));

const addButton = () => {
  form.buttons.push({
    type: 'QUICK_REPLY',
    text: '',
    code: '',
    url: '',
    phone_number: '',
  });
};

const removeButton = index => {
  form.buttons.splice(index, 1);
};

const handleHeaderFormatChange = () => {
  form.mediaHandle = '';
  form.mediaBlobId = '';
  form.mediaFileName = '';
  setMediaPreview(null);
  if (isMediaHeader.value) {
    form.headerText = '';
    form.headerExamples = [];
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
    // Kept alongside the Meta handle so the send can point at our own copy
    // instead of the approval sample, whose signed URL expires.
    form.mediaBlobId = data.blob_id || '';
    form.mediaFileName = file.name;
    setMediaPreview(file);
  } catch (error) {
    form.mediaHandle = '';
    form.mediaBlobId = '';
    form.mediaFileName = '';
    setMediaPreview(null);
    useAlert(
      error?.response?.data?.error ||
        t('WHATSAPP_TEMPLATE_MGMT.ERRORS.UPLOAD_FAILED')
    );
  } finally {
    isUploading.value = false;
    if (fileInputRef.value) fileInputRef.value.value = '';
  }
};

// Meta accepts at most one variable per URL button, and only at the very end.
const isValidButtonUrl = url => {
  if (!url?.trim()) return false;
  const variables = url.match(VARIABLE_PATTERN) || [];
  if (!variables.length) return true;
  return variables.length === 1 && url.endsWith(variables[0]);
};

const validate = () => {
  if (!/^[a-z0-9_]{1,512}$/.test(form.name)) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.INVALID_NAME');
  }
  if (!form.bodyText.trim()) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.BODY_REQUIRED');
  }
  if (form.bodyExamples.some(sample => !sample.trim())) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.BODY_EXAMPLE_MISMATCH');
  }
  if (isMediaHeader.value && !form.mediaHandle) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.MEDIA_REQUIRED');
  }
  if (
    !isMediaHeader.value &&
    form.headerExamples.some(sample => !sample.trim())
  ) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.HEADER_EXAMPLE_MISMATCH');
  }
  const invalidVariable = [...bodyVariables.value, ...headerVariables.value].find(
    variable => isNamedVariable(variable) && !NAMED_VARIABLE_FORMAT.test(variable)
  );
  if (invalidVariable) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.INVALID_VARIABLE_NAME', {
      name: invalidVariable,
    });
  }
  if (
    bodyVariables.value.length &&
    headerVariables.value.length &&
    hasNamedVariables(bodyVariables.value) !==
      hasNamedVariables(headerVariables.value)
  ) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.MIXED_VARIABLES');
  }
  const labelled = form.buttons.filter(
    button => !LABELLESS_BUTTON_TYPES.includes(button.type)
  );
  if (labelled.some(button => !button.text.trim())) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.BUTTON_LABEL_REQUIRED');
  }
  if (labelled.some(button => button.text.length > BUTTON_TEXT_MAX_LENGTH)) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.BUTTON_LABEL_TOO_LONG');
  }
  const copyCodeButtons = form.buttons.filter(
    button => button.type === 'COPY_CODE'
  );
  if (copyCodeButtons.some(button => !button.code?.trim())) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.COPY_CODE_REQUIRED');
  }
  if (
    copyCodeButtons.some(button => button.code.length > COPY_CODE_MAX_LENGTH)
  ) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.COPY_CODE_TOO_LONG');
  }
  if (copyCodeButtons.length > 1) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.COPY_CODE_LIMIT');
  }
  // A payment button replaces the whole call to action area, so Meta rejects
  // it next to any other button.
  const paymentButtons = form.buttons.filter(
    button => button.type === 'ORDER_DETAILS'
  );
  if (paymentButtons.length && form.buttons.length > 1) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.PAYMENT_BUTTON_ALONE');
  }
  const invalidUrlButton = form.buttons.find(
    button => button.type === 'URL' && !isValidButtonUrl(button.url)
  );
  if (invalidUrlButton) {
    return t('WHATSAPP_TEMPLATE_MGMT.ERRORS.INVALID_BUTTON_URL');
  }
  return '';
};

const buildPayload = () => {
  const payload = {
    // Trailing underscores are only trimmed on blur, which a submit via Enter skips.
    name: form.name.replace(/_+$/, ''),
    category: form.category,
    language: form.language,
    body: {
      text: form.bodyText,
      example: form.bodyExamples.map(sample => sample.trim()),
    },
  };

  if (isMediaHeader.value) {
    payload.header = {
      format: form.headerFormat,
      media_handle: form.mediaHandle,
      media_blob_id: form.mediaBlobId,
    };
  } else if (form.headerText.trim()) {
    payload.header = {
      format: 'TEXT',
      text: form.headerText,
      example: form.headerExamples.map(sample => sample.trim()),
    };
  }
  if (form.footerText.trim()) {
    payload.footer = { text: form.footerText };
  }
  if (form.buttons.length) {
    payload.buttons = form.buttons.map(button => {
      if (button.type === 'URL') {
        // Meta expects the sample as the full URL with the variable filled in.
        const example = extractVariables(button.url).length
          ? [button.url.replace(VARIABLE_PATTERN, '123')]
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
      // `code` and not `example`: the latter is reserved for the URL
      // button's array of samples.
      if (button.type === 'COPY_CODE') {
        return { type: 'COPY_CODE', code: button.code };
      }
      if (button.type === 'ORDER_DETAILS') {
        return { type: 'ORDER_DETAILS', text: button.text };
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

// Same sources the template parser uses: our stored copy first, then Meta's
// approval sample when it came back as a URL rather than a raw upload handle.
const existingMediaUrl = template => {
  if (template.chatwoot_media_url) return template.chatwoot_media_url;

  const header = (template.components || []).find(
    component => component.type?.toUpperCase() === 'HEADER'
  );
  const handle = header?.example?.header_handle?.[0] || '';
  return /^https?:\/\//.test(handle) ? handle : '';
};

const load = template => {
  Object.assign(form, template ? templateToForm(template) : buildInitialState());
  setMediaPreview(null);
  // On edit the media already lives at Meta or in our storage; start from it.
  mediaPreviewUrl.value = template ? existingMediaUrl(template) : '';
  errorMessage.value = '';
};

const reset = () => load(null);

onBeforeUnmount(() => setMediaPreview(null));

// The form fills itself from the prop instead of relying on the parent calling
// `load` at the right moment: the panel sets the template and mounts this
// component in the same tick, so its ref is still null when the parent tries,
// and the fields would stay empty on the first edit.
watch(() => props.template, load, { immediate: true });

defineExpose({ reset, load });
</script>

<template>
  <div class="flex flex-col gap-5">
    <div class="grid gap-4 sm:grid-cols-3">
      <Input
        v-model="templateName"
        :label="$t('WHATSAPP_TEMPLATE_MGMT.FORM.NAME.LABEL')"
        :placeholder="$t('WHATSAPP_TEMPLATE_MGMT.FORM.NAME.PLACEHOLDER')"
        :message="
          isEditing
            ? $t('WHATSAPP_TEMPLATE_MGMT.FORM.NAME.LOCKED')
            : $t('WHATSAPP_TEMPLATE_MGMT.FORM.NAME.HELP')
        "
        :disabled="isEditing"
        @blur="handleNameBlur"
      />
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('WHATSAPP_TEMPLATE_MGMT.FORM.CATEGORY.LABEL') }}
        </label>
        <Select
          v-model="form.category"
          :options="categoryOptions"
          :disabled="isEditing"
        />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('WHATSAPP_TEMPLATE_MGMT.FORM.LANGUAGE.LABEL') }}
        </label>
        <Select
          v-model="form.language"
          :options="languageOptions"
          :disabled="isEditing"
        />
      </div>
    </div>

    <div class="flex flex-col gap-3">
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('WHATSAPP_TEMPLATE_MGMT.FORM.HEADER_FORMAT.LABEL') }}
        </label>
        <Select
          v-model="form.headerFormat"
          :options="headerFormatOptions"
          :disabled="isEditing"
          @update:model-value="handleHeaderFormatChange"
        />
        <span v-if="isEditing" class="text-sm text-n-slate-11">
          {{ $t('WHATSAPP_TEMPLATE_MGMT.FORM.HEADER_FORMAT.LOCKED') }}
        </span>
      </div>

      <div v-if="isMediaHeader" class="flex flex-col gap-2 items-start">
        <input
          ref="fileInputRef"
          type="file"
          class="text-sm text-n-slate-11 file:mr-3 file:px-3 file:py-1.5 file:rounded-lg file:border-0 file:bg-n-slate-3 file:text-n-slate-12"
          :accept="mediaAccept"
          :disabled="isUploading"
          @change="handleFileSelect"
        />
        <span
          v-if="isUploading"
          class="px-3 py-1.5 max-w-full text-sm rounded-lg border border-n-weak bg-n-alpha-2 text-n-slate-11"
        >
          {{ $t('WHATSAPP_TEMPLATE_MGMT.FORM.UPLOADING') }}
        </span>
        <span
          v-else-if="form.mediaFileName"
          class="px-3 py-1.5 max-w-full text-sm truncate rounded-lg border border-n-weak bg-n-alpha-2 text-n-slate-12"
        >
          {{ form.mediaFileName }}
        </span>
      </div>

      <div v-else class="grid gap-4 sm:grid-cols-2">
        <Input
          v-model="form.headerText"
          :label="$t('WHATSAPP_TEMPLATE_MGMT.FORM.HEADER.LABEL')"
          :placeholder="
            $t('WHATSAPP_TEMPLATE_MGMT.FORM.HEADER.PLACEHOLDER')
          "
        />
        <div v-show="headerVariables.length" class="flex flex-col gap-2">
          <label class="text-sm font-medium text-n-slate-12">
            {{ $t('WHATSAPP_TEMPLATE_MGMT.FORM.HEADER_EXAMPLE.LABEL') }}
          </label>
          <Input
            v-for="(variable, index) in headerVariables"
            :key="`header-sample-${variable}`"
            v-model="form.headerExamples[index]"
            :placeholder="
              $t('WHATSAPP_TEMPLATE_MGMT.FORM.VARIABLE_PLACEHOLDER', {
                name: variable,
              })
            "
          />
        </div>
      </div>
    </div>

    <TextArea
      v-model="form.bodyText"
      :label="$t('WHATSAPP_TEMPLATE_MGMT.FORM.BODY.LABEL')"
      :placeholder="$t('WHATSAPP_TEMPLATE_MGMT.FORM.BODY.PLACEHOLDER')"
      :message="$t('WHATSAPP_TEMPLATE_MGMT.FORM.BODY.HELP')"
      :max-length="1024"
      show-character-count
      auto-height
      resize
    />

    <div v-show="bodyVariables.length" class="flex flex-col gap-2">
      <label class="text-sm font-medium text-n-slate-12">
        {{ $t('WHATSAPP_TEMPLATE_MGMT.FORM.BODY_EXAMPLE.LABEL') }}
      </label>
      <Input
        v-for="(variable, index) in bodyVariables"
        :key="`body-sample-${variable}`"
        v-model="form.bodyExamples[index]"
        :placeholder="
          $t('WHATSAPP_TEMPLATE_MGMT.FORM.VARIABLE_PLACEHOLDER', {
            name: variable,
          })
        "
      />
    </div>

    <Input
      v-model="form.footerText"
      :label="$t('WHATSAPP_TEMPLATE_MGMT.FORM.FOOTER.LABEL')"
      :placeholder="$t('WHATSAPP_TEMPLATE_MGMT.FORM.FOOTER.PLACEHOLDER')"
    />

    <div class="flex flex-col gap-3">
      <div class="flex justify-between items-center">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('WHATSAPP_TEMPLATE_MGMT.FORM.BUTTONS.LABEL') }}
        </span>
        <NextButton
          variant="faded"
          color="slate"
          size="sm"
          icon="i-lucide-plus"
          :label="$t('WHATSAPP_TEMPLATE_MGMT.FORM.BUTTONS.ADD')"
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
          v-if="!LABELLESS_BUTTON_TYPES.includes(button.type)"
          v-model="button.text"
          :placeholder="
            $t('WHATSAPP_TEMPLATE_MGMT.FORM.BUTTONS.TEXT_PLACEHOLDER')
          "
        />
        <Input
          v-if="button.type === 'COPY_CODE'"
          v-model="button.code"
          :maxlength="COPY_CODE_MAX_LENGTH"
          :placeholder="
            $t('WHATSAPP_TEMPLATE_MGMT.FORM.BUTTONS.CODE_PLACEHOLDER')
          "
        />
        <Input
          v-else-if="button.type === 'URL'"
          v-model="button.url"
          :placeholder="
            $t('WHATSAPP_TEMPLATE_MGMT.FORM.BUTTONS.URL_PLACEHOLDER')
          "
        />
        <Input
          v-else-if="button.type === 'PHONE_NUMBER'"
          v-model="button.phone_number"
          :placeholder="
            $t('WHATSAPP_TEMPLATE_MGMT.FORM.BUTTONS.PHONE_PLACEHOLDER')
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
        {{ $t('WHATSAPP_TEMPLATE_MGMT.FORM.PREVIEW') }}
      </span>
      <TemplateFormPreview
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
        :label="$t('WHATSAPP_TEMPLATE_MGMT.FORM.CANCEL')"
        @click="emit('cancel')"
      />
      <NextButton
        :label="
          isEditing
            ? $t('WHATSAPP_TEMPLATE_MGMT.FORM.SAVE')
            : $t('WHATSAPP_TEMPLATE_MGMT.FORM.SUBMIT')
        "
        :is-loading="isSubmitting"
        @click="handleSubmit"
      />
    </div>
  </div>
</template>
