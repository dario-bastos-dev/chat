<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { parsePhoneNumber } from 'libphonenumber-js';

import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { useGroupParticipantConversation } from 'dashboard/composables/useGroupParticipantConversation';

const props = defineProps({
  participant: { type: Object, required: true },
  conversationId: { type: Number, required: true },
});

const { t } = useI18n();
const { openPrivateConversation } = useGroupParticipantConversation();

// The six accent tokens the design system already carries. The colour is picked from the jid so
// a participant keeps it across the whole conversation even after changing their display name.
const PARTICIPANT_COLORS = [
  'text-n-blue-11',
  'text-n-ruby-11',
  'text-n-teal-11',
  'text-n-amber-11',
  'text-n-iris-11',
  'text-n-green-11',
];

// Whoever spoke in a group has to be named on the bubble. A participant reached only by their
// LID has no phone to fall back on, so the identifier itself is the last resort.
const name = computed(() => {
  const { name: participantName, phone, jid } = props.participant;
  if (participantName) return participantName;
  if (!phone) return jid?.split('@')[0] ?? '';

  return parsePhoneNumber(phone)?.formatInternational() ?? phone;
});

const colorClass = computed(() => {
  const key = props.participant.jid || name.value;
  const seed = [...key].reduce((sum, char) => sum + char.charCodeAt(0), 0);

  return PARTICIPANT_COLORS[seed % PARTICIPANT_COLORS.length];
});

const showMenu = ref(false);

const menuItems = computed(() => [
  {
    label: t('CONVERSATION.GROUP_PARTICIPANT_CONVERSATION.OPEN'),
    action: 'open_private_conversation',
    icon: 'i-lucide-message-circle',
  },
]);

const openConversation = () => {
  showMenu.value = false;
  openPrivateConversation({
    conversationId: props.conversationId,
    participantJid: props.participant.jid,
  });
};
</script>

<template>
  <div v-on-clickaway="() => (showMenu = false)" class="relative mb-1">
    <button
      type="button"
      data-participant-name
      aria-haspopup="menu"
      :aria-expanded="showMenu"
      class="max-w-full font-semibold truncate text-start hover:underline"
      :class="colorClass"
      @click="showMenu = !showMenu"
    >
      {{ name }}
    </button>
    <DropdownMenu
      v-if="showMenu"
      :menu-items="menuItems"
      class="mt-1 w-56 top-full ltr:left-0 rtl:right-0"
      @action="openConversation"
    />
  </div>
</template>
