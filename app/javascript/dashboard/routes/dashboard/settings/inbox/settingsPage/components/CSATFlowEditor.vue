<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import FilterSelect from 'dashboard/components-next/filter/inputs/FilterSelect.vue';
import CSATFlowButton from './CSATFlowButton.vue';
import CSATFlowTemplateSelect from './CSATFlowTemplateSelect.vue';

// Mirrors CsatFlowValidator
const MAX_BUTTONS = 3;
const SENTIMENTS = ['positive', 'negative', 'neutral'];

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  inbox: { type: Object, required: true },
  // Mirrors CsatFlowService.templates_available? and .header_required?
  templatesAvailable: { type: Boolean, default: false },
  headerRequired: { type: Boolean, default: false },
  actionButtonsAvailable: { type: Boolean, default: false },
  labels: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const key = (suffix, args) => t(`INBOX_MGMT.CSAT.FLOW.${suffix}`, args);

const buttons = computed(() => props.modelValue.buttons || []);

// Flows saved before the mode was explicit are recognised by the template they carry.
const mode = computed(
  () => props.modelValue.mode || (props.modelValue.template ? 'template' : 'compose')
);

const isTemplateMode = computed(() => mode.value === 'template');

const modeOptions = computed(() =>
  ['compose', 'template'].map(value => ({
    value,
    label: key(`MODE.${value.toUpperCase()}`),
  }))
);

const labelOptions = computed(() => [
  { value: '', label: key('BUTTONS.NO_LABEL') },
  ...props.labels.map(label => ({ value: label.title, label: label.title })),
]);

const update = attributes =>
  emit('update:modelValue', { ...props.modelValue, ...attributes });

const updateButton = (index, button) =>
  update({ buttons: buttons.value.map((item, i) => (i === index ? button : item)) });

const addButton = () =>
  update({
    buttons: [
      ...buttons.value,
      {
        title: '',
        sentiment: SENTIMENTS.find(
          sentiment => !buttons.value.some(button => button.sentiment === sentiment)
        ),
        label: '',
        reopen: false,
        reply: null,
      },
    ],
  });

const removeButton = index =>
  update({ buttons: buttons.value.filter((_, i) => i !== index) });

// A node is sent as a template whenever it carries one, so switching back to composing here has to
// drop the templates as well - otherwise the approved copy would keep going out.
const withoutReplyTemplate = button =>
  button.reply?.template
    ? { ...button, reply: { ...button.reply, template: null } }
    : button;

const onModeChange = value =>
  update({
    mode: value,
    template: value === 'template' ? props.modelValue.template : null,
    buttons:
      value === 'template'
        ? buttons.value
        : buttons.value.map(withoutReplyTemplate),
  });

// One update per event: the template always, the body and the labels only when the event carries
// them. Picking a template rewrites the titles with the ones it declares and keeps the sentiment and
// the reply already configured for each position; a template with no quick reply leaves the buttons
// untouched, so they can still be written by hand.
const onTemplateSelect = ({ template, message, buttonTitles }) => {
  const attributes = { template };
  if (message !== undefined) attributes.message = message;
  if (buttonTitles?.length) {
    attributes.buttons = buttonTitles.map((title, index) => ({
      sentiment: SENTIMENTS[index],
      label: '',
      reopen: false,
      reply: null,
      ...(buttons.value[index] || {}),
      title,
    }));
  }

  update(attributes);
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <label class="flex gap-2 items-center text-sm font-medium text-n-slate-12">
      <input
        type="checkbox"
        :checked="modelValue.enabled || false"
        @change="update({ enabled: $event.target.checked })"
      />
      {{ key('TITLE') }}
    </label>
    <p class="text-sm text-n-slate-11">{{ key('DESCRIPTION') }}</p>

    <template v-if="modelValue.enabled">
      <div v-if="templatesAvailable" class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ key('MODE.LABEL') }}
        </span>
        <FilterSelect
          :model-value="mode"
          :options="modeOptions"
          class="self-start"
          @update:model-value="onModeChange"
        />
        <p class="text-sm text-n-slate-11">{{ key('MODE.HELP') }}</p>
      </div>

      <CSATFlowTemplateSelect
        v-if="isTemplateMode"
        :model-value="modelValue.template || null"
        :inbox="inbox"
        @select="onTemplateSelect"
      />
      <template v-else>
        <Input
          v-if="headerRequired"
          :model-value="modelValue.header || ''"
          :label="key('HEADER.LABEL')"
          :placeholder="key('HEADER.PLACEHOLDER')"
          :message="key('HEADER.HELP')"
          @update:model-value="update({ header: $event })"
        />
        <TextArea
          :model-value="modelValue.message || ''"
          :label="key('MESSAGE.LABEL')"
          :placeholder="key('MESSAGE.PLACEHOLDER')"
          :max-length="1024"
          @update:model-value="update({ message: $event })"
        />
        <Input
          :model-value="modelValue.footer || ''"
          :label="key('FOOTER.LABEL')"
          :placeholder="key('FOOTER.PLACEHOLDER')"
          @update:model-value="update({ footer: $event })"
        />
      </template>

      <CSATFlowButton
        v-for="(button, index) in buttons"
        :key="index"
        :model-value="button"
        :inbox="inbox"
        :template-mode="isTemplateMode"
        :header-required="headerRequired"
        :action-buttons-available="actionButtonsAvailable"
        :label-options="labelOptions"
        @update:model-value="updateButton(index, $event)"
        @remove="removeButton(index)"
      />

      <p v-if="!buttons.length" class="text-sm text-n-ruby-11">
        {{ key('BUTTONS.EMPTY') }}
      </p>

      <NextButton
        v-if="buttons.length < MAX_BUTTONS"
        sm
        faded
        slate
        icon="i-lucide-plus"
        :label="key('BUTTONS.ADD')"
        class="self-start"
        @click="addButton"
      />

      <p class="text-sm italic text-n-slate-11">{{ key('NOTE') }}</p>
    </template>
  </div>
</template>
