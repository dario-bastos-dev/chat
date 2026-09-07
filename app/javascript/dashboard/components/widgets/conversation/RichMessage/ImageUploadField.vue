<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store.js';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import { checkFileSizeLimit } from 'shared/helpers/FileHelper';

import NextButton from 'dashboard/components-next/button/Button.vue';

// WhatsApp downloads the header image itself before delivering the message, so a heavy file
// delays the send. Four megabytes is the same ceiling the rest of the dashboard uses.
const MAX_FILE_SIZE_MB = 4;

// The model holds the URL of the uploaded file, which is what the send endpoints expect.
const modelValue = defineModel({ type: String, default: '' });

const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');

const fileInput = ref(null);
const fileName = ref('');
const isUploading = ref(false);

const openPicker = () => fileInput.value?.click();

const onFileChange = async event => {
  const file = event.target.files?.[0];
  // The input keeps the last selection, so clearing it allows picking the same file again after
  // a removal.
  event.target.value = '';
  if (!file) return;

  if (!checkFileSizeLimit(file, MAX_FILE_SIZE_MB)) {
    useAlert(
      t('CONVERSATION.RICH_MESSAGE.IMAGE.SIZE_ERROR', { size: MAX_FILE_SIZE_MB })
    );
    return;
  }

  isUploading.value = true;
  try {
    const { fileUrl } = await uploadFile(file, accountId.value);
    modelValue.value = fileUrl;
    fileName.value = file.name;
  } catch {
    useAlert(t('CONVERSATION.RICH_MESSAGE.IMAGE.UPLOAD_ERROR'));
  } finally {
    isUploading.value = false;
  }
};

const removeImage = () => {
  modelValue.value = '';
  fileName.value = '';
};
</script>

<template>
  <div class="flex items-center gap-3">
    <input
      ref="fileInput"
      type="file"
      accept="image/*"
      class="hidden"
      @change="onFileChange"
    />

    <img
      v-if="modelValue"
      :src="modelValue"
      alt=""
      class="object-cover rounded-md size-12 shrink-0"
    />

    <NextButton
      faded
      slate
      sm
      icon="i-lucide-image-up"
      :is-loading="isUploading"
      :disabled="isUploading"
      :label="
        modelValue
          ? $t('CONVERSATION.RICH_MESSAGE.IMAGE.REPLACE')
          : $t('CONVERSATION.RICH_MESSAGE.IMAGE.CHOOSE')
      "
      @click="openPicker"
    />

    <span
      v-if="fileName"
      class="text-sm truncate text-n-slate-11"
      :title="fileName"
    >
      {{ fileName }}
    </span>

    <NextButton
      v-if="modelValue"
      ghost
      slate
      sm
      icon="i-lucide-trash-2"
      @click="removeImage"
    />
  </div>
</template>
