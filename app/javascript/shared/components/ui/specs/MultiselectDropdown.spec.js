import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import MultiselectDropdown from '../MultiselectDropdown.vue';

describe('MultiselectDropdown', () => {
  it('leaves nothing in the body while the panel is closed', () => {
    const store = createStore({
      getters: { 'accounts/isRTL': () => false },
    });
    const wrapper = mount(MultiselectDropdown, {
      props: { options: [{ id: 1, name: 'Dinheiro' }], hasThumbnail: false },
      global: { plugins: [store] },
      attachTo: document.body,
    });

    expect(document.body.querySelector('[dir]')).toBeNull();
    expect(
      document.body.querySelector('[data-multiselect-dropdown-panel]')
    ).toBeNull();

    wrapper.unmount();
  });
});
