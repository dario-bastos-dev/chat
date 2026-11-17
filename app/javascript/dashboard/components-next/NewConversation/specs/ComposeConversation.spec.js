import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import ComposeConversation from '../ComposeConversation.vue';

const contact = {
  id: 42,
  name: 'Dário Bastos',
  contactInboxes: [
    { sourceId: '5527998999017', inbox: { id: 3, name: 'Suporte' } },
    { sourceId: '5527998999017', inbox: { id: 7, name: 'BIA' } },
  ],
};

const getters = {
  'contacts/getContactById': ref(id => (id === '42' ? contact : {})),
  'inboxes/getInboxes': ref([]),
};
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: key => getters[key] ?? ref({}),
}));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ fetchSignatureFlagFromUISettings: () => false }),
}));

const mountCompose = props =>
  mount(ComposeConversation, {
    props,
    global: {
      plugins: [createI18n({ legacy: false, locale: 'en', messages: {} })],
      stubs: {
        Popover: { template: '<div><slot name="content" /></div>' },
        ComposeNewConversationForm: {
          props: ['targetInbox'],
          template: '<div class="form">{{ targetInbox?.name }}</div>',
        },
      },
    },
  });

describe('ComposeConversation', () => {
  it('starts on the given inbox when the contact can be reached through it', () => {
    const wrapper = mountCompose({ contactId: '42', inboxId: 7 });

    expect(wrapper.find('.form').text()).toBe('BIA');
  });

  it('leaves the inbox for the agent to pick when none is given', () => {
    const wrapper = mountCompose({ contactId: '42' });

    expect(wrapper.find('.form').text()).toBe('');
  });
});
