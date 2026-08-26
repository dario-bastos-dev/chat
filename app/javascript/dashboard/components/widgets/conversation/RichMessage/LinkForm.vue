<script setup>
import { ref, computed, watchEffect } from 'vue';

const emit = defineEmits(['update']);

const MAX_TITLE_LENGTH = 60;
const MAX_DESCRIPTION_LENGTH = 200;
const MAX_BODY_LENGTH = 1024;

const url = ref('');
const text = ref('');
const title = ref('');
const description = ref('');
const imageUrl = ref('');

const isHttpUrl = value => {
  try {
    const parsed = new URL(value.trim());
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
};

const isUrlValid = computed(() => isHttpUrl(url.value));
// An unreachable image would render the preview without a thumbnail, so only the shape is
// checked here and the provider decides whether it can fetch it.
const isImageUrlValid = computed(
  () => !imageUrl.value.trim() || isHttpUrl(imageUrl.value)
);

const isValid = computed(() => isUrlValid.value && isImageUrlValid.value);

const payload = computed(() => ({
  // The preview needs the link inside the body too, otherwise the bubble shows a card with
  // nothing to tap on the agent side.
  message: text.value.trim() || url.value.trim(),
  contentType: 'text',
  contentAttributes: {
    link_preview: {
      url: url.value.trim(),
      title: title.value.trim() || undefined,
      description: description.value.trim() || undefined,
      image_url: imageUrl.value.trim() || undefined,
    },
  },
}));

watchEffect(() =>
  emit('update', { valid: isValid.value, payload: payload.value })
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <p class="text-sm text-n-slate-11">
      {{ $t('CONVERSATION.RICH_MESSAGE.LINK.HINT') }}
    </p>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.LINK.URL_LABEL') }}
      </span>
      <input
        v-model="url"
        type="url"
        class="!mb-0"
        placeholder="https://exemplo.com/pagina"
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.LINK.TEXT_LABEL') }}
      </span>
      <textarea
        v-model="text"
        rows="2"
        :maxlength="MAX_BODY_LENGTH"
        :placeholder="$t('CONVERSATION.RICH_MESSAGE.LINK.TEXT_PLACEHOLDER')"
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.LINK.TITLE_LABEL') }}
      </span>
      <input
        v-model="title"
        type="text"
        class="!mb-0"
        :maxlength="MAX_TITLE_LENGTH"
        :placeholder="$t('CONVERSATION.RICH_MESSAGE.LINK.TITLE_PLACEHOLDER')"
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.LINK.DESCRIPTION_LABEL') }}
      </span>
      <input
        v-model="description"
        type="text"
        class="!mb-0"
        :maxlength="MAX_DESCRIPTION_LENGTH"
        :placeholder="
          $t('CONVERSATION.RICH_MESSAGE.LINK.DESCRIPTION_PLACEHOLDER')
        "
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.LINK.IMAGE_LABEL') }}
      </span>
      <input
        v-model="imageUrl"
        type="url"
        class="!mb-0"
        placeholder="https://exemplo.com/imagem.jpg"
      />
    </label>

    <p v-if="url && !isUrlValid" class="text-sm text-n-ruby-11">
      {{ $t('CONVERSATION.RICH_MESSAGE.LINK.URL_ERROR') }}
    </p>
    <p v-if="!isImageUrlValid" class="text-sm text-n-ruby-11">
      {{ $t('CONVERSATION.RICH_MESSAGE.LINK.IMAGE_ERROR') }}
    </p>
  </div>
</template>
