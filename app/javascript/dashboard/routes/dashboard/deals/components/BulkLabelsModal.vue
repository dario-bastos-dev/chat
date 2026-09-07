<script setup>
import { ref, watch } from 'vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  count: { type: Number, default: 0 },
  labels: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:show', 'apply']);

const selected = ref([]);

// O modal e montado uma vez e reaproveitado: sem isso a segunda abertura viria
// com as etiquetas marcadas da vez anterior.
watch(
  () => props.show,
  isOpen => {
    if (isOpen) selected.value = [];
  }
);

const toggle = title => {
  const index = selected.value.indexOf(title);
  if (index > -1) {
    selected.value.splice(index, 1);
  } else {
    selected.value.push(title);
  }
};

const close = () => emit('update:show', false);
const apply = () => emit('apply', [...selected.value]);
</script>

<template>
  <woot-modal :show="show" @update:show="emit('update:show', $event)">
    <div
      class="p-6 min-w-[400px] flex flex-col gap-4 bg-n-surface-2 text-n-slate-12"
    >
      <woot-modal-header :header-title="$t('CRM.BULK.LABELS_TITLE')" />

      <p class="m-0 text-xs text-n-slate-11">
        {{ $t('CRM.BULK.LABELS_DESCRIPTION', { count }) }}
      </p>

      <div class="flex flex-wrap gap-2 p-1 overflow-y-auto max-h-64">
        <button
          v-for="label in labels"
          :key="label.id"
          type="button"
          class="flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-medium rounded-lg border transition-colors duration-150 cursor-pointer"
          :class="
            selected.includes(label.title)
              ? 'border-n-brand text-n-brand bg-n-brand/10'
              : 'border-n-weak text-n-slate-11 bg-n-alpha-1 hover:bg-n-alpha-2'
          "
          @click="toggle(label.title)"
        >
          <span
            class="w-2 h-2 rounded-full shrink-0"
            :style="{ backgroundColor: label.color }"
          />
          {{ label.title }}
        </button>
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
          class="px-5 py-2 text-xs font-semibold text-white border-0 rounded-xl bg-n-brand hover:brightness-110 transition-all duration-150 cursor-pointer disabled:opacity-50"
          :disabled="selected.length === 0"
          @click="apply"
        >
          {{ $t('CRM.BULK.APPLY') }}
        </button>
      </div>
    </div>
  </woot-modal>
</template>
