<script setup>
import { useTemplateRef, computed, ref } from 'vue';
import { useI18n, I18nT } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import { useMapGetter } from 'dashboard/composables/store';
import { usePolicy } from 'dashboard/composables/usePolicy';

import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  conversationCount: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['select']);

const { t } = useI18n();
const { checkPermissions } = usePolicy();
const containerRef = useTemplateRef('containerRef');
const [showDropdown, toggleDropdown] = useToggle(false);
const selectedTarget = ref(null);
const includeDeals = ref(false);

const teams = useMapGetter('teams/getTeams');
const bulkActionsUiFlags = useMapGetter('bulkActions/getUIFlags');
const isUpdating = computed(() => bulkActionsUiFlags.value.isUpdating);

// Espelha o DealPolicy#assign?: o backend recusa a acao inteira para quem nao pode reatribuir negocios.
const canTransferDeals = computed(() =>
  checkPermissions(['administrator', 'deal_manage'])
);

const menuItems = computed(() => [
  {
    action: 'select',
    value: 'all',
    label: t('BULK_ACTION.REDISTRIBUTE.ALL_AGENTS'),
    isSelected: selectedTarget.value?.id === null,
  },
  ...teams.value.map(team => ({
    action: 'select',
    value: team.id,
    label: team.name,
    isSelected: selectedTarget.value?.id === team.id,
  })),
]);

const reset = () => {
  selectedTarget.value = null;
  includeDeals.value = false;
};

const handleSelect = item => {
  if (item.value === 'all') {
    selectedTarget.value = { id: null };
    return;
  }
  const team = teams.value.find(({ id }) => id === item.value);
  selectedTarget.value = { id: team.id, name: team.name };
};

const handleConfirm = () => {
  if (isUpdating.value) return;
  emit('select', {
    teamId: selectedTarget.value.id,
    includeDeals: canTransferDeals.value && includeDeals.value,
  });
  reset();
  toggleDropdown(false);
};

const handleDismiss = () => {
  reset();
  toggleDropdown(false);
};
</script>

<template>
  <div ref="containerRef" class="relative">
    <Button
      v-tooltip="$t('BULK_ACTION.REDISTRIBUTE.TOOLTIP')"
      icon="i-lucide-shuffle"
      slate
      xs
      ghost
      :class="{ 'bg-n-alpha-2': showDropdown }"
      @click="toggleDropdown()"
    />
    <Transition
      enter-active-class="transition-all duration-150 ease-out origin-bottom"
      enter-from-class="opacity-0 scale-95"
      enter-to-class="opacity-100 scale-100"
      leave-active-class="transition-all duration-100 ease-in origin-bottom"
      leave-from-class="opacity-100 scale-100"
      leave-to-class="opacity-0 scale-95"
    >
      <DropdownMenu
        v-if="showDropdown"
        v-on-click-outside="[handleDismiss, { ignore: [containerRef] }]"
        :menu-items="menuItems"
        show-search
        :search-placeholder="t('BULK_ACTION.SEARCH_INPUT_PLACEHOLDER')"
        class="ltr:-right-2 rtl:-left-2 bottom-8 w-72 max-h-96"
        @action="handleSelect"
      >
        <template v-if="selectedTarget" #footer>
          <div
            class="pt-2 pb-2 px-2 border-t border-n-weak sticky bottom-0 rounded-b-md z-20 bg-n-alpha-3 backdrop-blur-[4px]"
          >
            <div class="flex flex-col gap-2">
              <I18nT
                v-if="selectedTarget.id"
                keypath="BULK_ACTION.REDISTRIBUTE.TEAM_CONFIRMATION_LABEL"
                tag="p"
                class="text-xs text-n-slate-11 px-1 mb-0"
                :plural="props.conversationCount"
              >
                <template #n>
                  <strong class="text-n-slate-12">
                    {{ props.conversationCount }}
                  </strong>
                </template>
                <template #teamName>
                  <strong class="text-n-slate-12">
                    {{ selectedTarget.name }}
                  </strong>
                </template>
              </I18nT>
              <I18nT
                v-else
                keypath="BULK_ACTION.REDISTRIBUTE.ALL_CONFIRMATION_LABEL"
                tag="p"
                class="text-xs text-n-slate-11 px-1 mb-0"
                :plural="props.conversationCount"
              >
                <template #n>
                  <strong class="text-n-slate-12">
                    {{ props.conversationCount }}
                  </strong>
                </template>
              </I18nT>
              <label
                v-if="canTransferDeals"
                class="flex items-start gap-2 px-1 cursor-pointer"
              >
                <Checkbox v-model="includeDeals" class="flex-shrink-0 mt-0.5" />
                <span class="flex flex-col">
                  <span class="text-xs text-n-slate-12">
                    {{ $t('BULK_ACTION.REDISTRIBUTE.INCLUDE_DEALS') }}
                  </span>
                  <span class="text-xs text-n-slate-11">
                    {{ $t('BULK_ACTION.REDISTRIBUTE.INCLUDE_DEALS_HELP') }}
                  </span>
                </span>
              </label>
              <div class="flex gap-2">
                <Button
                  sm
                  faded
                  slate
                  class="flex-1"
                  :label="t('BULK_ACTION.CANCEL')"
                  @click="reset"
                />
                <Button
                  sm
                  class="flex-1"
                  :label="t('BULK_ACTION.REDISTRIBUTE.CONFIRM')"
                  :disabled="isUpdating"
                  :is-loading="isUpdating"
                  @click="handleConfirm"
                />
              </div>
            </div>
          </div>
        </template>
      </DropdownMenu>
    </Transition>
  </div>
</template>
