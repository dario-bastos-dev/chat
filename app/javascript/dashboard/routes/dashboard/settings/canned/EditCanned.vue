<script>
/* eslint no-console: 0 */
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';

export default {
  components: {
    NextButton,
    Modal,
    WootMessageEditor,
  },
  props: {
    id: { type: Number, default: null },
    edcontent: { type: String, default: '' },
    edshortCode: { type: String, default: '' },
    edFileUrl: { type: String, default: '' },
    edFileName: { type: String, default: '' },
    edFileContentType: { type: String, default: '' },
    onClose: { type: Function, default: () => {} },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      editCanned: {
        showAlert: false,
        showLoading: false,
      },
      shortCode: this.edshortCode,
      content: this.edcontent,
      file: null,
      filePreview: null,
      existingFileUrl: this.edFileUrl,
      existingFileName: this.edFileName,
      existingFileContentType: this.edFileContentType,
      removeExistingFile: false,
      isRecording: false,
      mediaRecorder: null,
      audioChunks: [],
      recordingTime: 0,
      recordingInterval: null,
      show: true,
    };
  },
  validations: {
    shortCode: {
      required,
      minLength: minLength(2),
    },
    content: {},
  },
  computed: {
    pageTitle() {
      return `${this.$t('CANNED_MGMT.EDIT.TITLE')} - ${this.edshortCode}`;
    },
    isFormValid() {
      return (
        !this.v$.shortCode.$invalid &&
        (this.content.trim().length > 0 ||
          !!this.file ||
          (!!this.existingFileUrl && !this.removeExistingFile))
      );
    },
    formattedRecordingTime() {
      const mins = Math.floor(this.recordingTime / 60);
      const secs = this.recordingTime % 60;
      return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    },
    hasFile() {
      return !!this.file;
    },
    hasExistingFile() {
      return !!this.existingFileUrl && !this.removeExistingFile;
    },
    currentFileName() {
      if (this.file) return this.file.name;
      if (this.hasExistingFile) return this.existingFileName;
      return '';
    },
    isCurrentAudioFile() {
      if (this.file) return this.file.type && this.file.type.startsWith('audio/');
      if (this.hasExistingFile)
        return (
          this.existingFileContentType &&
          this.existingFileContentType.startsWith('audio/')
        );
      return false;
    },
    currentAudioSrc() {
      if (this.file && this.filePreview) return this.filePreview;
      if (this.hasExistingFile && this.isCurrentAudioFile)
        return this.existingFileUrl;
      return '';
    },
  },
  beforeUnmount() {
    this.stopRecording();
    if (this.filePreview) {
      URL.revokeObjectURL(this.filePreview);
    }
  },
  methods: {
    setPageName({ name }) {
      this.v$.content.$touch();
      this.content = name;
    },
    resetForm() {
      this.shortCode = '';
      this.content = '';
      this.file = null;
      this.filePreview = null;
      this.v$.shortCode.$reset();
      this.v$.content.$reset();
    },
    handleFileSelect(event) {
      const selectedFile = event.target.files[0];
      if (!selectedFile) return;
      this.file = selectedFile;
      this.removeExistingFile = true;
      if (this.filePreview) URL.revokeObjectURL(this.filePreview);
      if (selectedFile.type.startsWith('audio/')) {
        this.filePreview = URL.createObjectURL(selectedFile);
      } else {
        this.filePreview = null;
      }
    },
    removeFile() {
      if (this.file) {
        this.file = null;
        if (this.filePreview) {
          URL.revokeObjectURL(this.filePreview);
          this.filePreview = null;
        }
        if (this.existingFileUrl) {
          this.removeExistingFile = false;
        }
      } else if (this.hasExistingFile) {
        this.removeExistingFile = true;
      }
    },
    async startRecording() {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          audio: true,
        });
        this.mediaRecorder = new MediaRecorder(stream);
        this.audioChunks = [];
        this.mediaRecorder.ondataavailable = e => {
          this.audioChunks.push(e.data);
        };
        this.mediaRecorder.onstop = () => {
          const audioBlob = new Blob(this.audioChunks, { type: 'audio/webm' });
          this.file = new File([audioBlob], 'audio_recording.webm', {
            type: 'audio/webm',
          });
          this.removeExistingFile = true;
          if (this.filePreview) URL.revokeObjectURL(this.filePreview);
          this.filePreview = URL.createObjectURL(audioBlob);
          stream.getTracks().forEach(track => track.stop());
        };
        this.mediaRecorder.start();
        this.isRecording = true;
        this.recordingTime = 0;
        this.recordingInterval = setInterval(() => {
          this.recordingTime += 1;
        }, 1000);
      } catch {
        useAlert(this.$t('CANNED_MGMT.ADD.FORM.AUDIO.PERMISSION_ERROR'));
      }
    },
    stopRecording() {
      if (this.mediaRecorder && this.isRecording) {
        this.mediaRecorder.stop();
        this.isRecording = false;
        clearInterval(this.recordingInterval);
      }
    },
    editCannedResponse() {
      this.editCanned.showLoading = true;
      const payload = {
        id: this.id,
        short_code: this.shortCode,
        content: this.content,
      };
      if (this.file) {
        payload.file = this.file;
      } else if (this.removeExistingFile) {
        payload.remove_file = true;
      }
      this.$store
        .dispatch('updateCannedResponse', payload)
        .then(() => {
          this.editCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.EDIT.API.SUCCESS_MESSAGE'));
          this.resetForm();
          setTimeout(() => {
            this.onClose();
          }, 10);
        })
        .catch(error => {
          this.editCanned.showLoading = false;
          const errorMessage =
            error?.message || this.$t('CANNED_MGMT.EDIT.API.ERROR_MESSAGE');
          useAlert(errorMessage);
        });
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="pageTitle" />
      <form class="flex flex-col w-full" @submit.prevent="editCannedResponse()">
        <div class="w-full">
          <label :class="{ error: v$.shortCode.$error }">
            {{ $t('CANNED_MGMT.EDIT.FORM.SHORT_CODE.LABEL') }}
            <input
              v-model="shortCode"
              type="text"
              :placeholder="$t('CANNED_MGMT.EDIT.FORM.SHORT_CODE.PLACEHOLDER')"
              @input="v$.shortCode.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label>
            {{ $t('CANNED_MGMT.EDIT.FORM.CONTENT.LABEL') }}
          </label>
          <div class="editor-wrap">
            <WootMessageEditor
              v-model="content"
              class="message-editor [&>div]:px-1"
              channel-type="Context::Default"
              enable-variables
              :enable-canned-responses="false"
              :placeholder="$t('CANNED_MGMT.EDIT.FORM.CONTENT.PLACEHOLDER')"
              @blur="v$.content.$touch"
            />
          </div>
        </div>

        <!-- File attachment section -->
        <div class="w-full mt-3">
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            {{ $t('CANNED_MGMT.ADD.FORM.FILE.LABEL') }}
          </label>

          <div
            v-if="!hasFile && !hasExistingFile && !isRecording"
            class="flex items-center gap-2"
          >
            <label
              class="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium border rounded-lg cursor-pointer text-n-blue-11 border-n-blue-9 bg-n-blue-3 hover:bg-n-blue-4"
            >
              <span class="i-lucide-paperclip size-4" />
              {{ $t('CANNED_MGMT.ADD.FORM.FILE.ATTACH') }}
              <input type="file" class="hidden" @change="handleFileSelect" />
            </label>
            <button
              type="button"
              class="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium border rounded-lg text-n-ruby-11 border-n-ruby-9 bg-n-ruby-3 hover:bg-n-ruby-4"
              @click="startRecording"
            >
              <span class="i-lucide-mic size-4" />
              {{ $t('CANNED_MGMT.ADD.FORM.AUDIO.RECORD') }}
            </button>
          </div>

          <!-- Recording indicator -->
          <div
            v-if="isRecording"
            class="flex items-center gap-3 p-3 border rounded-lg border-n-ruby-9 bg-n-ruby-3"
          >
            <span class="relative flex size-3">
              <span
                class="absolute inline-flex w-full h-full rounded-full opacity-75 animate-ping bg-n-ruby-9"
              />
              <span
                class="relative inline-flex rounded-full size-3 bg-n-ruby-11"
              />
            </span>
            <span class="text-sm font-medium text-n-ruby-11">
              {{ $t('CANNED_MGMT.ADD.FORM.AUDIO.RECORDING') }}
              {{ formattedRecordingTime }}
            </span>
            <button
              type="button"
              class="inline-flex items-center gap-1 px-3 py-1 ml-auto text-sm font-medium border rounded-md text-n-slate-12 border-n-weak bg-n-solid-2 hover:bg-n-solid-3"
              @click="stopRecording"
            >
              <span class="i-lucide-square size-3" />
              {{ $t('CANNED_MGMT.ADD.FORM.AUDIO.STOP') }}
            </button>
          </div>

          <!-- File preview (new or existing) -->
          <div
            v-if="(hasFile || hasExistingFile) && !isRecording"
            class="flex items-center gap-3 p-3 mt-2 border rounded-lg border-n-weak bg-n-solid-2"
          >
            <span
              :class="isCurrentAudioFile ? 'i-lucide-mic' : 'i-lucide-file'"
              class="flex-shrink-0 size-5 text-n-blue-11"
            />
            <div class="flex-1 min-w-0">
              <p class="m-0 text-sm font-medium truncate text-n-slate-12">
                {{ currentFileName }}
              </p>
              <p v-if="isCurrentAudioFile && currentAudioSrc" class="m-0 mt-1">
                <audio :src="currentAudioSrc" controls class="w-full h-8" />
              </p>
            </div>
            <button
              type="button"
              class="flex-shrink-0 text-n-slate-10 hover:text-n-ruby-11"
              @click="removeFile"
            >
              <span class="i-lucide-x size-4" />
            </button>
          </div>
        </div>

        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="reset"
            :label="$t('CANNED_MGMT.EDIT.CANCEL_BUTTON_TEXT')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="$t('CANNED_MGMT.EDIT.FORM.SUBMIT')"
            :disabled="!isFormValid || editCanned.showLoading"
            :is-loading="editCanned.showLoading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>

<style scoped lang="scss">
:deep(.ProseMirror-menubar) {
  @apply hidden;
}

:deep(.ProseMirror-woot-style) {
  @apply min-h-[12.5rem];

  p {
    @apply text-base;
  }
}
</style>
