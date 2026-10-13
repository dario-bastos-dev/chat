import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import GroupParticipantName from '../GroupParticipantName.vue';

const openPrivateConversation = vi.fn();
vi.mock('dashboard/composables/useGroupParticipantConversation', () => ({
  useGroupParticipantConversation: () => ({ openPrivateConversation }),
}));

const mountName = participant =>
  mount(GroupParticipantName, {
    props: { participant, conversationId: 42 },
    global: {
      plugins: [createI18n({ legacy: false, locale: 'en', messages: {} })],
      directives: { onClickaway: {} },
    },
  });

const nameButton = wrapper => wrapper.find('[data-participant-name]');

describe('GroupParticipantName', () => {
  it('names the participant who spoke', () => {
    const wrapper = mountName({
      name: 'Alex',
      phone: '+5527998999017',
      jid: '5527998999017@s.whatsapp.net',
    });

    expect(nameButton(wrapper).text()).toBe('Alex');
  });

  it('falls back to the formatted phone number when the participant has no name', () => {
    const wrapper = mountName({
      name: null,
      phone: '+5527998999017',
      jid: '5527998999017@s.whatsapp.net',
    });

    expect(nameButton(wrapper).text()).toBe('+55 27 99899 9017');
  });

  it('falls back to the lid when the participant has neither name nor phone', () => {
    const wrapper = mountName({
      name: null,
      phone: null,
      jid: '27041265119351@lid',
    });

    expect(nameButton(wrapper).text()).toBe('27041265119351');
  });

  it('gives two participants different colours so they can be told apart', () => {
    const colourOf = participant =>
      nameButton(mountName(participant)).classes().join(' ');

    expect(colourOf({ name: 'Alex', phone: null, jid: 'a@lid' })).not.toBe(
      colourOf({ name: 'Bruna', phone: null, jid: 'b@lid' })
    );
  });

  it('opens a private conversation with the participant from the menu', async () => {
    const wrapper = mountName({ name: 'Alex', phone: null, jid: 'a@lid' });

    await nameButton(wrapper).trigger('click');
    expect(nameButton(wrapper).attributes('aria-expanded')).toBe('true');

    const openItem = wrapper
      .findAll('button')
      .find(button =>
        button.text().includes('GROUP_PARTICIPANT_CONVERSATION.OPEN')
      );
    await openItem.trigger('click');

    expect(openPrivateConversation).toHaveBeenCalledWith({
      conversationId: 42,
      participantJid: 'a@lid',
    });
    expect(nameButton(wrapper).attributes('aria-expanded')).toBe('false');
  });
});
