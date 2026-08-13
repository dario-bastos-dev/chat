<script setup>
import { computed, ref, watch } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';

// `action_params` holds a plain string for a free text message and an object
// for a template, so rules saved before templates were supported keep loading
// as text without any migration.
const modelValue = defineModel({ type: [String, Object], default: '' });

defineProps({
  dropdownMaxHeight: {
    type: String,
    default: 'max-h-80',
  },
});

const inboxes = useMapGetter('inboxes/getInboxes');

const isTemplate = computed(
  () => !!modelValue.value && typeof modelValue.value === 'object'
);

const mode = ref(isTemplate.value ? 'template' : 'text');

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
  modelValue.value = value === 'template' ? { template_params: {} } : '';
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

    <WootMessageEditor
      v-if="mode === 'text'"
      v-model="modelValue"
      rows="4"
      enable-variables
      :placeholder="$t('AUTOMATION.ACTION.TEAM_MESSAGE_INPUT_PLACEHOLDER')"
      class="[&_.ProseMirror-menubar]:hidden px-3 py-1 bg-n-alpha-1 rounded-lg outline outline-1 outline-n-weak dark:outline-n-strong"
    />

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
