import { AUTOMATIONS, CRM_CONDITION_KEYS } from '../constants';

describe('CRM_CONDITION_KEYS', () => {
  it('lists the deal conditions the backend evaluates', () => {
    expect(CRM_CONDITION_KEYS).toEqual([
      'has_active_deal',
      'deal_stage_id',
      'deal_labels',
    ]);
  });

  it('is offered as a condition on every event', () => {
    Object.values(AUTOMATIONS).forEach(({ conditions }) => {
      const keys = conditions.map(({ key }) => key);
      expect(keys).toEqual(expect.arrayContaining(CRM_CONDITION_KEYS));
    });
  });
});
