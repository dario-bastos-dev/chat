import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ContactDeals from '../ContactDeals.vue';

describe('ContactDeals', () => {
  let store;

  const mountComponent = () =>
    shallowMount(ContactDeals, {
      props: { contactId: 1 },
      global: {
        plugins: [store],
        mocks: { $t: msg => msg },
        stubs: {
          NextButton: true,
          Spinner: true,
          WootModal: true,
          WootModalHeader: true,
          FluentIcon: true,
          DealDrawer: true,
          Avatar: true,
        },
      },
    });

  beforeEach(() => {
    store = createStore({
      getters: {
        'pipelines/getPipelines': () => [{ id: 1, name: 'Default', stages: [] }],
        'agents/getAgents': () => [],
        getCurrentUser: () => ({ id: 1 }),
      },
      actions: {
        'pipelines/get': vi.fn(),
        'agents/get': vi.fn(),
        'deals/create': vi.fn(),
      },
    });
  });

  it('renders empty state when no deals', () => {
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain('CRM.DEALS.SIDEBAR.EMPTY');
  });

  it('renders deals list when there are deals', async () => {
    const wrapper = mountComponent();

    await wrapper.setData({
      deals: [
        {
          id: 1,
          title: 'Deal 1',
          value: 100,
          status: 'open',
          pipeline: { name: 'Pipeline A' },
          stage: { name: 'Stage A' },
        },
      ],
      isLoading: false,
    });

    expect(wrapper.text()).toContain('Deal 1');
    expect(wrapper.text()).toContain('Stage A');
  });
});
