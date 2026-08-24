<script setup>
import { computed } from 'vue';

const props = defineProps({
  header: { type: Object, default: () => ({}) },
  body: { type: Object, default: () => ({}) },
  footer: { type: Object, default: () => ({}) },
  buttons: { type: Array, default: () => [] },
});

// Samples arrive in the order the placeholders first appear, which works for
// both {{1}} and {{order_id}} without the preview caring which style is used.
// A fresh regex per call keeps `lastIndex` from leaking between the two passes.
const variablePattern = () => /\{\{\s*([A-Za-z0-9_]+)\s*\}\}/g;

const interpolate = (text, examples) => {
  if (!text) return '';

  const order = [
    ...new Set([...text.matchAll(variablePattern())].map(match => match[1])),
  ];

  return text.replace(variablePattern(), (match, name) => {
    const sample = examples?.[order.indexOf(name)];
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

// A picked file is previewed straight from the browser via an object URL; on
// edit it is the URL already stored for the template. Documents have nothing to
// render inline, so they keep the label.
const mediaUrl = computed(() => props.header?.mediaUrl || '');
const previewableImage = computed(
  () => mediaUrl.value && props.header?.format === 'IMAGE'
);
const previewableVideo = computed(
  () => mediaUrl.value && props.header?.format === 'VIDEO'
);
const bodyText = computed(() =>
  interpolate(props.body?.text, props.body?.example)
);
// A copy code button carries no label of its own, so it still shows up in the
// preview with the label Meta renders for it.
const visibleButtons = computed(() =>
  props.buttons.filter(button => button.text || button.type === 'COPY_CODE')
);
</script>

<template>
  <div class="p-4 rounded-lg bg-n-slate-3">
    <div
      class="flex flex-col gap-2 p-3 max-w-sm rounded-lg shadow-sm bg-n-background"
    >
      <img
        v-if="previewableImage"
        :src="mediaUrl"
        :alt="mediaLabel"
        class="object-cover w-full h-32 rounded-md bg-n-slate-4"
      />
      <video
        v-else-if="previewableVideo"
        :src="mediaUrl"
        controls
        class="object-cover w-full h-32 rounded-md bg-n-slate-4"
      />
      <div
        v-else-if="isMediaHeader"
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
          {{
            button.type === 'COPY_CODE'
              ? $t('WHATSAPP_TEMPLATE_MGMT.PREVIEW.COPY_CODE_LABEL')
              : button.text
          }}
        </span>
      </div>
    </div>
  </div>
</template>
