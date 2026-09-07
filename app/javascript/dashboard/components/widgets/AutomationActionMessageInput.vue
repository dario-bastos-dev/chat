<script setup>
import { computed, ref, watch } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import {
  BUTTON_LABEL_MAX,
  getSendMessageButtonError,
} from 'dashboard/helper/validations';

// `action_params` holds a plain string for a free text message and an object
// for a template, so rules saved before templates were supported keep loading
// as text without any migration. A text message with interactive buttons is
// stored as `{ content, title, buttons: [{ title, url? }] }` in the same slot.
const modelValue = defineModel({ type: [String, Object], default: '' });

defineProps({
  dropdownMaxHeight: {
    type: String,
    default: 'max-h-80',
  },
});

const MAX_BUTTONS = 3;

const inboxes = useMapGetter('inboxes/getInboxes');

const isObject = value => !!value && typeof value === 'object';

const isTemplate = computed(
  () => isObject(modelValue.value) && 'template_params' in modelValue.value
);

const mode = ref(isTemplate.value ? 'template' : 'text');

// Text-mode state lives in local refs and is mirrored back into `modelValue` by
// the watcher below, so the free-text editor and the button rows stay decoupled.
const text = ref(
  isObject(modelValue.value)
    ? modelValue.value.content || ''
    : modelValue.value || ''
);

// Header above the interactive message. Optional everywhere except WhatsApp Lite, which rejects a
// button send without it; the template carries a standing note to that effect.
const header = ref(isObject(modelValue.value) ? modelValue.value.title || '' : '');

let buttonSeq = 0;
const nextButton = (title = '', url = '') => {
  buttonSeq += 1;
  return { id: buttonSeq, title, url };
};

const buttons = ref(
  isObject(modelValue.value) && Array.isArray(modelValue.value.buttons)
    ? modelValue.value.buttons.map(button =>
        nextButton(button.title || '', button.url || '')
      )
    : []
);

const addButton = () => {
  if (buttons.value.length >= MAX_BUTTONS) return;
  buttons.value.push(nextButton());
};

const removeButton = index => {
  buttons.value.splice(index, 1);
};

// One item per row: a filled `url` makes it a link button, otherwise a quick reply. Blank-label
// rows are kept so validation flags them instead of silently dropping the row; the backend
// filters them out.
const serializeButtons = () =>
  buttons.value.map(button => {
    const item = { title: button.title.trim() };
    const url = button.url.trim();
    if (url) item.url = url;
    return item;
  });

const syncTextMode = () => {
  if (mode.value !== 'text') return;

  const serialized = serializeButtons();
  modelValue.value = serialized.length
    ? { content: text.value, title: header.value.trim(), buttons: serialized }
    : text.value;
};

watch([text, header, buttons], syncTextMode, { deep: true });

// Runs the same check as the save-time validation (helper/validations.js) on the serialized
// shape, then maps the returned code to its inline message. The header is optional here; the
// template shows a standing note that WhatsApp Lite still needs it.
const buttonIssueKey = computed(() => {
  const code = getSendMessageButtonError({
    content: text.value,
    buttons: serializeButtons(),
  });
  return code ? `AUTOMATION.ACTION.BUTTONS.ERRORS.${code}` : null;
});

const templateInboxId = ref(null);
const parserRef = ref(null);

const whatsappInboxes = computed(() =>
  inboxes.value.filter(
    inbox =>
      inbox.channel_type === 'Channel::Whatsapp' &&
      (inbox.message_templates || []).length
  )
);

const inboxOptions = computed(() =>
  whatsappInboxes.value.map(inbox => ({ id: inbox.id, name: inbox.name }))
);

const inboxTemplates = computed(() => {
  const inbox = whatsappInboxes.value.find(i => i.id === templateInboxId.value);
  return inbox ? inbox.message_templates || [] : [];
});

const templateOptions = computed(() =>
  inboxTemplates.value.map(template => ({
    id: `${template.name}:${template.language}`,
    name: `${template.name} (${template.language})`,
  }))
);

const templateParams = computed(() =>
  isTemplate.value ? modelValue.value.template_params || {} : {}
);

const selectedTemplate = computed(() =>
  inboxTemplates.value.find(
    template =>
      template.name === templateParams.value.name &&
      template.language === templateParams.value.language
  )
);

const selectedInboxOption = computed(() =>
  inboxOptions.value.find(option => option.id === templateInboxId.value)
);

const selectedTemplateOption = computed(() => {
  const { name, language } = templateParams.value;
  if (!name) return null;
  return templateOptions.value.find(
    option => option.id === `${name}:${language}`
  );
});

// A rule is authored against one inbox but matches every conversation, so only
// the template name and language are stored. On reopening, the inbox is
// resolved back from whichever one still has it.
const resolveInboxFromTemplate = () => {
  if (!isTemplate.value || templateInboxId.value) return;
  const { name } = templateParams.value;
  if (!name) return;

  const inbox = whatsappInboxes.value.find(candidate =>
    (candidate.message_templates || []).some(template => template.name === name)
  );
  if (inbox) templateInboxId.value = inbox.id;
};

watch(whatsappInboxes, resolveInboxFromTemplate, { immediate: true });

const onModeChange = value => {
  mode.value = value;
  if (value === 'template') {
    modelValue.value = { template_params: {} };
    return;
  }
  text.value = '';
  header.value = '';
  buttons.value = [];
  modelValue.value = '';
};

const onInboxChange = option => {
  templateInboxId.value = option?.id ?? option ?? null;
  modelValue.value = { template_params: {} };
};

const onTemplateChange = option => {
  const template = inboxTemplates.value.find(
    candidate =>
      `${candidate.name}:${candidate.language}` === (option?.id ?? option)
  );
  if (!template) {
    modelValue.value = { template_params: {} };
    return;
  }

  modelValue.value = {
    content: '',
    template_params: {
      name: template.name,
      namespace: template.namespace,
      category: template.category || 'UTILITY',
      language: template.language || 'en',
      processed_params: {},
    },
  };
};

// The parser owns the variable inputs, so its state is mirrored into the action
// on every keystroke. Reading it only on submit would need the ref plumbed up
// through the whole rule form.
watch(
  () => [parserRef.value?.processedParams, parserRef.value?.renderedTemplate],
  ([processedParams, renderedTemplate]) => {
    if (!isTemplate.value || !templateParams.value.name) return;

    modelValue.value = {
      content: renderedTemplate || modelValue.value.content || '',
      template_params: {
        ...templateParams.value,
        processed_params: processedParams || {},
      },
    };
  },
  { deep: true }
);
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex gap-2">
      <button
        v-for="option in ['text', 'template']"
        :key="option"
        type="button"
        class="px-3 py-1 text-sm rounded-lg outline outline-1 -outline-offset-1"
        :class="
          mode === option
            ? 'bg-n-alpha-2 text-n-slate-12 outline-n-brand'
            : 'text-n-slate-11 outline-n-weak dark:outline-n-strong'
        "
        @click="onModeChange(option)"
      >
        {{ $t(`AUTOMATION.ACTION.MESSAGE_MODE.${option.toUpperCase()}`) }}
      </button>
    </div>

    <template v-if="mode === 'text'">
      <WootMessageEditor
        v-model="text"
        rows="4"
        enable-variables
        :placeholder="$t('AUTOMATION.ACTION.TEAM_MESSAGE_INPUT_PLACEHOLDER')"
        class="[&_.ProseMirror-menubar]:hidden px-3 py-1 bg-n-alpha-1 rounded-lg outline outline-1 outline-n-weak dark:outline-n-strong"
      />

      <div class="flex flex-col gap-2">
        <div class="flex items-center justify-between">
          <label class="text-sm font-medium text-n-slate-12 !mb-0">
            {{ $t('AUTOMATION.ACTION.BUTTONS.LABEL') }}
          </label>
          <NextButton
            v-if="buttons.length < MAX_BUTTONS"
            icon="i-lucide-plus"
            blue
            faded
            xs
            :label="$t('AUTOMATION.ACTION.BUTTONS.ADD')"
            @click="addButton"
          />
        </div>

        <p v-if="!buttons.length" class="text-sm text-n-slate-11">
          {{ $t('AUTOMATION.ACTION.BUTTONS.HINT') }}
        </p>

        <NextInput
          v-if="buttons.length"
          v-model="header"
          type="text"
          size="sm"
          :maxlength="60"
          :placeholder="$t('AUTOMATION.ACTION.BUTTONS.HEADER_PLACEHOLDER')"
        />

        <p v-if="buttons.length" class="text-sm text-n-slate-11">
          {{ $t('AUTOMATION.ACTION.BUTTONS.HEADER_HINT') }}
        </p>

        <div
          v-for="(button, index) in buttons"
          :key="button.id"
          class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak"
        >
          <div class="flex items-center gap-2">
            <NextInput
              v-model="button.title"
              type="text"
              size="sm"
              class="flex-1"
              :maxlength="BUTTON_LABEL_MAX"
              :placeholder="$t('AUTOMATION.ACTION.BUTTONS.TITLE_PLACEHOLDER')"
            />
            <NextButton
              sm
              solid
              slate
              icon="i-lucide-trash"
              @click="removeButton(index)"
            />
          </div>
          <NextInput
            v-model="button.url"
            type="url"
            size="sm"
            :placeholder="$t('AUTOMATION.ACTION.BUTTONS.URL_PLACEHOLDER')"
          />
        </div>

        <p v-if="buttonIssueKey" class="text-sm text-n-ruby-11">
          {{ $t(buttonIssueKey) }}
        </p>
      </div>
    </template>

    <template v-else>
      <p v-if="!inboxOptions.length" class="text-sm text-n-slate-11">
        {{ $t('AUTOMATION.ACTION.NO_TEMPLATE_INBOX') }}
      </p>
      <template v-else>
        <SingleSelect
          :model-value="selectedInboxOption"
          :options="inboxOptions"
          :placeholder="$t('AUTOMATION.ACTION.TEMPLATE_INBOX_PLACEHOLDER')"
          :dropdown-max-height="dropdownMaxHeight"
          @update:model-value="onInboxChange"
        />
        <SingleSelect
          v-if="templateInboxId"
          :model-value="selectedTemplateOption"
          :options="templateOptions"
          :placeholder="$t('AUTOMATION.ACTION.TEMPLATE_PLACEHOLDER')"
          :dropdown-max-height="dropdownMaxHeight"
          @update:model-value="onTemplateChange"
        />
        <WhatsAppTemplateParser
          v-if="selectedTemplate"
          ref="parserRef"
          :key="`${selectedTemplate.name}:${selectedTemplate.language}`"
          :template="selectedTemplate"
          :initial-params="templateParams.processed_params || {}"
        />
      </template>
    </template>
  </div>
</template>
