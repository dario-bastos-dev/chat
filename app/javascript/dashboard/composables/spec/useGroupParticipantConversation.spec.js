import { useGroupParticipantConversation } from '../useGroupParticipantConversation';
import ConversationAPI from 'dashboard/api/inbox/conversation';
import { useAlert } from 'dashboard/composables';

const push = vi.fn();
vi.mock('vue-router', () => ({ useRouter: () => ({ push }) }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/inbox/conversation', () => ({
  default: { openGroupParticipantConversation: vi.fn() },
}));

const open = () =>
  useGroupParticipantConversation().openPrivateConversation({
    conversationId: 7,
    participantJid: 'a@lid',
  });

describe('useGroupParticipantConversation', () => {
  beforeEach(() => vi.clearAllMocks());

  it('takes the agent to the private conversation', async () => {
    ConversationAPI.openGroupParticipantConversation.mockResolvedValue({
      data: { id: 99 },
    });

    await open();

    expect(push).toHaveBeenCalledWith({
      name: 'inbox_conversation',
      params: { conversation_id: 99 },
    });
  });

  it('tells the agent why the server refused to open it', async () => {
    ConversationAPI.openGroupParticipantConversation.mockRejectedValue({
      response: { data: { message: 'Alex is blocked.' } },
    });

    await open();

    expect(useAlert).toHaveBeenCalledWith('Alex is blocked.');
    expect(push).not.toHaveBeenCalled();
  });

  it('falls back to a generic error when the server gives no reason', async () => {
    ConversationAPI.openGroupParticipantConversation.mockRejectedValue(
      new Error('Network Error')
    );

    await open();

    expect(useAlert).toHaveBeenCalledWith(
      'CONVERSATION.GROUP_PARTICIPANT_CONVERSATION.ERROR'
    );
  });
});
