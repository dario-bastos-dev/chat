<script setup>
import { computed } from 'vue';
import BaseBubble from './Base.vue';
import FormattedContent from './Text/FormattedContent.vue';
import { useMessageContext } from '../provider.js';

const { content, contentAttributes } = useMessageContext();

// MessageList deep-camelCases the payload, so media_url arrives as mediaUrl here.
const cards = computed(() => contentAttributes.value?.items ?? []);
const footer = computed(() => contentAttributes.value?.footer);
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="cards">
    <FormattedContent v-if="content" :content="content" />

    <div class="flex gap-3 mt-3 overflow-x-auto">
      <div
        v-for="(card, index) in cards"
        :key="index"
        class="flex flex-col gap-2 p-2 rounded-lg shrink-0 w-52 bg-n-alpha-2"
      >
        <img
          v-if="card.mediaUrl"
          :src="card.mediaUrl"
          :alt="card.title"
          class="object-cover w-full rounded-md h-28"
        />
        <span class="text-sm font-medium text-n-slate-12">
          {{ card.title }}
        </span>
        <span v-if="card.description" class="text-sm text-n-slate-11">
          {{ card.description }}
        </span>
        <template v-for="(action, actionIndex) in card.actions" :key="actionIndex">
          <a
            v-if="action.type === 'link'"
            :href="action.uri"
            target="_blank"
            rel="noopener noreferrer"
            class="px-2 py-1 text-sm text-center rounded-md text-n-blue-11 bg-n-alpha-1"
          >
            {{ action.text }}
          </a>
          <span
            v-else
            class="px-2 py-1 text-sm text-center rounded-md text-n-slate-12 bg-n-alpha-1"
          >
            {{ action.text }}
          </span>
        </template>
      </div>
    </div>

    <span v-if="footer" class="block mt-2 text-xs text-n-slate-11">
      {{ footer }}
    </span>
  </BaseBubble>
</template>
