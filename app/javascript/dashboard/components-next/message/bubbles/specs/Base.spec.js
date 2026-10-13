import { defineComponent, ref } from 'vue';
import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import BaseBubble from '../Base.vue';
import { provideMessageContext } from '../../provider.js';
import { MESSAGE_VARIANTS, ORIENTATION } from '../../constants';

const useGroupParticipantConversation = vi.fn(() => ({
  openPrivateConversation: vi.fn(),
}));
vi.mock('dashboard/composables/useGroupParticipantConversation', () => ({
  useGroupParticipantConversation: () => useGroupParticipantConversation(),
}));

const mountBubble = (contentAttributes = {}) => {
  const TestHost = defineComponent({
    components: { BaseBubble },
    setup() {
      provideMessageContext({
        variant: ref(MESSAGE_VARIANTS.USER),
        orientation: ref(ORIENTATION.LEFT),
        inReplyTo: ref(null),
        shouldGroupWithNext: ref(false),
        id: ref(1),
        conversationId: ref(42),
        sender: ref({ name: 'WhatsApp group (223333)' }),
        senderType: ref('contact'),
        contentAttributes: ref(contentAttributes),
      });
    },
    template: '<BaseBubble><span>corpo da mensagem</span></BaseBubble>',
  });

  const i18n = createI18n({
    legacy: false,
    locale: 'en',
    messages: { en: {} },
  });

  return mount(TestHost, {
    global: {
      plugins: [i18n],
      stubs: { MessageMeta: true, CaptainGenerationDetails: true },
      directives: { onClickaway: {} },
    },
  });
};

describe('Base bubble', () => {
  it('names the participant who spoke inside a group', () => {
    const wrapper = mountBubble({
      groupParticipant: {
        name: 'Alex',
        phone: '+5527998999017',
        jid: '5527998999017@s.whatsapp.net',
      },
    });

    expect(wrapper.text()).toContain('Alex');
  });

  it('says nothing extra on a one to one conversation', () => {
    const wrapper = mountBubble();

    expect(wrapper.text()).toBe('corpo da mensagem');
  });

  it('leaves the private conversation action out of a one to one bubble', () => {
    mountBubble();

    expect(useGroupParticipantConversation).not.toHaveBeenCalled();
  });
});
