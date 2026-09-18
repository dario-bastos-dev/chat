import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import TagGroupParticipants from '../TagGroupParticipants.vue';

const i18n = createI18n({
  legacy: false,
  locale: 'pt_BR',
  messages: {
    pt_BR: {
      CONVERSATION: {
        GROUP_MENTION: {
          EVERYONE: 'Todos',
          EVERYONE_INFO: 'Notificar todos os membros do grupo',
          EVERYONE_HANDLE: 'todos',
        },
      },
    },
  },
});

const mountList = (participants, searchKey = '') =>
  mount(TagGroupParticipants, {
    props: { participants, searchKey },
    global: { plugins: [i18n], stubs: { Avatar: true } },
  });

const names = wrapper => wrapper.findAll('h5').map(node => node.text());

describe('TagGroupParticipants', () => {
  it('puts "everyone" first, then the members', () => {
    const wrapper = mountList([
      { jid: '2704@lid', phone: '5527998999017@s.whatsapp.net', name: 'Dário' },
    ]);

    expect(names(wrapper)).toEqual(['Todos', 'Dário']);
  });

  it('shows the number of a member the account does not know by name', () => {
    const wrapper = mountList([
      { jid: '2704@lid', phone: '5527998999017@s.whatsapp.net', name: null },
    ]);

    expect(names(wrapper)).toContain('+5527998999017');
  });

  it('never shows a bare "+" for a member reached only by lid', () => {
    const wrapper = mountList([
      { jid: '27041265119351@lid', phone: null, name: null },
    ]);

    expect(names(wrapper)).not.toContain('+');
    expect(names(wrapper)).toContain('27041265119351');
    expect(wrapper.text()).not.toMatch(/(^|\s)\+(\s|$)/);
  });

  it('inserts the member handle as plain text when picked', async () => {
    const wrapper = mountList([
      { jid: '2704@lid', phone: '5527998999017@s.whatsapp.net', name: 'Dário' },
    ]);

    await wrapper.findAll('[role="option"]')[1].trigger('click');

    expect(wrapper.emitted('selectParticipant')[0]).toEqual([
      '@5527998999017 ',
    ]);
  });

  it('inserts @todos when "everyone" is picked', async () => {
    const wrapper = mountList([]);

    await wrapper.findAll('[role="option"]')[0].trigger('click');

    expect(wrapper.emitted('selectParticipant')[0]).toEqual(['@todos ']);
  });

  it('filters by name or number', () => {
    const wrapper = mountList(
      [
        { jid: 'a@lid', phone: '5527998999017@s.whatsapp.net', name: 'Dário' },
        { jid: 'b@lid', phone: '5511977776666@s.whatsapp.net', name: 'Bruna' },
      ],
      '1197'
    );

    expect(names(wrapper)).toEqual(['Bruna']);
  });
});
