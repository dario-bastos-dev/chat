<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import FilterSelect from 'dashboard/components-next/filter/inputs/FilterSelect.vue';
import CSATFlowTemplateSelect from './CSATFlowTemplateSelect.vue';

// Mirrors CsatFlowValidator
const MAX_BUTTONS = 3;
const MAX_TITLE_LENGTH = 20;

const props = defineProps({
  modelValue: { type: Object, required: true },
  inbox: { type: Object, required: true },
  templateMode: { type: Boolean, default: false },
  headerRequired: { type: Boolean, default: false },
  actionButtonsAvailable: { type: Boolean, default: false },
  labelOptions: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue', 'remove']);

const { t } = useI18n();

const key = (suffix, args) => t(`INBOX_MGMT.CSAT.FLOW.${suffix}`, args);

const sentimentOptions = computed(() =>
  ['positive', 'negative', 'neutral'].map(value => ({
    value,
    label: key(`SENTIMENT.${value.toUpperCase()}`),
  }))
);

const replyTypeOptions = computed(() =>
  ['none', 'csat_survey', 'message'].map(value => ({
    value,
    label: key(`REPLY.TYPE.${value.toUpperCase()}`),
  }))
);

// Call-to-action buttons are only offered where the channel can actually deliver them.
const buttonTypeOptions = computed(() =>
  ['none', 'quick_reply', 'action']
    .filter(value => value !== 'action' || props.actionButtonsAvailable)
    .map(value => ({
      value,
      label: key(`REPLY.BUTTON_TYPE.${value.toUpperCase()}`),
    }))
);

const actionTypeOptions = computed(() =>
  ['url', 'call'].map(value => ({
    value,
    label: key(`REPLY.ACTION.${value.toUpperCase()}`),
  }))
);

const reply = computed(() => props.modelValue.reply || null);

const replyType = computed(() => reply.value?.type || 'none');

const replyButtonType = computed(() => reply.value?.button_type || 'none');

const replyButtons = computed(() => reply.value?.buttons || []);

const update = attributes =>
  emit('update:modelValue', { ...props.modelValue, ...attributes });

const updateReply = attributes =>
  update({ reply: { ...reply.value, ...attributes } });

const onReplyTypeChange = value => {
  if (value === 'none') return update({ reply: null });
  if (value === 'csat_survey') {
    // The survey is only sent on a resolved conversation, so this branch cannot reopen it.
    return update({ reopen: false, reply: { type: 'csat_survey' } });
  }

  return update({
    reply: { type: 'message', message: '', button_type: 'none', buttons: [] },
  });
};

const onReplyButtonTypeChange = value =>
  updateReply({ button_type: value, buttons: [] });

const updateReplyButton = (index, attributes) =>
  updateReply({
    buttons: replyButtons.value.map((button, i) =>
      i === index ? { ...button, ...attributes } : button
    ),
  });

const addReplyButton = () =>
  updateReply({
    buttons: [
      ...replyButtons.value,
      replyButtonType.value === 'action'
        ? { type: 'url', text: '', url: '', phone_number: '' }
        : { title: '', reopen: false },
    ],
  });

const removeReplyButton = index =>
  updateReply({
    buttons: replyButtons.value.filter((_, i) => i !== index),
  });

// The quick replies of the reply message are part of the approved template: only whether each of
// them reopens the conversation is configured here.
const onReplyTemplateSelect = ({ template, message, buttonTitles }) => {
  const attributes = { template };
  if (message !== undefined) attributes.message = message;
  // A reply button only carries whether it reopens the conversation, so the labels of the chosen
  // template replace them wholesale - including going back to no buttons when it declares none.
  if (buttonTitles !== undefined) {
    attributes.button_type = buttonTitles.length ? 'quick_reply' : 'none';
    attributes.buttons = buttonTitles.map((title, index) => ({
      reopen: false,
      ...(replyButtons.value[index] || {}),
      title,
    }));
  }

  updateReply(attributes);
};
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 rounded-xl outline outline-1 outline-n-weak bg-n-alpha-1"
  >
    <div class="flex flex-wrap gap-3 items-end">
      <Input
        :model-value="modelValue.title"
        :label="key('BUTTONS.TITLE_LABEL')"
        :placeholder="key('BUTTONS.TITLE_PLACEHOLDER')"
        :maxlength="MAX_TITLE_LENGTH"
        :message="templateMode ? key('BUTTONS.TITLE_FROM_TEMPLATE') : ''"
        class="flex-1 min-w-40"
        @update:model-value="update({ title: $event })"
      />
      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ key('BUTTONS.SENTIMENT_LABEL') }}
        </span>
        <FilterSelect
          :model-value="modelValue.sentiment"
          :options="sentimentOptions"
          @update:model-value="update({ sentiment: $event })"
        />
      </div>
      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ key('BUTTONS.LABEL_LABEL') }}
        </span>
        <FilterSelect
          :model-value="modelValue.label || ''"
          :options="labelOptions"
          @update:model-value="update({ label: $event })"
        />
      </div>
      <NextButton
        sm
        ghost
        ruby
        icon="i-lucide-trash-2"
        :aria-label="key('BUTTONS.REMOVE')"
        @click="emit('remove')"
      />
    </div>

    <label
      v-if="replyType !== 'csat_survey'"
      class="flex gap-2 items-center text-sm text-n-slate-11"
    >
      <input
        type="checkbox"
        :checked="modelValue.reopen || false"
        @change="update({ reopen: $event.target.checked })"
      />
      {{ key('BUTTONS.REOPEN') }}
    </label>

    <div class="flex flex-col gap-2">
      <span class="text-sm font-medium text-n-slate-12">
        {{ key('REPLY.LABEL') }}
      </span>
      <FilterSelect
        :model-value="replyType"
        :options="replyTypeOptions"
        class="self-start"
        @update:model-value="onReplyTypeChange"
      />
    </div>

    <template v-if="replyType === 'message'">
      <CSATFlowTemplateSelect
        v-if="templateMode"
        :model-value="reply.template || null"
        :inbox="inbox"
        @select="onReplyTemplateSelect"
      />
      <TextArea
        v-else
        :model-value="reply.message || ''"
        :label="key('REPLY.MESSAGE_LABEL')"
        :placeholder="key('REPLY.MESSAGE_PLACEHOLDER')"
        :max-length="1024"
        @update:model-value="updateReply({ message: $event })"
      />

      <div v-if="templateMode" class="flex flex-col gap-2">
        <label
          v-for="(button, index) in replyButtons"
          :key="index"
          class="flex gap-2 items-center text-sm text-n-slate-11"
        >
          <input
            type="checkbox"
            :checked="button.reopen || false"
            @change="
              updateReplyButton(index, { reopen: $event.target.checked })
            "
          />
          {{ key('BUTTONS.REOPEN_NAMED', { title: button.title }) }}
        </label>
      </div>

      <div v-else class="flex flex-col gap-3">
        <div class="flex flex-col gap-2">
          <span class="text-sm font-medium text-n-slate-12">
            {{ key('REPLY.BUTTON_TYPE_LABEL') }}
          </span>
          <FilterSelect
            :model-value="replyButtonType"
            :options="buttonTypeOptions"
            class="self-start"
            @update:model-value="onReplyButtonTypeChange"
          />
        </div>

        <Input
          v-if="headerRequired && replyButtonType !== 'none'"
          :model-value="reply.header || ''"
          :label="key('HEADER.LABEL')"
          :placeholder="key('HEADER.PLACEHOLDER')"
          :message="key('HEADER.HELP')"
          @update:model-value="updateReply({ header: $event })"
        />

        <div
          v-for="(button, index) in replyButtons"
          :key="index"
          class="flex flex-wrap gap-2 items-end"
        >
          <template v-if="replyButtonType === 'action'">
            <FilterSelect
              :model-value="button.type"
              :options="actionTypeOptions"
              @update:model-value="updateReplyButton(index, { type: $event })"
            />
            <Input
              :model-value="button.text"
              :placeholder="key('REPLY.ACTION.TEXT_PLACEHOLDER')"
              class="flex-1 min-w-32"
              @update:model-value="updateReplyButton(index, { text: $event })"
            />
            <Input
              v-if="button.type === 'url'"
              :model-value="button.url"
              :placeholder="key('REPLY.ACTION.URL_PLACEHOLDER')"
              class="flex-1 min-w-40"
              @update:model-value="updateReplyButton(index, { url: $event })"
            />
            <Input
              v-else
              :model-value="button.phone_number"
              :placeholder="key('REPLY.ACTION.PHONE_PLACEHOLDER')"
              class="flex-1 min-w-40"
              @update:model-value="
                updateReplyButton(index, { phone_number: $event })
              "
            />
          </template>
          <template v-else>
            <Input
              :model-value="button.title"
              :placeholder="key('BUTTONS.TITLE_PLACEHOLDER')"
              :maxlength="MAX_TITLE_LENGTH"
              class="flex-1 min-w-40"
              @update:model-value="updateReplyButton(index, { title: $event })"
            />
            <label class="flex gap-2 items-center pb-2 text-sm text-n-slate-11">
              <input
                type="checkbox"
                :checked="button.reopen || false"
                @change="
                  updateReplyButton(index, { reopen: $event.target.checked })
                "
              />
              {{ key('BUTTONS.REOPEN') }}
            </label>
          </template>
          <NextButton
            sm
            ghost
            ruby
            icon="i-lucide-trash-2"
            :aria-label="key('BUTTONS.REMOVE')"
            @click="removeReplyButton(index)"
          />
        </div>

        <NextButton
          v-if="replyButtonType !== 'none' && replyButtons.length < MAX_BUTTONS"
          sm
          faded
          slate
          icon="i-lucide-plus"
          :label="key('BUTTONS.ADD')"
          class="self-start"
          @click="addReplyButton"
        />
      </div>
    </template>

    <p class="text-xs text-n-slate-11">
      {{ key('BUTTONS.MAX_TITLE_HELP', { maxTitleLength: MAX_TITLE_LENGTH }) }}
    </p>
  </div>
</template>
