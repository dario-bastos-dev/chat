<script setup>
import { computed, ref } from 'vue';
import { OnClickOutside } from '@vueuse/components';
import { useElementSize, useToggle } from '@vueuse/core';
import { useDropdownPosition } from 'dashboard/composables/useDropdownPosition';

import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import EmojiIcon from 'dashboard/components-next/emoji-icon-picker/EmojiIcon.vue';
import MultiselectDropdownItems from 'shared/components/ui/MultiselectDropdownItems.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

const props = defineProps({
  options: {
    type: Array,
    default: () => [],
  },
  selectedItem: {
    type: Object,
    default: () => ({}),
  },
  hasThumbnail: {
    type: Boolean,
    default: true,
  },
  multiselectorTitle: {
    type: String,
    default: '',
  },
  multiselectorPlaceholder: {
    type: String,
    default: 'None',
  },
  noSearchResult: {
    type: String,
    default: 'No results found',
  },
  inputPlaceholder: {
    type: String,
    default: 'Search',
  },
  showEmojiIcon: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['select']);
const [showSearchDropdown, toggleDropdown] = useToggle(false);

// The panel is teleported to body so it isn't clipped by scrollable ancestors
const triggerRef = ref(null);
const dropdownRef = ref(null);
const { width: triggerWidth } = useElementSize(triggerRef);
const { fixedPosition } = useDropdownPosition(
  triggerRef,
  dropdownRef,
  showSearchDropdown,
  { align: 'start' }
);
const dropdownStyle = computed(() => ({
  ...fixedPosition.value.style,
  width: `${triggerWidth.value}px`,
}));

const onCloseDropdown = () => toggleDropdown(false);
const onClickSelectItem = value => {
  emit('select', value);
  onCloseDropdown();
};

const hasValue = computed(() => {
  if (props.selectedItem && props.selectedItem.id) {
    return true;
  }
  return false;
});

const hasIcon = computed(() => {
  return props.selectedItem?.icon || false;
});

const isAgentBot = computed(
  () => props.selectedItem?.assignee_type === 'AgentBot'
);

const selectedItemName = computed(() =>
  !props.selectedItem?.name && isAgentBot.value ? '-' : props.selectedItem?.name
);

const selectedThumbnail = computed(
  () => props.selectedItem?.thumbnail || props.selectedItem?.avatar_url
);
</script>

<template>
  <OnClickOutside
    :options="{ ignore: ['[data-multiselect-dropdown-panel]'] }"
    @trigger="onCloseDropdown"
  >
    <div ref="triggerRef" class="w-full mb-2" @keyup.esc="onCloseDropdown">
      <Button
        slate
        outline
        trailing-icon
        :icon="
          showSearchDropdown ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'
        "
        class="w-full !px-2"
        @click="
          () => toggleDropdown() // ensure that the event is not passed to the button
        "
      >
        <div class="flex items-center justify-between w-full min-w-0">
          <h4 v-if="!hasValue" class="text-sm text-ellipsis text-n-slate-12">
            {{ multiselectorPlaceholder }}
          </h4>
          <h4
            v-else
            class="items-center overflow-hidden text-sm leading-tight whitespace-nowrap text-ellipsis text-n-slate-12"
            :title="selectedItemName"
          >
            {{ selectedItemName }}
          </h4>
        </div>
        <Avatar
          v-if="hasValue && hasThumbnail && (isAgentBot || !hasIcon)"
          :src="selectedThumbnail"
          :status="selectedItem.availability_status"
          :name="selectedItemName"
          :icon-name="isAgentBot ? 'i-lucide-bot' : undefined"
          :size="24"
          hide-offline-status
          rounded-full
        >
          <template v-if="isAgentBot && selectedThumbnail" #badge>
            <div
              class="absolute z-20 flex items-center justify-center rounded-full outline outline-1 outline-n-weak bg-n-solid-1 -bottom-0.5 ltr:-right-0.5 rtl:-left-0.5 size-3.5"
            >
              <Icon icon="i-lucide-bot" class="text-n-slate-11 size-2.5" />
            </div>
          </template>
        </Avatar>
        <div
          v-else-if="hasValue && hasIcon && showEmojiIcon"
          class="flex items-center justify-center flex-shrink-0 text-sm rounded-full size-6 outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <EmojiIcon
            :value="selectedItem.icon"
            :color="selectedItem.icon_color"
            class="size-3.5 !text-sm"
          />
        </div>
        <Icon
          v-else-if="hasValue && hasIcon"
          :icon="selectedItem.icon"
          class="size-5 text-n-slate-11"
        />
      </Button>
      <TeleportWithDirection v-if="showSearchDropdown" to="body">
        <div
          ref="dropdownRef"
          data-multiselect-dropdown-panel
          :class="fixedPosition.class"
          :style="dropdownStyle"
          class="box-border overflow-y-auto border rounded-lg bg-n-alpha-3 backdrop-blur-[100px] shadow-lg border-n-strong dark:border-n-strong p-2"
          @keyup.esc="onCloseDropdown"
        >
          <div class="flex items-center justify-between mb-1">
            <h4
              class="m-0 overflow-hidden text-sm text-n-slate-11 whitespace-nowrap text-ellipsis"
            >
              {{ multiselectorTitle }}
            </h4>
            <Button ghost slate xs icon="i-lucide-x" @click="onCloseDropdown" />
          </div>
          <MultiselectDropdownItems
            :options="options"
            :selected-items="[selectedItem]"
            :has-thumbnail="hasThumbnail"
            :input-placeholder="inputPlaceholder"
            :no-search-result="noSearchResult"
            :show-emoji-icon="showEmojiIcon"
            @select="onClickSelectItem"
          />
        </div>
      </TeleportWithDirection>
    </div>
  </OnClickOutside>
</template>
