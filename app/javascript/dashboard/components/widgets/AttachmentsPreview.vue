<script setup>
import { computed } from 'vue';
import { formatBytes } from 'shared/helpers/FileHelper';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  attachments: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['removeAttachment']);

const nonRecordedAudioAttachments = computed(() => {
  return props.attachments.filter(attachment => !attachment?.isVoiceMessage);
});

const recordedAudioAttachments = computed(() =>
  props.attachments.filter(attachment => attachment.isVoiceMessage)
);

const onRemoveAttachment = itemIndex => {
  emit(
    'removeAttachment',
    nonRecordedAudioAttachments.value
      .filter((_, index) => index !== itemIndex)
      .concat(recordedAudioAttachments.value)
  );
};

const formatFileSize = file => {
  const f = file.file || file;
  const size = f.byte_size || f.size;
  return formatBytes(size, 0);
};

const isTypeImage = file => {
  const f = file.file || file;
  const type = f.content_type || f.type;
  return type?.includes('image');
};

const isTypeVideo = file => {
  const f = file.file || file;
  const type = f.content_type || f.type;
  return type?.includes('video');
};

const fileName = file => {
  const f = file.file || file;
  return f.filename || f.name;
};
</script>

<template>
  <div class="flex flex-wrap gap-y-2 gap-x-2 overflow-auto max-h-[12.5rem]">
    <div
      v-for="(attachment, index) in nonRecordedAudioAttachments"
      :key="attachment.id"
      class="flex items-center p-2 bg-n-slate-3 dark:bg-n-slate-4 gap-2 rounded-lg w-auto min-w-[12rem] max-w-[18rem] border border-n-slate-6 shadow-sm group hover:border-n-slate-8 transition-colors"
    >
      <div class="flex-shrink-0 w-8 h-8 flex items-center justify-center bg-n-slate-6 dark:bg-n-slate-5 rounded-md overflow-hidden">
        <img
          v-if="isTypeImage(attachment.resource)"
          class="object-cover w-full h-full"
          :src="attachment.thumb"
        />
        <video
          v-else-if="isTypeVideo(attachment.resource)"
          class="object-cover w-full h-full"
          :src="attachment.thumb"
        />
        <span v-else class="text-xl">
          📄
        </span>
      </div>
      <div class="flex-1 min-w-0 flex flex-col justify-center leading-tight">
        <div
          class="text-sm font-semibold text-n-slate-12 text-ellipsis whitespace-nowrap overflow-hidden"
          :title="fileName(attachment.resource)"
        >
          {{ fileName(attachment.resource) }}
        </div>
        <div class="text-[11px] font-medium text-n-slate-11 uppercase tracking-wider">
          {{ formatFileSize(attachment.resource) }}
        </div>
      </div>
      <div class="flex items-center justify-center ml-1">
        <Button
          ghost
          slate
          xs
          icon="i-lucide-x"
          class="opacity-60 hover:opacity-100"
          @click="onRemoveAttachment(index)"
        />
      </div>
    </div>
  </div>
</template>
