<script setup>
import { ref, computed, watchEffect } from 'vue';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const emit = defineEmits(['update']);

const MAX_CARDS = 10;
// WhatsApp shows at most three buttons per carousel card.
const MAX_BUTTONS = 3;
const MAX_BODY_LENGTH = 1024;
const MAX_TITLE_LENGTH = 60;
const MAX_DESCRIPTION_LENGTH = 200;
const MAX_BUTTON_LABEL = 20;

let nextId = 0;
const uid = () => {
  nextId += 1;
  return nextId;
};

const newButton = () => ({ id: uid(), text: '', type: 'postback', uri: '' });
const newCard = () => ({
  id: uid(),
  title: '',
  description: '',
  mediaUrl: '',
  buttons: [newButton()],
});

const body = ref('');
const footer = ref('');
const cards = ref([newCard()]);

const isHttpUrl = value => {
  try {
    const parsed = new URL(value.trim());
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
};

const isPhoneNumber = value => /^\+[1-9]\d{7,14}$/.test(value.trim());

// link needs a URL, call a dialable number and copy a code; a quick reply needs nothing.
const isButtonDestinationValid = button => {
  if (button.type === 'link') return isHttpUrl(button.uri);
  if (button.type === 'call') return isPhoneNumber(button.uri);
  if (button.type === 'copy') return button.uri.trim().length > 0;

  return true;
};

// ContentAttributeValidator only allows text/type/payload/uri on an action, so link and call
// share `uri` as the destination and copy puts its code in `payload`.
const buttonPayload = button => {
  const text = button.text.trim();

  if (button.type === 'link') return { text, type: 'link', uri: button.uri.trim() };
  if (button.type === 'call') return { text, type: 'call', uri: button.uri.trim() };
  if (button.type === 'copy') {
    return { text, type: 'copy', payload: button.uri.trim() };
  }

  return { text, type: 'postback', payload: text };
};

const filledButtons = card =>
  card.buttons.filter(button => button.text.trim().length > 0);

// Chatwoot rejects a card without actions, and a link button without a destination would reach
// WhatsApp as a dead tap, so both are blocked before the message is created.
const isCardValid = card =>
  card.title.trim().length > 0 &&
  filledButtons(card).length > 0 &&
  filledButtons(card).every(isButtonDestinationValid) &&
  (!card.mediaUrl.trim() || isHttpUrl(card.mediaUrl));

const hasInvalidCard = computed(() => cards.value.some(card => !isCardValid(card)));

const isValid = computed(
  () => body.value.trim().length > 0 && !hasInvalidCard.value
);

const payload = computed(() => ({
  message: body.value.trim(),
  contentType: 'cards',
  contentAttributes: {
    footer: footer.value.trim() || undefined,
    items: cards.value.map(card => ({
      title: card.title.trim(),
      description: card.description.trim() || undefined,
      media_url: card.mediaUrl.trim() || undefined,
      actions: filledButtons(card).map(buttonPayload),
    })),
  },
}));

const addCard = () => {
  if (cards.value.length >= MAX_CARDS) return;
  cards.value.push(newCard());
};

const removeCard = index => {
  cards.value.splice(index, 1);
};

const addButton = card => {
  if (card.buttons.length >= MAX_BUTTONS) return;
  card.buttons.push(newButton());
};

const removeButton = (card, index) => {
  card.buttons.splice(index, 1);
};

watchEffect(() =>
  emit('update', { valid: isValid.value, payload: payload.value })
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <p class="text-sm text-n-slate-11">
      {{ $t('CONVERSATION.RICH_MESSAGE.CAROUSEL.HINT') }}
    </p>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.CAROUSEL.BODY_LABEL') }}
      </span>
      <textarea
        v-model="body"
        rows="2"
        :maxlength="MAX_BODY_LENGTH"
        :placeholder="$t('CONVERSATION.RICH_MESSAGE.CAROUSEL.BODY_PLACEHOLDER')"
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
        :maxlength="MAX_TITLE_LENGTH"
        :placeholder="$t('CONVERSATION.RICH_MESSAGE.FOOTER_PLACEHOLDER')"
      />
    </label>

    <div
      v-for="(card, cardIndex) in cards"
      :key="card.id"
      class="flex flex-col gap-3 p-3 border rounded-lg border-n-weak"
    >
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium text-n-slate-12">
          {{
            $t('CONVERSATION.RICH_MESSAGE.CAROUSEL.CARD_LABEL', {
              index: cardIndex + 1,
            })
          }}
        </span>
        <NextButton
          v-if="cards.length > 1"
          ghost
          slate
          sm
          icon="i-lucide-trash-2"
          @click="removeCard(cardIndex)"
        />
      </div>

      <input
        v-model="card.title"
        type="text"
        class="!mb-0"
        :maxlength="MAX_TITLE_LENGTH"
        :placeholder="$t('CONVERSATION.RICH_MESSAGE.CAROUSEL.CARD_TITLE')"
      />
      <input
        v-model="card.description"
        type="text"
        class="!mb-0"
        :maxlength="MAX_DESCRIPTION_LENGTH"
        :placeholder="$t('CONVERSATION.RICH_MESSAGE.CAROUSEL.CARD_DESCRIPTION')"
      />
      <input
        v-model="card.mediaUrl"
        type="url"
        class="!mb-0"
        :placeholder="$t('CONVERSATION.RICH_MESSAGE.CAROUSEL.CARD_MEDIA')"
      />

      <div
        v-for="(button, buttonIndex) in card.buttons"
        :key="button.id"
        class="flex flex-col gap-2 sm:flex-row sm:items-center"
      >
        <input
          v-model="button.text"
          type="text"
          class="!mb-0 flex-1"
          :maxlength="MAX_BUTTON_LABEL"
          :placeholder="$t('CONVERSATION.RICH_MESSAGE.CAROUSEL.BUTTON_TEXT')"
        />
        <select v-model="button.type" class="!mb-0 w-full sm:w-40">
          <option value="postback">
            {{ $t('CONVERSATION.RICH_MESSAGE.CAROUSEL.BUTTON_TYPE_REPLY') }}
          </option>
          <option value="link">
            {{ $t('CONVERSATION.RICH_MESSAGE.CAROUSEL.BUTTON_TYPE_LINK') }}
          </option>
          <option value="call">
            {{ $t('CONVERSATION.RICH_MESSAGE.CAROUSEL.BUTTON_TYPE_CALL') }}
          </option>
          <option value="copy">
            {{ $t('CONVERSATION.RICH_MESSAGE.CAROUSEL.BUTTON_TYPE_COPY') }}
          </option>
        </select>
        <input
          v-if="button.type === 'link'"
          v-model="button.uri"
          type="url"
          class="!mb-0 flex-1"
          placeholder="https://exemplo.com"
        />
        <input
          v-else-if="button.type === 'call'"
          v-model="button.uri"
          type="tel"
          class="!mb-0 flex-1"
          placeholder="+5582988898565"
        />
        <input
          v-else-if="button.type === 'copy'"
          v-model="button.uri"
          type="text"
          class="!mb-0 flex-1"
          :placeholder="$t('CONVERSATION.RICH_MESSAGE.CAROUSEL.BUTTON_COPY_CODE')"
        />
        <NextButton
          v-if="card.buttons.length > 1"
          ghost
          slate
          sm
          icon="i-lucide-trash-2"
          @click="removeButton(card, buttonIndex)"
        />
      </div>

      <button
        v-if="card.buttons.length < MAX_BUTTONS"
        type="button"
        class="flex items-center gap-1 text-sm font-medium w-fit text-n-blue-11"
        @click="addButton(card)"
      >
        <Icon icon="i-lucide-plus" class="size-4" />
        {{ $t('CONVERSATION.RICH_MESSAGE.CAROUSEL.ADD_BUTTON') }}
      </button>
    </div>

    <button
      v-if="cards.length < MAX_CARDS"
      type="button"
      class="flex items-center gap-1 text-sm font-medium w-fit text-n-blue-11"
      @click="addCard"
    >
      <Icon icon="i-lucide-plus" class="size-4" />
      {{ $t('CONVERSATION.RICH_MESSAGE.CAROUSEL.ADD_CARD') }}
    </button>

    <p v-if="hasInvalidCard" class="text-sm text-n-ruby-11">
      {{ $t('CONVERSATION.RICH_MESSAGE.CAROUSEL.CARD_ERROR') }}
    </p>
  </div>
</template>
