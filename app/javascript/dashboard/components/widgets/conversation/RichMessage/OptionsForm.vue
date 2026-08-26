<script setup>
import { ref, computed, watchEffect } from 'vue';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const emit = defineEmits(['update']);

// WhatsApp renders up to three options as tappable buttons; past that it switches to a list,
// which the provider does automatically. Ten rows is WhatsApp's ceiling for a single section.
const MAX_BUTTON_OPTIONS = 3;
const MAX_OPTIONS = 10;
const MAX_BODY_LENGTH = 1024;
// WhatsApp caps the header and the footer at 60 characters each.
const MAX_HEADER_LENGTH = 60;
// WhatsApp caps a reply button label at 20 characters but allows 24 on a list row, so the
// ceiling moves as soon as a fourth option turns the message into a list.
const MAX_BUTTON_LABEL = 20;
const MAX_ROW_LABEL = 24;

let nextOptionId = 0;
const newOption = () => {
  nextOptionId += 1;
  return { id: nextOptionId, title: '' };
};

const header = ref('');
const footer = ref('');
const body = ref('');
const options = ref([newOption(), newOption()]);

const filledOptions = computed(() =>
  options.value.map(option => option.title.trim()).filter(Boolean)
);

const isList = computed(() => filledOptions.value.length > MAX_BUTTON_OPTIONS);

const maxOptionLength = computed(() =>
  isList.value ? MAX_ROW_LABEL : MAX_BUTTON_LABEL
);

// maxlength stops new typing but does not shorten what is already there, so removing an
// option can leave a label that was legal as a list row and is too long for a button.
const hasTooLongOption = computed(() =>
  options.value.some(option => option.title.trim().length > maxOptionLength.value)
);

const hasDuplicates = computed(
  () => new Set(filledOptions.value).size !== filledOptions.value.length
);

const isValid = computed(
  () =>
    // Evolution GO rejects the message without a header; the Cloud API ignores it.
    header.value.trim().length > 0 &&
    body.value.trim().length > 0 &&
    body.value.length <= MAX_BODY_LENGTH &&
    filledOptions.value.length >= 1 &&
    !hasDuplicates.value &&
    !hasTooLongOption.value
);

const payload = computed(() => ({
  message: body.value.trim(),
  contentType: 'input_select',
  contentAttributes: {
    title: header.value.trim(),
    footer: footer.value.trim() || undefined,
    // value is the callback payload WhatsApp echoes back; the label doubles as the value so
    // the reply is readable without a separate id to maintain.
    items: filledOptions.value.map(title => ({ title, value: title })),
  },
}));

const addOption = () => {
  if (options.value.length >= MAX_OPTIONS) return;
  options.value.push(newOption());
};

const removeOption = index => {
  options.value.splice(index, 1);
};

watchEffect(() => emit('update', { valid: isValid.value, payload: payload.value }));
</script>

<template>
  <div class="flex flex-col gap-6">
    <p class="text-sm text-n-slate-11">
      {{
        isList
          ? $t('CONVERSATION.RICH_MESSAGE.OPTIONS.HINT_LIST')
          : $t('CONVERSATION.RICH_MESSAGE.OPTIONS.HINT_BUTTONS')
      }}
    </p>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.OPTIONS.HEADER_LABEL') }}
      </span>
      <input
        v-model="header"
        type="text"
        class="!mb-0"
        :maxlength="MAX_HEADER_LENGTH"
        :placeholder="
          $t('CONVERSATION.RICH_MESSAGE.OPTIONS.HEADER_PLACEHOLDER')
        "
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.OPTIONS.BODY_LABEL') }}
      </span>
      <textarea
        v-model="body"
        rows="3"
        :maxlength="MAX_BODY_LENGTH"
        :placeholder="$t('CONVERSATION.RICH_MESSAGE.OPTIONS.BODY_PLACEHOLDER')"
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.FOOTER_LABEL') }}
      </span>
      <input
        v-model="footer"
        type="text"
        class="!mb-0"
        :maxlength="MAX_HEADER_LENGTH"
        :placeholder="$t('CONVERSATION.RICH_MESSAGE.FOOTER_PLACEHOLDER')"
      />
    </label>

    <div class="flex flex-col gap-2">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.OPTIONS.OPTIONS_LABEL') }}
      </span>

      <div
        v-for="(option, index) in options"
        :key="option.id"
        class="flex items-center gap-2"
      >
        <input
          v-model="option.title"
          type="text"
          class="!mb-0"
          :maxlength="maxOptionLength"
          :placeholder="
            $t('CONVERSATION.RICH_MESSAGE.OPTIONS.OPTION_PLACEHOLDER', {
              index: index + 1,
            })
          "
        />
        <NextButton
          v-if="options.length > 1"
          ghost
          slate
          sm
          icon="i-lucide-trash-2"
          @click="removeOption(index)"
        />
      </div>

      <button
        v-if="options.length < MAX_OPTIONS"
        type="button"
        class="flex items-center gap-1 text-sm font-medium w-fit text-n-blue-11"
        @click="addOption"
      >
        <Icon icon="i-lucide-plus" class="size-4" />
        {{ $t('CONVERSATION.RICH_MESSAGE.OPTIONS.ADD_OPTION') }}
      </button>

      <p v-if="hasDuplicates" class="text-sm text-n-ruby-11">
        {{ $t('CONVERSATION.RICH_MESSAGE.OPTIONS.DUPLICATE_ERROR') }}
      </p>
      <p v-if="hasTooLongOption" class="text-sm text-n-ruby-11">
        {{
          $t('CONVERSATION.RICH_MESSAGE.OPTIONS.TOO_LONG_ERROR', {
            max: maxOptionLength,
          })
        }}
      </p>
    </div>
  </div>
</template>
