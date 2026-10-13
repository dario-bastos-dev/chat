import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ConversationAPI from 'dashboard/api/inbox/conversation';

// Takes the agent to the private conversation with a member of a WhatsApp group. The server
// reuses the member's open conversation when there is one, so opening it twice lands in the same
// place.
export function useGroupParticipantConversation() {
  const router = useRouter();
  const { t } = useI18n();
  const isOpening = ref(false);

  const openPrivateConversation = async ({
    conversationId,
    participantJid,
  }) => {
    if (isOpening.value) return;

    isOpening.value = true;
    try {
      const { data } = await ConversationAPI.openGroupParticipantConversation({
        conversationId,
        participantJid,
      });
      // The account id is carried over from the current route.
      router.push({
        name: 'inbox_conversation',
        params: { conversation_id: data.id },
      });
    } catch (error) {
      // A refusal the agent can act on, such as a blocked contact, comes with its reason.
      useAlert(
        error?.response?.data?.message ||
          t('CONVERSATION.GROUP_PARTICIPANT_CONVERSATION.ERROR')
      );
    } finally {
      isOpening.value = false;
    }
  };

  return { isOpening, openPrivateConversation };
}
