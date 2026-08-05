<script setup>
import { computed } from 'vue';

const props = defineProps({
  header: { type: Object, default: () => ({}) },
  body: { type: Object, default: () => ({}) },
  footer: { type: Object, default: () => ({}) },
  buttons: { type: Array, default: () => [] },
});

const interpolate = (text, examples) => {
  if (!text) return '';
  return text.replace(/\{\{(\d+)\}\}/g, (match, index) => {
    const sample = examples?.[Number(index) - 1];
    return sample || match;
  });
};

const headerText = computed(() =>
  interpolate(props.header?.text, props.header?.example)
);
const isMediaHeader = computed(
  () => props.header?.format && props.header.format !== 'TEXT'
);
const mediaLabel = computed(
  () => props.header?.fileName || props.header?.format
);
const bodyText = computed(() =>
  interpolate(props.body?.text, props.body?.example)
);
const visibleButtons = computed(() =>
  props.buttons.filter(button => button.text)
);
</script>

<template>
  <div class="p-4 rounded-lg bg-n-slate-3">
    <div
      class="flex flex-col gap-2 p-3 max-w-sm rounded-lg shadow-sm bg-n-background"
    >
      <div
        v-if="isMediaHeader"
        class="flex justify-center items-center h-24 text-xs rounded-md bg-n-slate-4 text-n-slate-11"
      >
        {{ mediaLabel }}
      </div>
      <span
        v-else-if="headerText"
        class="text-sm font-semibold break-words text-n-slate-12"
      >
        {{ headerText }}
      </span>
      <span
        v-if="bodyText"
        class="text-sm whitespace-pre-wrap break-words text-n-slate-12"
      >
        {{ bodyText }}
      </span>
      <span v-if="footer?.text" class="text-xs break-words text-n-slate-10">
        {{ footer.text }}
      </span>
      <div
        v-if="visibleButtons.length"
        class="flex flex-col gap-1 pt-2 border-t border-n-weak"
      >
        <span
          v-for="(button, index) in visibleButtons"
          :key="index"
          class="py-1 text-sm text-center truncate text-n-brand"
        >
          {{ button.text }}
        </span>
      </div>
    </div>
  </div>
</template>
