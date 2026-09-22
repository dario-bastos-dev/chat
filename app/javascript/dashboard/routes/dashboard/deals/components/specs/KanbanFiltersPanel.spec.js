import { mount } from '@vue/test-utils';
import KanbanFiltersPanel from '../KanbanFiltersPanel.vue';

const EMPTY_FILTERS = {
  stageId: null,
  assigneeId: null,
  status: null,
  tag: null,
  minValue: null,
  maxValue: null,
  createdFrom: '',
  createdTo: '',
  customFieldKey: null,
  customFieldValue: '',
};

const mountPanel = (props = {}) =>
  mount(KanbanFiltersPanel, {
    props: {
      modelValue: EMPTY_FILTERS,
      stages: [{ id: 10, name: 'Novos' }],
      agents: [
        { id: 1, name: 'Ana' },
        { id: 2, name: 'Bruno' },
      ],
      labels: [{ id: 5, title: 'vip' }],
      customFields: [
        { key: 'origem', name: 'Origem' },
        { key: 'plano', name: 'Plano' },
      ],
      hasActiveFilters: false,
      ...props,
    },
  });

const optionValues = select =>
  select.findAll('option').map(option => option.element.value);

describe('KanbanFiltersPanel', () => {
  // A primeira opcao ("todos") e `:value="null"`, que nao vira atributo no DOM.
  it('offers "no assignee" and every agent after the "all" option', () => {
    const wrapper = mountPanel();

    expect(
      optionValues(wrapper.find('#deal-filter-assignee')).slice(1)
    ).toEqual(['none', '1', '2']);
  });

  it('emits the whole filter object with only the changed field updated', async () => {
    const wrapper = mountPanel();

    await wrapper.find('#deal-filter-status').setValue('won');

    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual([
      { ...EMPTY_FILTERS, status: 'won' },
    ]);
  });

  it('keeps the value range numeric', async () => {
    const wrapper = mountPanel();

    await wrapper.find('#deal-filter-min-value').setValue('150');

    expect(wrapper.emitted('update:modelValue').at(-1)[0].minValue).toBe(150);
  });

  // O valor digitado pertence ao campo anterior: aplicado ao novo campo, o
  // filtro buscaria um valor que nada tem a ver com ele.
  it('clears the typed value when another custom field is chosen', async () => {
    const wrapper = mountPanel({
      modelValue: {
        ...EMPTY_FILTERS,
        customFieldKey: 'origem',
        customFieldValue: 'instagram',
      },
    });

    await wrapper.find('#deal-filter-custom-field').setValue('plano');

    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual([
      { ...EMPTY_FILTERS, customFieldKey: 'plano', customFieldValue: '' },
    ]);
  });

  it('hides the custom field filter when the account has no deal attributes', () => {
    const wrapper = mountPanel({ customFields: [] });

    expect(wrapper.find('#deal-filter-custom-field').exists()).toBe(false);
  });

  it('limits each date input by the other end of the range', () => {
    const wrapper = mountPanel({
      modelValue: {
        ...EMPTY_FILTERS,
        createdFrom: '2026-09-01',
        createdTo: '2026-09-30',
      },
    });

    expect(wrapper.find('#deal-filter-created-from').attributes('max')).toBe(
      '2026-09-30'
    );
    expect(wrapper.find('#deal-filter-created-to').attributes('min')).toBe(
      '2026-09-01'
    );
  });

  it('shows the clear button only when a filter is active', () => {
    expect(mountPanel().find('[data-test="clear-filters"]').exists()).toBe(
      false
    );
    expect(
      mountPanel({ hasActiveFilters: true })
        .find('[data-test="clear-filters"]')
        .exists()
    ).toBe(true);
  });

  it('asks the board to clear the filters', async () => {
    const wrapper = mountPanel({ hasActiveFilters: true });

    await wrapper.find('[data-test="clear-filters"]').trigger('click');

    expect(wrapper.emitted('clear')).toHaveLength(1);
  });
});
