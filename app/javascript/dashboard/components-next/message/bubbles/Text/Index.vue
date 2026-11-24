<script setup>
import { computed, ref } from 'vue';
import { usePreferredReducedMotion } from '@vueuse/core';
import { useMapGetter } from 'dashboard/composables/store';
import BaseBubble from 'next/message/bubbles/Base.vue';
import FormattedContent from './FormattedContent.vue';
import AttachmentChips from 'next/message/chips/AttachmentChips.vue';
import Icon from 'next/icon/Icon.vue';
import TranslationToggle from 'dashboard/components-next/message/TranslationToggle.vue';
import { MESSAGE_TYPES } from '../../constants';
import { MESSAGE_STATUS } from 'shared/constants/messages';
import { useMessageContext } from '../../provider.js';
import { useTranslations } from 'dashboard/composables/useTranslations';

const TEXT_SHIMMER_CLASS =
  'bg-clip-text bg-gradient-to-r from-n-iris-9 from-25% via-n-iris-12 to-n-iris-9 to-75% dark:from-n-slate-12 dark:from-35% dark:via-n-iris-10 dark:to-n-slate-12 dark:to-65% bg-[length:300%_100%] animate-text-shimmer motion-reduce:animate-none [&_*]:!text-transparent [&_*]:!bg-transparent';
const HEIGHT_MORPH = {
  duration: 300,
  easing: 'cubic-bezier(0.2, 0.8, 0.2, 1)',
};

const {
  id,
  content,
  attachments,
  contentAttributes,
  messageType,
  contactSide,
  status,
  showingOriginal,
  isCaptainMessage,
} = useMessageContext();

const { hasTranslations, translationContent } = useTranslations(
  contentAttributes,
  contactSide
);
const reducedMotion = usePreferredReducedMotion();

const translationState = useMapGetter('getMessageTranslationState');
const isTranslating = computed(() => translationState.value(id.value).pending);

const contentWrapper = ref(null);
let heightBeforeChange = 0;

const renderContent = computed(() => {
  if (showingOriginal.value) {
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

const contactInfoRequestState = computed(() => {
  if (status.value === MESSAGE_STATUS.FAILED) return null;

  return contentAttributes.value?.whatsappContactInfo?.state;
});

const isEmpty = computed(() => {
  return !content.value && !attachments.value?.length;
});

// The Evolution GO call-to-action and Pix buttons are rendered by the contact's app, so the agent
// view has to redraw them from what was sent.
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
  showingOriginal.value = !showingOriginal.value;
};

const measureHeight = () => {
  heightBeforeChange = contentWrapper.value.offsetHeight;
};

const morphHeight = () => {
  if (reducedMotion.value === 'reduce') return;

  const wrapper = contentWrapper.value;
  wrapper.animate(
    { height: [`${heightBeforeChange}px`, `${wrapper.offsetHeight}px`] },
    HEIGHT_MORPH
  );
};
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="text">
    <div class="gap-3 flex flex-col">
      <span v-if="isEmpty" class="text-n-slate-11">
        {{ $t('CONVERSATION.NO_CONTENT') }}
      </span>
      <div
        v-if="renderContent"
        ref="contentWrapper"
        class="overflow-hidden"
        :aria-busy="isTranslating"
      >
        <Transition
          mode="out-in"
          enter-from-class="opacity-0 blur-[0.125rem]"
          enter-active-class="transition duration-300 ease-out motion-reduce:transition-none"
          leave-active-class="transition duration-150 ease-in motion-reduce:transition-none"
          leave-to-class="opacity-0 blur-[0.125rem]"
          @before-leave="measureHeight"
          @enter="morphHeight"
        >
          <div :key="renderContent">
            <div :class="{ [TEXT_SHIMMER_CLASS]: isTranslating }">
              <FormattedContent :content="renderContent" />
            </div>
            <TranslationToggle
              v-if="!isCaptainMessage"
              class="mt-0.5"
              :showing-original="showingOriginal"
              @toggle="handleSeeOriginal"
            />
          </div>
        </Transition>
      </div>
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
      <span
        v-if="contactInfoRequestState === 'pending'"
        class="text-xs font-medium text-n-slate-11"
      >
        {{ $t('CONVERSATION.REQUEST_CONTACT_INFO.STATES.PENDING') }}
      </span>
      <span
        v-else-if="contactInfoRequestState === 'shared'"
        class="text-xs font-medium text-n-slate-11"
      >
        {{ $t('CONVERSATION.REQUEST_CONTACT_INFO.STATES.SHARED') }}
      </span>
      <span
        v-else-if="contactInfoRequestState === 'identity_conflict'"
        class="text-xs font-medium text-n-slate-11"
      >
        {{ $t('CONVERSATION.REQUEST_CONTACT_INFO.STATES.IDENTITY_CONFLICT') }}
      </span>
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
