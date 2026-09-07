<script setup>
import { ref, computed, watchEffect } from 'vue';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ImageUploadField from './ImageUploadField.vue';

const emit = defineEmits(['update']);

const MAX_BUTTONS = 3;
const MAX_BODY_LENGTH = 1024;
const MAX_HEADER_LENGTH = 60;
const MAX_BUTTON_LABEL = 20;

const PIX_KEY_TYPES = ['phone', 'email', 'cpf', 'cnpj', 'random'];

let nextId = 0;
const newButton = () => {
  nextId += 1;
  return { id: nextId, type: 'url', text: '', url: '', phoneNumber: '', copyCode: '' };
};

// Evolution GO refuses a message that mixes a Pix button with anything else, so the two are
// modes of the form rather than entries of the same list.
const mode = ref('cta');
const title = ref('');
const body = ref('');
const footer = ref('');
const imageUrl = ref('');
const buttons = ref([newButton()]);

const pixKey = ref('');
const pixKeyType = ref('cpf');
const pixName = ref('');

const isHttpUrl = value => {
  try {
    const parsed = new URL(value.trim());
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
};

// WhatsApp dials the number as given, so anything that is not E.164 reaches the contact as a
// button that fails on tap.
const isPhoneNumber = value => /^\+[1-9]\d{7,14}$/.test(value.trim());

const isButtonValid = button => {
  if (!button.text.trim()) return false;
  if (button.type === 'url') return isHttpUrl(button.url);
  if (button.type === 'call') return isPhoneNumber(button.phoneNumber);
  return button.copyCode.trim().length > 0;
};

const hasInvalidButton = computed(() =>
  buttons.value.some(button => !isButtonValid(button))
);

const isValid = computed(() => {
  // Evolution GO rejects the send without a header and a body.
  if (!title.value.trim() || !body.value.trim()) return false;

  if (mode.value === 'pix') {
    return pixKey.value.trim().length > 0 && pixName.value.trim().length > 0;
  }

  return !hasInvalidButton.value;
});

const buttonPayload = button => {
  const text = button.text.trim();

  if (button.type === 'url') return { type: 'url', text, url: button.url.trim() };
  if (button.type === 'call') {
    return { type: 'call', text, phone_number: button.phoneNumber.trim() };
  }

  return { type: 'copy', text, copy_code: button.copyCode.trim() };
};

const payload = computed(() => ({
  message: body.value.trim(),
  // These buttons have no equivalent on the other channels, so they travel as a plain text
  // message carrying an Evolution GO specific key instead of as input_select.
  contentType: 'text',
  contentAttributes: {
    whatsapp_buttons: {
      title: title.value.trim(),
      footer: footer.value.trim() || undefined,
      image_url: imageUrl.value.trim() || undefined,
      buttons:
        mode.value === 'pix'
          ? [
              {
                type: 'pix',
                key: pixKey.value.trim(),
                key_type: pixKeyType.value,
                name: pixName.value.trim(),
                currency: 'BRL',
              },
            ]
          : buttons.value.map(buttonPayload),
    },
  },
}));

const addButton = () => {
  if (buttons.value.length >= MAX_BUTTONS) return;
  buttons.value.push(newButton());
};

const removeButton = index => {
  buttons.value.splice(index, 1);
};

watchEffect(() =>
  emit('update', { valid: isValid.value, payload: payload.value })
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <p class="text-sm text-n-slate-11">
      {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.HINT') }}
    </p>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.MODE_LABEL') }}
      </span>
      <select v-model="mode" class="!mb-0">
        <option value="cta">
          {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.MODE_CTA') }}
        </option>
        <option value="pix">
          {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.MODE_PIX') }}
        </option>
      </select>
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.HEADER_LABEL') }}
      </span>
      <input
        v-model="title"
        type="text"
        class="!mb-0"
        :maxlength="MAX_HEADER_LENGTH"
        :placeholder="
          $t('CONVERSATION.RICH_MESSAGE.BUTTONS.HEADER_PLACEHOLDER')
        "
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.BODY_LABEL') }}
      </span>
      <textarea
        v-model="body"
        rows="3"
        :maxlength="MAX_BODY_LENGTH"
        :placeholder="$t('CONVERSATION.RICH_MESSAGE.BUTTONS.BODY_PLACEHOLDER')"
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
        {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.IMAGE_LABEL') }}
      </span>
      <ImageUploadField v-model="imageUrl" />
    </div>

    <template v-if="mode === 'cta'">
      <div class="flex flex-col gap-3">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.BUTTONS_LABEL') }}
        </span>

        <div
          v-for="(button, index) in buttons"
          :key="button.id"
          class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak"
        >
          <div class="flex items-center gap-2">
            <select v-model="button.type" class="!mb-0 w-40">
              <option value="url">
                {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.TYPE_URL') }}
              </option>
              <option value="call">
                {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.TYPE_CALL') }}
              </option>
              <option value="copy">
                {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.TYPE_COPY') }}
              </option>
            </select>
            <input
              v-model="button.text"
              type="text"
              class="!mb-0 flex-1"
              :maxlength="MAX_BUTTON_LABEL"
              :placeholder="
                $t('CONVERSATION.RICH_MESSAGE.BUTTONS.BUTTON_TEXT')
              "
            />
            <NextButton
              v-if="buttons.length > 1"
              ghost
              slate
              sm
              icon="i-lucide-trash-2"
              @click="removeButton(index)"
            />
          </div>

          <input
            v-if="button.type === 'url'"
            v-model="button.url"
            type="url"
            class="!mb-0"
            placeholder="https://exemplo.com"
          />
          <input
            v-else-if="button.type === 'call'"
            v-model="button.phoneNumber"
            type="tel"
            class="!mb-0"
            placeholder="+5582988898565"
          />
          <input
            v-else
            v-model="button.copyCode"
            type="text"
            class="!mb-0"
            :placeholder="$t('CONVERSATION.RICH_MESSAGE.BUTTONS.COPY_CODE')"
          />
        </div>

        <button
          v-if="buttons.length < MAX_BUTTONS"
          type="button"
          class="flex items-center gap-1 text-sm font-medium w-fit text-n-blue-11"
          @click="addButton"
        >
          <Icon icon="i-lucide-plus" class="size-4" />
          {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.ADD_BUTTON') }}
        </button>

        <p v-if="hasInvalidButton" class="text-sm text-n-ruby-11">
          {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.BUTTON_ERROR') }}
        </p>
      </div>
    </template>

    <template v-else>
      <div class="flex flex-col gap-3">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('CONVERSATION.RICH_MESSAGE.BUTTONS.PIX_LABEL') }}
        </span>
        <div class="flex gap-2">
          <select v-model="pixKeyType" class="!mb-0 w-40">
            <option v-for="keyType in PIX_KEY_TYPES" :key="keyType" :value="keyType">
              {{
                $t(
                  `CONVERSATION.RICH_MESSAGE.BUTTONS.PIX_KEY_TYPE_${keyType.toUpperCase()}`
                )
              }}
            </option>
          </select>
          <input
            v-model="pixKey"
            type="text"
            class="!mb-0 flex-1"
            :placeholder="$t('CONVERSATION.RICH_MESSAGE.BUTTONS.PIX_KEY')"
          />
        </div>
        <input
          v-model="pixName"
          type="text"
          class="!mb-0"
          :maxlength="MAX_HEADER_LENGTH"
          :placeholder="$t('CONVERSATION.RICH_MESSAGE.BUTTONS.PIX_NAME')"
        />
      </div>
    </template>
  </div>
</template>
