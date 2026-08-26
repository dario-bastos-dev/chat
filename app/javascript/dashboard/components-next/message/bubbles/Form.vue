<script setup>
import { computed } from 'vue';
import BaseBubble from './Base.vue';
import FormattedContent from './Text/FormattedContent.vue';
import { useI18n } from 'vue-i18n';
import { CONTENT_TYPES } from '../constants.js';
import { useMessageContext } from '../provider.js';
import { useInbox } from 'dashboard/composables/useInbox';

const { content, contentAttributes, contentType } = useMessageContext();
const { t } = useI18n();
const { isAWebWidgetInbox } = useInbox();

const formValues = computed(() => {
  if (contentType.value === CONTENT_TYPES.FORM) {
    const { items, submittedValues = [] } = contentAttributes.value;

    if (submittedValues.length) {
      return submittedValues.map(submittedValue => {
        const item = items.find(
          formItem => formItem.name === submittedValue.name
        );
        return {
          title: submittedValue.value,
          value: submittedValue.value,
          label: item?.label,
        };
      });
    }

    return [];
  }

  if (contentType.value === CONTENT_TYPES.INPUT_SELECT) {
    const [item] = contentAttributes.value?.submittedValues ?? [];
    if (!item) return [];

    return [
      {
        title: item.title,
        value: item.value,
        label: '',
      },
    ];
  }

  return [];
});

// On WhatsApp the options are rendered by the contact's app, so without this the agent sees
// only the body of the message they just sent. The widget already has its own copy for an
// unanswered prompt, so it keeps it.
const offeredOptions = computed(() => {
  if (contentType.value !== CONTENT_TYPES.INPUT_SELECT) return [];
  if (isAWebWidgetInbox.value || formValues.value.length) return [];

  return (contentAttributes.value?.items ?? []).map(item => item.title);
});
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="csat">
    <FormattedContent v-if="content" :content="content" />
    <dl v-if="formValues.length" class="mt-4">
      <template v-for="item in formValues" :key="item.title">
        <dt class="text-n-slate-11 italic mt-2">
          {{ item.label || t('CONVERSATION.RESPONSE') }}
        </dt>
        <dd>{{ item.title }}</dd>
      </template>
    </dl>
    <div v-else-if="offeredOptions.length" class="flex flex-col gap-1 mt-3">
      <span
        v-for="option in offeredOptions"
        :key="option"
        class="px-3 py-1 text-sm text-center rounded-md bg-n-alpha-2 text-n-slate-12"
      >
        {{ option }}
      </span>
    </div>
    <div v-else-if="isAWebWidgetInbox" class="my-2 font-medium">
      {{ t('CONVERSATION.NO_RESPONSE') }}
    </div>
  </BaseBubble>
</template>
