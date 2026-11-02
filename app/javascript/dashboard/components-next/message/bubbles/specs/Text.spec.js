import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import TextBubble from '../Text/Index.vue';

const contentAttributes = ref({});
vi.mock('../../provider.js', () => ({
  useMessageContext: () => ({
    content: ref('olha isso https://example.com/promo'),
    attachments: ref([]),
    contentAttributes,
    messageType: ref(1),
  }),
}));
vi.mock('dashboard/composables/useTranslations', () => ({
  useTranslations: () => ({
    hasTranslations: ref(false),
    translationContent: ref(''),
  }),
}));

const mountBubble = () =>
  mount(TextBubble, {
    global: {
      plugins: [createI18n({ legacy: false, locale: 'en', messages: {} })],
      stubs: {
        BaseBubble: { template: '<div><slot /></div>' },
        FormattedContent: {
          props: ['content'],
          template: '<p>{{ content }}</p>',
        },
        TranslationToggle: true,
        AttachmentChips: true,
        Icon: true,
      },
    },
  });

describe('Text bubble', () => {
  it('shows a link as plain text, since that is all the contact receives', () => {
    contentAttributes.value = {
      linkPreview: {
        url: 'https://example.com/promo',
        title: 'Promoção',
        description: 'Só hoje',
        imageUrl: 'https://example.com/promo.jpg',
      },
    };

    const wrapper = mountBubble();

    expect(wrapper.text()).toContain('olha isso https://example.com/promo');
    expect(wrapper.find('img').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Promoção');
  });
});
