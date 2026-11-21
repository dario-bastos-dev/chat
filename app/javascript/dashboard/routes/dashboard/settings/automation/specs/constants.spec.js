import {
  AUTOMATIONS,
  AUTOMATION_ACTION_TYPES,
  CRM_CONDITION_KEYS,
} from '../constants';

// Input types AutomationActionInput.vue has a branch for. create_deal and
// move_deal_stage are matched by action name, so their own type never reaches
// the generic branches.
const RENDERED_INPUT_TYPES = [
  null,
  'search_select',
  'multi_select',
  'email',
  'url',
  'attachment',
  'team_message',
  'textarea',
  'deal_update',
];
const NAME_RENDERED_ACTIONS = ['create_deal', 'move_deal_stage'];

describe('AUTOMATION_ACTION_TYPES', () => {
  it('only uses input types the action input renders', () => {
    AUTOMATION_ACTION_TYPES.filter(
      ({ key }) => !NAME_RENDERED_ACTIONS.includes(key)
    ).forEach(({ key, inputType }) => {
      expect({ key, inputType }).toEqual({
        key,
        inputType: expect.toBeOneOf(RENDERED_INPUT_TYPES),
      });
    });
  });
});

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
