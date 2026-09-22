<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const props = defineProps({
  modelValue: { type: String, required: true },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const [showDropdown, toggleDropdown] = useToggle();

// Espelha Deal::SORT_ORDERS no backend.
const sortOptions = computed(() => [
  { label: t('CRM.SORT.CREATED_AT_DESC'), value: 'created_at_desc' },
  { label: t('CRM.SORT.CREATED_AT_ASC'), value: 'created_at_asc' },
]);

const activeLabel = computed(
  () =>
    sortOptions.value.find(option => option.value === props.modelValue)
      ?.label || ''
);
</script>

<template>
  <div class="relative flex">
    <button
      v-tooltip.bottom="$t('CRM.SORT.TOOLTIP')"
      type="button"
      class="flex items-center justify-center w-9 h-9 border rounded-lg shrink-0 bg-n-alpha-1 border-n-weak text-n-slate-11 hover:text-n-brand hover:bg-n-alpha-2 transition-colors duration-150 cursor-pointer"
      :class="{ 'text-n-brand border-n-brand bg-n-brand/10': showDropdown }"
      :aria-label="$t('CRM.SORT.TOOLTIP')"
      @click="toggleDropdown()"
    >
      <span class="i-lucide-arrow-up-down size-4" />
    </button>
    <div
      v-if="showDropdown"
      v-on-click-outside="() => toggleDropdown(false)"
      class="absolute z-50 p-4 mt-2 border ltr:right-0 rtl:left-0 top-full w-80 rounded-xl bg-n-alpha-3 backdrop-blur-[100px] border-n-weak"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm truncate text-n-slate-12">
          {{ $t('CRM.SORT.ORDER_BY') }}
        </span>
        <SelectMenu
          :model-value="modelValue"
          :options="sortOptions"
          :label="activeLabel"
          sub-menu-position="left"
          @update:model-value="emit('update:modelValue', $event)"
        />
      </div>
    </div>
  </div>
</template>
