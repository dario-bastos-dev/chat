<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { parsePhoneNumber } from 'libphonenumber-js';

import Button from 'dashboard/components-next/button/Button.vue';
import { useGroupParticipantConversation } from 'dashboard/composables/useGroupParticipantConversation';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  participants: { type: Array, default: () => [] },
  businessPhone: { type: String, default: '' },
});

const { t } = useI18n();
const { isOpening, openPrivateConversation } =
  useGroupParticipantConversation();

const digitsOf = value => value?.split('@')[0].replace('+', '') ?? '';

const formatPhone = digits =>
  parsePhoneNumber(`+${digits}`)?.formatInternational() ?? `+${digits}`;

// The roster lists the business number too, and there is no private conversation to have with it.
const members = computed(() => {
  const businessDigits = digitsOf(props.businessPhone);

  return props.participants
    .filter(participant => {
      const phone = digitsOf(participant.phone);
      return !phone || phone !== businessDigits;
    })
    .map(participant => {
      const phone = digitsOf(participant.phone);
      const formattedPhone = phone ? formatPhone(phone) : '';
      return {
        jid: participant.jid,
        admin: participant.admin,
        name: participant.name || formattedPhone || digitsOf(participant.jid),
        detail: participant.name ? formattedPhone : '',
      };
    });
});
</script>

<template>
  <p v-if="!members.length" class="px-2 text-sm text-n-slate-11">
    {{ t('CONVERSATION.GROUP_PARTICIPANT_CONVERSATION.EMPTY') }}
  </p>
  <ul v-else class="flex flex-col gap-1 overflow-y-auto max-h-80">
    <li
      v-for="member in members"
      :key="member.jid"
      class="flex items-center gap-2 px-2 py-1 rounded-lg hover:bg-n-alpha-1"
    >
      <div class="flex flex-col flex-1 min-w-0">
        <span class="text-sm truncate text-n-slate-12">
          {{ member.name }}
          <span
            v-if="member.admin"
            class="px-1 rounded ms-1 text-xxs bg-n-alpha-2 text-n-slate-11"
          >
            {{ t('CONVERSATION.GROUP_PARTICIPANT_CONVERSATION.ADMIN') }}
          </span>
        </span>
        <span v-if="member.detail" class="text-xs truncate text-n-slate-11">
          {{ member.detail }}
        </span>
      </div>
      <Button
        v-tooltip.left="
          t('CONVERSATION.GROUP_PARTICIPANT_CONVERSATION.OPEN_WITH', {
            name: member.name,
          })
        "
        icon="i-lucide-message-circle"
        variant="ghost"
        color="slate"
        size="xs"
        :disabled="isOpening"
        @click="
          openPrivateConversation({
            conversationId,
            participantJid: member.jid,
          })
        "
      />
    </li>
  </ul>
</template>
