<script setup>
import { ref, computed, watch } from 'vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  count: { type: Number, default: 0 },
  isSubmitting: { type: Boolean, default: false },
});

const emit = defineEmits(['update:show', 'apply']);

const form = ref({ title: '', content: '', scheduledAt: '' });

watch(
  () => props.show,
  isOpen => {
    if (isOpen) form.value = { title: '', content: '', scheduledAt: '' };
  }
);

const isValid = computed(() =>
  Boolean(form.value.title && form.value.content && form.value.scheduledAt)
);

const close = () => emit('update:show', false);
const apply = () => emit('apply', { ...form.value });
</script>

<template>
  <woot-modal :show="show" @update:show="emit('update:show', $event)">
    <div
      class="p-6 min-w-[440px] flex flex-col gap-4 bg-n-surface-2 text-n-slate-12"
    >
      <woot-modal-header :header-title="$t('CRM.BULK.SCHEDULE_TITLE')" />

      <p class="m-0 text-xs leading-5 text-n-slate-11">
        {{ $t('CRM.BULK.SCHEDULE_DESCRIPTION', { count }) }}
      </p>

      <div class="flex flex-col gap-1.5">
        <label
          class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider"
        >
          {{ $t('CRM.BULK.SCHEDULE_NAME') }}
        </label>
        <input
          v-model="form.title"
          type="text"
          class="reset-base block w-full h-9 px-3 text-xs border rounded-lg bg-n-alpha-1 border-n-weak text-n-slate-12 placeholder-n-slate-11 focus:border-n-brand"
          :placeholder="$t('CRM.BULK.SCHEDULE_NAME_PLACEHOLDER')"
        />
      </div>

      <div class="flex flex-col gap-1.5">
        <label
          class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider"
        >
          {{ $t('CRM.BULK.SCHEDULE_CONTENT') }}
        </label>
        <textarea
          v-model="form.content"
          rows="4"
          class="w-full px-3 py-2 text-xs border rounded-lg resize-none bg-n-alpha-1 border-n-weak text-n-slate-12 placeholder-n-slate-11 focus:border-n-brand"
          :placeholder="$t('CRM.BULK.SCHEDULE_CONTENT_PLACEHOLDER')"
        />
      </div>

      <div class="flex flex-col gap-1.5">
        <label
          class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider"
        >
          {{ $t('CRM.BULK.SCHEDULE_AT') }}
        </label>
        <input
          v-model="form.scheduledAt"
          type="datetime-local"
          class="reset-base block w-full h-9 px-3 text-xs border rounded-lg bg-n-alpha-1 border-n-weak text-n-slate-12 focus:border-n-brand"
        />
      </div>

      <div class="flex justify-end gap-3 pt-4 border-t border-n-weak">
        <button
          type="button"
          class="px-4 py-2 text-xs font-semibold border rounded-xl border-n-weak bg-n-alpha-1 text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors duration-150 cursor-pointer"
          @click="close"
        >
          {{ $t('CRM.CANCEL') }}
        </button>
        <button
          type="button"
          class="flex items-center gap-1.5 px-5 py-2 text-xs font-semibold text-white border-0 rounded-xl bg-n-brand hover:brightness-110 transition-all duration-150 cursor-pointer disabled:opacity-50"
          :disabled="!isValid || isSubmitting"
          @click="apply"
        >
          <woot-spinner v-if="isSubmitting" size="tiny" />
          {{ $t('CRM.BULK.SCHEDULE_CONFIRM') }}
        </button>
      </div>
    </div>
  </woot-modal>
</template>
