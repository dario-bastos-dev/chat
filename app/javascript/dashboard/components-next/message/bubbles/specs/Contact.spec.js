import { ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import ContactBubble from '../Contact.vue';

const dispatch = vi.fn();
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('../../provider.js', () => ({
  useMessageContext: () => ({
    attachments: ref([
      {
        fallbackTitle: '+5527998999017',
        meta: { firstName: 'Dário', lastName: 'Bastos' },
      },
    ]),
    inboxId: ref(7),
  }),
}));

const openCompose = vi.fn();

const mountBubble = () =>
  mount(ContactBubble, {
    global: {
      plugins: [createI18n({ legacy: false, locale: 'en', messages: {} })],
      stubs: {
        BaseAttachmentBubble: {
          props: ['action'],
          template:
            '<div><button class="save" @click="action.onClick">save</button><slot name="actions" /></div>',
        },
        ComposeConversation: {
          props: ['contactId', 'inboxId'],
          methods: { open: openCompose },
          template:
            '<div class="compose" :data-contact-id="contactId" :data-inbox-id="inboxId"><slot name="trigger" /></div>',
        },
      },
    },
  });

describe('Contact bubble', () => {
  beforeEach(() => {
    dispatch.mockReset();
    openCompose.mockReset();
    vi.spyOn(window, 'open').mockImplementation(() => {});
  });

  it('opens the contact that already has the shared number', async () => {
    dispatch.mockResolvedValueOnce([{ id: 42 }]);

    await mountBubble().find('button.save').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledTimes(1);
    expect(dispatch).toHaveBeenCalledWith('contacts/filter', {
      queryPayload: {
        payload: [
          expect.objectContaining({
            attribute_key: 'phone_number',
            values: ['5527998999017'],
          }),
        ],
      },
      resetState: false,
    });
    expect(window.open).toHaveBeenCalledWith(
      expect.stringMatching(/\/contacts\/42$/),
      '_blank'
    );
  });

  it('opens a new conversation with the shared contact in the current inbox', async () => {
    dispatch.mockResolvedValueOnce([{ id: 42 }]);

    const wrapper = mountBubble();
    await wrapper.find('.compose button').trigger('click');
    await flushPromises();

    expect(dispatch.mock.calls.map(([action]) => action)).toEqual([
      'contacts/filter',
      'contacts/show',
      'contacts/fetchContactableInbox',
    ]);
    expect(dispatch).toHaveBeenCalledWith('contacts/show', { id: 42 });
    expect(dispatch).toHaveBeenCalledWith('contacts/fetchContactableInbox', 42);

    const compose = wrapper.find('.compose');
    expect(compose.attributes('data-contact-id')).toBe('42');
    expect(compose.attributes('data-inbox-id')).toBe('7');
    expect(openCompose).toHaveBeenCalledTimes(1);
    expect(window.open).not.toHaveBeenCalled();
  });

  it('creates the contact first when nobody has the shared number', async () => {
    dispatch.mockResolvedValueOnce([]).mockResolvedValueOnce({ id: 99 });

    const wrapper = mountBubble();
    await wrapper.find('.compose button').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('contacts/create', {
      name: 'Dário Bastos',
      phone_number: '+5527998999017',
    });
    expect(wrapper.find('.compose').attributes('data-contact-id')).toBe('99');
    expect(openCompose).toHaveBeenCalledTimes(1);
  });
});
