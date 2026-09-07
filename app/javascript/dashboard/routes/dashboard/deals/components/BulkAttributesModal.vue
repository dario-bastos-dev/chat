<script setup>
import { ref, computed, watch } from 'vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  count: { type: Number, default: 0 },
  attributes: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:show', 'apply']);

const NUMERIC_TYPES = ['number', 'currency', 'percent'];

const values = ref({});

watch(
  () => props.show,
  isOpen => {
    if (isOpen) values.value = {};
  }
);

const inputTypeFor = type => {
  if (NUMERIC_TYPES.includes(type)) return 'number';
  if (type === 'date') return 'date';
  return 'text';
};

// Campo em branco significa "nao alterar", entao so o que foi preenchido vira
// payload. Atributo numerico e gravado como numero: o v-model de um input
// dinamico entrega string, e o filtro por campo personalizado compara valor.
const filled = computed(() =>
  props.attributes
    .filter(attribute => {
      const value = values.value[attribute.key];
      return value !== '' && value !== null && value !== undefined;
    })
    .map(attribute => {
      const value = values.value[attribute.key];
      return [
        attribute.key,
        NUMERIC_TYPES.includes(attribute.type) ? Number(value) : value,
      ];
    })
);

const close = () => emit('update:show', false);
const apply = () => emit('apply', Object.fromEntries(filled.value));
</script>

<template>
  <woot-modal :show="show" @update:show="emit('update:show', $event)">
    <div
      class="p-6 min-w-[400px] flex flex-col gap-4 bg-n-surface-2 text-n-slate-12"
    >
      <woot-modal-header :header-title="$t('CRM.BULK.ATTRIBUTES_TITLE')" />

      <p class="m-0 text-xs text-n-slate-11">
        {{ $t('CRM.BULK.ATTRIBUTES_DESCRIPTION', { count }) }}
      </p>

      <div class="flex flex-col gap-3 p-1 overflow-y-auto max-h-72">
        <div
          v-for="attribute in attributes"
          :key="attribute.key"
          class="flex flex-col gap-1.5"
        >
          <label
            class="text-[10px] font-bold text-n-slate-11 uppercase tracking-wider"
          >
            {{ attribute.name }}
          </label>
          <select
            v-if="attribute.type === 'list'"
            v-model="values[attribute.key]"
            class="w-full h-8 px-3 py-1.5 text-xs border rounded-lg bg-n-alpha-1 border-n-weak text-n-slate-12 focus:border-n-brand"
          >
            <option value="">{{ $t('CRM.BULK.ATTRIBUTE_KEEP') }}</option>
            <option v-for="value in attribute.values" :key="value" :value="value">
              {{ value }}
            </option>
          </select>
          <input
            v-else
            v-model="values[attribute.key]"
            :type="inputTypeFor(attribute.type)"
            class="reset-base block w-full h-8 px-3 py-1.5 text-xs border rounded-lg bg-n-alpha-1 border-n-weak text-n-slate-12 placeholder-n-slate-11 focus:border-n-brand"
            :placeholder="$t('CRM.BULK.ATTRIBUTE_KEEP')"
          />
        </div>
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
          :disabled="filled.length === 0"
          @click="apply"
        >
          {{ $t('CRM.BULK.APPLY') }}
        </button>
      </div>
    </div>
  </woot-modal>
</template>
