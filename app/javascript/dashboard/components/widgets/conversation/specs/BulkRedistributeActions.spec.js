import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import { createStore } from 'vuex';
import { withFullI18n } from 'test-i18n';
import BulkRedistributeActions from '../conversationBulkActions/BulkRedistributeActions.vue';
import BulkActionsAPI from 'dashboard/api/bulkActions';

withFullI18n('pt_BR');

const userPermissions = { value: [] };

vi.mock('dashboard/api/bulkActions', () => ({
  default: { redistributionPreview: vi.fn() },
}));

const previewReturns = agents =>
  BulkActionsAPI.redistributionPreview.mockResolvedValue({ data: { agents } });

vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({
    checkPermissions: required =>
      required.some(permission => userPermissions.value.includes(permission)),
  }),
}));

// O ref criado pelo useToggle real não dispara re-render no jsdom deste projeto.
vi.mock('@vueuse/core', async importOriginal => ({
  ...(await importOriginal()),
  useToggle: initial => {
    const state = ref(initial);
    const toggle = value => {
      state.value = typeof value === 'boolean' ? value : !state.value;
    };
    return [state, toggle];
  },
}));

const mountComponent = () => {
  const store = createStore({
    getters: {
      'teams/getTeams': () => [{ id: 7, name: 'Comercial' }],
      'bulkActions/getUIFlags': () => ({ isUpdating: false }),
    },
  });

  return mount(BulkRedistributeActions, {
    props: { conversationIds: [11, 12, 13] },
    global: { plugins: [store], directives: { tooltip: {} } },
  });
};

const buttonWithText = (wrapper, text) =>
  wrapper.findAll('button').find(button => button.text().includes(text));

const pickTarget = async (wrapper, label) => {
  await wrapper.find('button').trigger('click');
  await buttonWithText(wrapper, label).trigger('click');
  await flushPromises();
};

const confirmButton = wrapper =>
  wrapper.findAll('button').find(button => button.text() === 'Redistribuir');

const confirm = wrapper => confirmButton(wrapper).trigger('click');

describe('BulkRedistributeActions', () => {
  beforeEach(() => {
    previewReturns([
      { id: 1, name: 'Ana' },
      { id: 2, name: 'Bruno' },
    ]);
  });

  it('asks who will receive the selection and says it will be split evenly', async () => {
    const wrapper = mountComponent();

    await pickTarget(wrapper, 'Comercial');

    expect(BulkActionsAPI.redistributionPreview).toHaveBeenCalledWith({
      ids: [11, 12, 13],
      teamId: 7,
    });
    expect(wrapper.text()).toContain('divididas igualmente entre 2 pessoas');
  });

  it('warns by name when only one person can receive the whole selection', async () => {
    previewReturns([{ id: 1, name: 'Ana' }]);
    const wrapper = mountComponent();

    await pickTarget(wrapper, 'Comercial');

    expect(wrapper.text()).toContain('Só Ana pode receber');
    expect(confirmButton(wrapper).attributes('disabled')).toBeUndefined();
  });

  it('blocks the redistribution when nobody can receive it', async () => {
    previewReturns([]);
    const wrapper = mountComponent();

    await pickTarget(wrapper, 'Todos os agentes');

    expect(wrapper.text()).toContain('Ninguém pode receber');
    expect(confirmButton(wrapper).attributes('disabled')).toBeDefined();
  });

  it('sends the chosen team and the deals option together', async () => {
    userPermissions.value = ['administrator'];
    const wrapper = mountComponent();

    await pickTarget(wrapper, 'Comercial');
    expect(wrapper.text()).toContain(
      'Redistribuir 3 conversas entre os membros de Comercial'
    );
    await wrapper.find('input[type="checkbox"]').setValue(true);
    await confirm(wrapper);

    expect(wrapper.emitted('select')).toEqual([
      [{ teamId: 7, includeDeals: true }],
    ]);
  });

  it('shows the deals option to custom roles that can manage every deal', async () => {
    userPermissions.value = ['deal_manage'];
    const wrapper = mountComponent();

    await pickTarget(wrapper, 'Comercial');

    expect(wrapper.find('input[type="checkbox"]').exists()).toBe(true);
  });

  it('hides the deals option from who cannot reassign deals', async () => {
    userPermissions.value = ['conversation_manage', 'deal_own_manage'];
    const wrapper = mountComponent();

    await pickTarget(wrapper, 'Todos os agentes');
    expect(wrapper.find('input[type="checkbox"]').exists()).toBe(false);
    await confirm(wrapper);

    expect(wrapper.emitted('select')).toEqual([
      [{ teamId: null, includeDeals: false }],
    ]);
  });
});
