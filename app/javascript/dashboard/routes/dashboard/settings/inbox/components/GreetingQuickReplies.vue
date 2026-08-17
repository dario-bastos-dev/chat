<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

// Mirrors the Limits:: constants used by the Inbox validation
const MAX_ITEMS = 13;
const MAX_LINK_ITEMS = 3;
const MAX_TITLE_LENGTH = 20;

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const hasLink = computed(() => props.modelValue.some(item => item.uri));

const maxItems = computed(() => (hasLink.value ? MAX_LINK_ITEMS : MAX_ITEMS));

const canAddItem = computed(() => props.modelValue.length < maxItems.value);

const updateItem = (index, attributes) => {
  const items = props.modelValue.map((item, i) =>
    i === index ? { ...item, ...attributes } : item
  );
  emit('update:modelValue', items);
};

const addItem = () => {
  emit('update:modelValue', [
    ...props.modelValue,
    { title: '', value: '', uri: '' },
  ]);
};

const removeItem = index => {
  emit(
    'update:modelValue',
    props.modelValue.filter((_, i) => i !== index)
  );
};
</script>

<template>
  <div class="flex flex-col gap-2 mt-4">
    <label class="text-sm font-medium text-n-slate-12">
      {{ t('INBOX_MGMT.SETTINGS_POPUP.GREETING_QUICK_REPLIES.LABEL') }}
    </label>
    <p class="text-sm text-n-slate-11">
      {{
        t('INBOX_MGMT.SETTINGS_POPUP.GREETING_QUICK_REPLIES.HELP_TEXT', {
          maxItems,
          maxTitleLength: MAX_TITLE_LENGTH,
        })
      }}
    </p>
    <p v-if="hasLink" class="text-sm text-n-slate-11">
      {{ t('INBOX_MGMT.SETTINGS_POPUP.GREETING_QUICK_REPLIES.LINK_HELP_TEXT') }}
    </p>
    <div
      v-for="(item, index) in modelValue"
      :key="index"
      class="flex items-center gap-2"
    >
      <Input
        :model-value="item.title"
        :maxlength="MAX_TITLE_LENGTH"
        class="flex-1"
        :placeholder="
          t('INBOX_MGMT.SETTINGS_POPUP.GREETING_QUICK_REPLIES.PLACEHOLDER')
        "
        @update:model-value="
          value => updateItem(index, { title: value, value })
        "
      />
      <Input
        :model-value="item.uri"
        type="url"
        class="flex-1"
        :placeholder="
          t('INBOX_MGMT.SETTINGS_POPUP.GREETING_QUICK_REPLIES.LINK_PLACEHOLDER')
        "
        @update:model-value="value => updateItem(index, { uri: value })"
      />
      <NextButton
        icon="i-lucide-trash-2"
        ghost
        slate
        sm
        :aria-label="
          t('INBOX_MGMT.SETTINGS_POPUP.GREETING_QUICK_REPLIES.REMOVE')
        "
        @click="removeItem(index)"
      />
    </div>
    <NextButton
      v-if="canAddItem"
      icon="i-lucide-plus"
      faded
      slate
      sm
      class="self-start"
      :label="t('INBOX_MGMT.SETTINGS_POPUP.GREETING_QUICK_REPLIES.ADD')"
      @click="addItem"
    />
  </div>
</template>
