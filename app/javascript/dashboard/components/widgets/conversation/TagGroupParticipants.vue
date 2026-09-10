<script setup>
import Avatar from 'next/avatar/Avatar.vue';
import { ref, computed, watch, nextTick } from 'vue';
import { useKeyboardNavigableList } from 'dashboard/composables/useKeyboardNavigableList';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  searchKey: { type: String, default: '' },
  participants: { type: Array, default: () => [] },
});

const emit = defineEmits(['selectParticipant']);

const { t } = useI18n();

const listRef = ref(null);
const selectedIndex = ref(0);

// The handle typed into the message is the phone number, which is what the recipient's phone
// renders and what the server matches back against the roster.
const digitsOf = jid => String(jid ?? '').split('@')[0];

const items = computed(() => {
  const search = props.searchKey?.trim().toLowerCase() || '';

  const everyone = {
    id: 'all',
    handle: t('CONVERSATION.GROUP_MENTION.EVERYONE_HANDLE'),
    displayName: t('CONVERSATION.GROUP_MENTION.EVERYONE'),
    displayInfo: t('CONVERSATION.GROUP_MENTION.EVERYONE_INFO'),
  };

  const members = props.participants.map(participant => {
    const phone = digitsOf(participant.phone);
    return {
      id: participant.jid || phone,
      handle: phone || digitsOf(participant.jid),
      displayName: participant.name || `+${phone}`,
      displayInfo: participant.name ? `+${phone}` : '',
    };
  });

  return [everyone, ...members].filter(item =>
    search
      ? `${item.displayName} ${item.handle}`.toLowerCase().includes(search)
      : true
  );
});

const adjustScroll = () => {
  nextTick(() => {
    const selected = listRef.value?.querySelector(
      `#group-mention-item-${selectedIndex.value}`
    );
    selected?.scrollIntoView({ block: 'nearest', behavior: 'auto' });
  });
};

const onSelect = () => {
  const item = items.value[selectedIndex.value];
  if (item) emit('selectParticipant', `@${item.handle} `);
};

useKeyboardNavigableList({
  items,
  onSelect,
  adjustScroll,
  selectedIndex,
});

watch(items, newItems => {
  if (newItems.length < selectedIndex.value + 1) selectedIndex.value = 0;
});

const onHover = index => {
  selectedIndex.value = index;
};

const onItemSelect = index => {
  selectedIndex.value = index;
  onSelect();
};
</script>

<template>
  <div>
    <ul
      v-if="items.length"
      ref="listRef"
      class="vertical dropdown menu mention--box bg-n-solid-1 p-1 rounded-xl text-sm overflow-auto absolute w-full z-20 shadow-md left-0 leading-[1.2] bottom-full max-h-[12.5rem] border border-solid border-n-strong"
      role="listbox"
    >
      <li
        v-for="(item, index) in items"
        :id="`group-mention-item-${index}`"
        :key="item.id"
      >
        <div
          :class="{ 'bg-n-alpha-black2': index === selectedIndex }"
          class="flex items-center px-2 py-1 rounded-md cursor-pointer"
          role="option"
          @click="onItemSelect(index)"
          @mouseover="onHover(index)"
        >
          <div class="ltr:mr-2 rtl:ml-2">
            <Avatar :name="item.displayName" rounded-full />
          </div>
          <div
            class="overflow-hidden flex-1 max-w-full whitespace-nowrap text-ellipsis"
          >
            <h5
              class="overflow-hidden mb-0 text-sm whitespace-nowrap text-n-slate-11 text-ellipsis"
              :class="{ 'text-n-slate-12': index === selectedIndex }"
            >
              {{ item.displayName }}
            </h5>
            <div
              v-if="item.displayInfo"
              class="overflow-hidden text-xs whitespace-nowrap text-ellipsis text-n-slate-10"
              :class="{ 'text-n-slate-11': index === selectedIndex }"
            >
              {{ item.displayInfo }}
            </div>
          </div>
        </div>
      </li>
    </ul>
  </div>
</template>
