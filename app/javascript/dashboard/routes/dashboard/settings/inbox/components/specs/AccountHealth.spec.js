import { shallowMount } from '@vue/test-utils';
import ButtonV4 from 'next/button/Button.vue';
import AccountHealth from '../AccountHealth.vue';

const { mockLocale } = vi.hoisted(() => ({ mockLocale: { value: 'en' } }));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
    te: () => false,
    locale: mockLocale,
  }),
}));

describe('AccountHealth', () => {
  const mountComponent = (healthData, props = {}) =>
    shallowMount(AccountHealth, {
      props: { healthData, ...props },
    });

  beforeEach(() => {
    vi.spyOn(window, 'open').mockImplementation(() => {});
  });

  afterEach(() => {
    vi.restoreAllMocks();
    mockLocale.value = 'en';
  });

  it('opens the phone numbers page for the correct WhatsApp Business Account', async () => {
    const wrapper = mountComponent({
      business_account_id: 'waba-456',
      business_portfolio_id: 'business-123',
    });

    await wrapper.findComponent(ButtonV4).trigger('click');

    expect(window.open).toHaveBeenCalledWith(
      'https://business.facebook.com/latest/whatsapp_manager/phone_numbers/?business_id=business-123&asset_id=waba-456',
      '_blank'
    );
  });

  it('opens Meta Business Manager when the WhatsApp Business Account ID is unavailable', async () => {
    const wrapper = mountComponent({
      business_portfolio_id: 'business-123',
    });

    await wrapper.findComponent(ButtonV4).trigger('click');

    expect(window.open).toHaveBeenCalledWith(
      'https://business.facebook.com/',
      '_blank'
    );
  });

  it('formats unknown messaging tiers and account modes without exposing translation keys', () => {
    const wrapper = mountComponent({
      messaging_limit_tier: 'TIER_CUSTOM',
      account_mode: 'CUSTOM_MODE',
    });

    expect(wrapper.text()).toContain('Tier Custom');
    expect(wrapper.text()).toContain('Custom Mode');
    expect(wrapper.text()).not.toContain(
      'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.TIERS.TIER_CUSTOM'
    );
    expect(wrapper.text()).not.toContain(
      'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.MODES.CUSTOM_MODE'
    );
  });

  it('formats the last onboarded time for app locales with an underscore, such as pt_BR', () => {
    mockLocale.value = 'pt_BR';

    const wrapper = mountComponent({
      last_onboarded_time: '2025-06-01T12:00:00+0000',
    });

    expect(wrapper.text()).toContain('1 de jun. de 2025, 12:00');
  });

  it('shows the current error instead of stale health data', () => {
    const wrapper = mountComponent(
      { verified_name: 'Stale Business Name' },
      {
        healthError: {
          type: 'authorization',
          message: 'The connection needs to be refreshed',
        },
        isEmbeddedSignup: true,
      }
    );

    expect(wrapper.text()).toContain('The connection needs to be refreshed');
    expect(wrapper.text()).not.toContain('Stale Business Name');
  });
});
