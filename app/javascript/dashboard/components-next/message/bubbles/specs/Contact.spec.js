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
  }),
}));

const mountBubble = () =>
  mount(ContactBubble, {
    global: {
      plugins: [createI18n({ legacy: false, locale: 'en', messages: {} })],
      stubs: {
        BaseAttachmentBubble: {
          props: ['action'],
          template: '<button @click="action.onClick">save</button>',
        },
      },
    },
  });

describe('Contact bubble', () => {
  beforeEach(() => {
    dispatch.mockReset();
    vi.spyOn(window, 'open').mockImplementation(() => {});
  });

  it('opens the contact that already has the shared number', async () => {
    dispatch.mockResolvedValueOnce([{ id: 42 }]);

    await mountBubble().find('button').trigger('click');
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
});
