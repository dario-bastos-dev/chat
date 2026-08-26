<script setup>
import { computed, ref } from 'vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import FormattedContent from './FormattedContent.vue';
import AttachmentChips from 'next/message/chips/AttachmentChips.vue';
import Icon from 'next/icon/Icon.vue';
import TranslationToggle from 'dashboard/components-next/message/TranslationToggle.vue';
import { MESSAGE_TYPES } from '../../constants';
import { useMessageContext } from '../../provider.js';
import { useTranslations } from 'dashboard/composables/useTranslations';

const { content, attachments, contentAttributes, messageType } =
  useMessageContext();

const { hasTranslations, translationContent } =
  useTranslations(contentAttributes);

const renderOriginal = ref(false);

const renderContent = computed(() => {
  if (renderOriginal.value) {
    return content.value;
  }

  if (hasTranslations.value) {
    return translationContent.value;
  }

  return content.value;
});

const isTemplate = computed(() => {
  return messageType.value === MESSAGE_TYPES.TEMPLATE;
});

const isEmpty = computed(() => {
  return !content.value && !attachments.value?.length;
});

// WhatsApp builds the preview card on the contact's device, so the agent only sees the card
// here if the message carries the metadata it was sent with.
const linkPreview = computed(() => contentAttributes.value?.linkPreview);

// Same for the Evolution GO call-to-action and Pix buttons: they are rendered by the contact's
// app, so the agent view has to redraw them from what was sent.
const whatsappButtons = computed(
  () => contentAttributes.value?.whatsappButtons
);

const BUTTON_ICONS = {
  url: 'i-lucide-external-link',
  call: 'i-lucide-phone',
  copy: 'i-lucide-copy',
  pix: 'i-lucide-qr-code',
};

const buttonLabel = button =>
  button.type === 'pix' ? `Pix · ${button.name}` : button.text;

const handleSeeOriginal = () => {
  renderOriginal.value = !renderOriginal.value;
};
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="text">
    <div class="gap-3 flex flex-col">
      <span v-if="isEmpty" class="text-n-slate-11">
        {{ $t('CONVERSATION.NO_CONTENT') }}
      </span>
      <FormattedContent v-if="renderContent" :content="renderContent" />
      <TranslationToggle
        v-if="hasTranslations"
        class="-mt-3"
        :showing-original="renderOriginal"
        @toggle="handleSeeOriginal"
      />
      <a
        v-if="linkPreview"
        :href="linkPreview.url"
        target="_blank"
        rel="noopener noreferrer"
        class="flex flex-col gap-1 p-2 -mt-1 rounded-lg bg-n-alpha-2"
      >
        <img
          v-if="linkPreview.imageUrl"
          :src="linkPreview.imageUrl"
          :alt="linkPreview.title || linkPreview.url"
          class="object-cover w-full rounded-md h-28"
        />
        <span
          v-if="linkPreview.title"
          class="text-sm font-medium text-n-slate-12"
        >
          {{ linkPreview.title }}
        </span>
        <span
          v-if="linkPreview.description"
          class="text-sm text-n-slate-11"
        >
          {{ linkPreview.description }}
        </span>
        <span class="text-sm break-all text-n-blue-11">
          {{ linkPreview.url }}
        </span>
      </a>
      <div v-if="whatsappButtons" class="flex flex-col gap-1 -mt-1">
        <span
          v-if="whatsappButtons.title"
          class="text-sm font-medium text-n-slate-12"
        >
          {{ whatsappButtons.title }}
        </span>
        <span
          v-for="(button, index) in whatsappButtons.buttons"
          :key="index"
          class="flex items-center justify-center gap-1 px-3 py-1 text-sm rounded-md bg-n-alpha-2 text-n-slate-12"
        >
          <Icon :icon="BUTTON_ICONS[button.type]" class="size-4" />
          {{ buttonLabel(button) }}
        </span>
        <span
          v-if="whatsappButtons.footer"
          class="text-xs text-n-slate-11"
        >
          {{ whatsappButtons.footer }}
        </span>
      </div>
      <AttachmentChips :attachments="attachments" class="gap-2" />
      <template v-if="isTemplate">
        <div
          v-if="contentAttributes.submittedEmail"
          class="px-2 py-1 rounded-lg bg-n-alpha-3"
        >
          {{ contentAttributes.submittedEmail }}
        </div>
      </template>
    </div>
  </BaseBubble>
</template>

<style>
p:last-child {
  margin-bottom: 0;
}
</style>
