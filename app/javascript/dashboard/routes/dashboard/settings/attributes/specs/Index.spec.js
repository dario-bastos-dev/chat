import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import AttributesIndex from '../Index.vue';

const enabledFeatures = ref([]);

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    currentAccount: ref({ id: 1 }),
    isCloudFeatureEnabled: feature => enabledFeatures.value.includes(feature),
  }),
}));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: () => ref([]),
  useStoreGetters: () => ({
    'attributes/getUIFlags': ref({}),
    'attributes/getAttributesByModel': ref(() => []),
  }),
}));
vi.mock('dashboard/modules/command-bar/composables/usePageCommands', () => ({
  usePageCommands: vi.fn(),
  recordCommands: vi.fn(() => []),
}));

const mountPage = () =>
  mount(AttributesIndex, {
    global: {
      plugins: [createI18n({ legacy: false, locale: 'en', messages: {} })],
      stubs: {
        SettingsLayout: {
          template: '<div><slot name="header" /><slot name="body" /></div>',
        },
        BaseSettingsHeader: { template: '<div><slot name="tabs" /></div>' },
        TabBar: {
          name: 'TabBar',
          props: ['tabs', 'initialActiveTab'],
          emits: ['tabChanged'],
          template: '<div />',
        },
        Button: true,
        AttributeListItem: true,
        AddAttribute: true,
        EditAttribute: true,
        'woot-modal': true,
        'woot-confirm-delete-modal': true,
      },
    },
  });

describe('Attributes settings page', () => {
  it('highlights the company tab by its position when the deal tab is hidden', async () => {
    enabledFeatures.value = ['companies'];
    const wrapper = mountPage();
    const tabBar = wrapper.findComponent({ name: 'TabBar' });
    const companyTab = tabBar.props('tabs').find(tab => tab.key === 3);

    await tabBar.vm.$emit('tabChanged', companyTab);

    expect(tabBar.props('tabs').map(tab => tab.key)).toEqual([0, 1, 3]);
    expect(tabBar.props('initialActiveTab')).toBe(2);
  });
});
