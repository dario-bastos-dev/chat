<script setup>
import { computed, ref, watch } from 'vue';
import {
  COMPONENT_TYPES,
  findComponentByType,
} from 'dashboard/helper/templateHelper';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';

// A message carried by an approved template: its body and its button labels belong to the template,
// so they are read from it instead of being typed here.
const props = defineProps({
  modelValue: { type: Object, default: null },
  inbox: { type: Object, required: true },
});

// One event carrying everything the parent has to store. Two separate updates in the same tick would
// both be built from the same stale props and the second would drop what the first had written.
const emit = defineEmits(['select']);

const parserRef = ref(null);

const approvedTemplates = computed(() =>
  (props.inbox.message_templates || []).filter(
    template => (template.status || '').toLowerCase() === 'approved'
  )
);

const templateOptions = computed(() =>
  approvedTemplates.value.map(template => ({
    id: `${template.name}:${template.language}`,
    name: `${template.name} (${template.language})`,
  }))
);

const selectedTemplate = computed(() =>
  approvedTemplates.value.find(
    template =>
      template.name === props.modelValue?.name &&
      template.language === props.modelValue?.language
  )
);

// SingleSelect treats a missing selection as null, never undefined.
const selectedOption = computed(
  () =>
    templateOptions.value.find(
      option =>
        option.id === `${props.modelValue?.name}:${props.modelValue?.language}`
    ) || null
);

const quickReplies = template =>
  (findComponentByType(template, COMPONENT_TYPES.BUTTONS)?.buttons || [])
    .filter(button => (button.type || '').toUpperCase() === 'QUICK_REPLY')
    .map(button => button.text);

const onTemplateChange = option => {
  const template = approvedTemplates.value.find(
    candidate =>
      `${candidate.name}:${candidate.language}` === (option?.id ?? option)
  );
  if (!template) {
    emit('select', { template: null });
    return;
  }

  emit('select', {
    template: {
      name: template.name,
      namespace: template.namespace,
      category: template.category || 'UTILITY',
      language: template.language,
      processed_params: {},
    },
    message: findComponentByType(template, COMPONENT_TYPES.BODY)?.text || '',
    buttonTitles: quickReplies(template),
  });
};

// The parser owns the variable inputs, so its state is mirrored back on every keystroke.
watch(
  () => parserRef.value?.processedParams,
  processedParams => {
    if (!props.modelValue?.name) return;

    emit('select', {
      template: { ...props.modelValue, processed_params: processedParams || {} },
    });
  },
  { deep: true }
);
</script>

<template>
  <div class="flex flex-col gap-3">
    <p v-if="!templateOptions.length" class="text-sm text-n-slate-11">
      {{ $t('INBOX_MGMT.CSAT.FLOW.TEMPLATE.EMPTY') }}
    </p>
    <SingleSelect
      v-else
      :model-value="selectedOption"
      :options="templateOptions"
      :placeholder="$t('INBOX_MGMT.CSAT.FLOW.TEMPLATE.PLACEHOLDER')"
      @update:model-value="onTemplateChange"
    />
    <WhatsAppTemplateParser
      v-if="selectedTemplate"
      ref="parserRef"
      :key="`${selectedTemplate.name}:${selectedTemplate.language}`"
      :template="selectedTemplate"
      :initial-params="modelValue?.processed_params || {}"
    />
  </div>
</template>
