import { shallowMount, createLocalVue } from '@vue/test-utils';
import Vuex from 'vuex';
import ContactDeals from '../ContactDeals.vue';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('ContactDeals', () => {
  let getters;
  let actions;
  let store;
  let wrapper;

  beforeEach(() => {
    getters = {
      'pipelines/getPipelines': () => [{ id: 1, name: 'Default', stages: [] }],
      'agents/getAgents': () => [],
      getCurrentUser: () => ({ id: 1 }),
    };
    actions = {
      'pipelines/get': vi.fn(),
      'agents/get': vi.fn(),
      'deals/create': vi.fn(),
      'deals/win': vi.fn(),
      'deals/lose': vi.fn(),
    };
    store = new Vuex.Store({
      getters,
      actions,
    });
  });

  it('renders empty state when no deals', () => {
    wrapper = shallowMount(ContactDeals, {
      store,
      localVue,
      propsData: {
        contactId: 1,
      },
      mocks: {
        $t: msg => msg,
      },
      stubs: {
        WootButton: true,
        Spinner: true,
        WootModal: true,
        WootModalHeader: true,
        FluentIcon: true,
      },
    });

    expect(wrapper.find('.empty-state').exists()).toBe(true);
  });

  it('renders deals list when there are deals', async () => {
    wrapper = shallowMount(ContactDeals, {
      store,
      localVue,
      propsData: {
        contactId: 1,
      },
      mocks: {
        $t: msg => msg,
      },
      stubs: {
        WootButton: true,
        Spinner: true,
        WootModal: true,
        WootModalHeader: true,
        FluentIcon: true,
      },
    });

    await wrapper.setData({
      deals: [
        {
          id: 1,
          title: 'Deal 1',
          value: 100,
          status: 'open',
          pipeline: { name: 'Pipeline A' },
        },
      ],
      isLoading: false,
    });

    expect(wrapper.find('.deals-list').exists()).toBe(true);
    expect(wrapper.find('.deal-title').text()).toBe('Deal 1');
  });
});
