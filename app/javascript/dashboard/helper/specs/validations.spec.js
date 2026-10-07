import { describe, it, expect } from 'vitest';
import {
  validateAutomation,
  getSendMessageButtonError,
  validateSingleFilter,
  VALUE_MUST_BE_BETWEEN_1_AND_998,
} from '../validations';

describe('validateSingleFilter', () => {
  it.each(['days_before', 'hours_before'])(
    'requires %s values between 1 and 998',
    filterOperator => {
      const validate = values =>
        validateSingleFilter({
          attribute_key: 'last_activity_at',
          filter_operator: filterOperator,
          values,
        });

      expect(validate('0')).toBe(VALUE_MUST_BE_BETWEEN_1_AND_998);
      expect(validate('999')).toBe(VALUE_MUST_BE_BETWEEN_1_AND_998);
      expect(validate('24')).toBeNull();
    }
  );
});

describe('validateAutomation', () => {
  it('should return no errors for a valid automation', () => {
    const validAutomation = {
      name: 'Test Automation',
      description: 'A test automation',
      event_name: 'message_created',
      conditions: [
        {
          attribute_key: 'content',
          filter_operator: 'contains',
          values: 'hello',
        },
      ],
      actions: [
        { action_name: 'send_message', action_params: ['Hello there!'] },
      ],
    };
    const errors = validateAutomation(validAutomation);
    expect(errors).toEqual({});
  });

  it('should return errors for missing basic fields', () => {
    const invalidAutomation = {
      name: '',
      description: '',
      event_name: '',
      conditions: [],
      actions: [],
    };
    const errors = validateAutomation(invalidAutomation);
    expect(errors).toHaveProperty('name');
    expect(errors).toHaveProperty('description');
    expect(errors).toHaveProperty('event_name');
  });

  it('should return errors for invalid conditions', () => {
    const automationWithInvalidConditions = {
      name: 'Test',
      description: 'Test',
      event_name: 'message_created',
      conditions: [{ attribute_key: '', filter_operator: '', values: '' }],
      actions: [{ action_name: 'send_message', action_params: ['Hello'] }],
    };
    const errors = validateAutomation(automationWithInvalidConditions);
    expect(errors).toHaveProperty('condition_0');
  });

  it('should return errors for invalid actions', () => {
    const automationWithInvalidActions = {
      name: 'Test',
      description: 'Test',
      event_name: 'message_created',
      conditions: [
        {
          attribute_key: 'content',
          filter_operator: 'contains',
          values: 'hello',
        },
      ],
      actions: [{ action_name: 'send_message', action_params: [] }],
    };
    const errors = validateAutomation(automationWithInvalidActions);
    expect(errors).toHaveProperty('action_0');
  });

  it('should not require action params for specific actions', () => {
    const automationWithNoParamAction = {
      name: 'Test',
      description: 'Test',
      event_name: 'message_created',
      conditions: [
        {
          attribute_key: 'content',
          filter_operator: 'contains',
          values: 'hello',
        },
      ],
      actions: [{ action_name: 'mute_conversation' }],
    };
    const errors = validateAutomation(automationWithNoParamAction);
    expect(errors).toEqual({});
  });
});

describe('getSendMessageButtonError', () => {
  it('returns null when the params carry no buttons', () => {
    expect(getSendMessageButtonError('plain text')).toBeNull();
    expect(getSendMessageButtonError({ content: 'x' })).toBeNull();
    expect(getSendMessageButtonError({ content: 'x', buttons: [] })).toBeNull();
  });

  it('does not require a header', () => {
    expect(
      getSendMessageButtonError({ content: 'Body', buttons: [{ title: 'Yes' }] })
    ).toBeNull();
  });

  it('flags a missing body', () => {
    expect(
      getSendMessageButtonError({ content: '  ', buttons: [{ title: 'Yes' }] })
    ).toBe('MISSING_BODY');
  });

  it('flags a blank label', () => {
    expect(
      getSendMessageButtonError({
        content: 'Body',
        buttons: [{ title: 'Yes' }, { title: '' }],
      })
    ).toBe('BLANK_LABEL');
  });

  it('flags a label longer than 20 characters', () => {
    expect(
      getSendMessageButtonError({
        content: 'Body',
        buttons: [{ title: 'a'.repeat(21) }],
      })
    ).toBe('LABEL_TOO_LONG');
  });

  it('flags duplicate labels', () => {
    expect(
      getSendMessageButtonError({
        content: 'Body',
        buttons: [{ title: 'Yes' }, { title: 'Yes' }],
      })
    ).toBe('DUPLICATE_LABEL');
  });

  it('flags a mix of link and quick reply buttons', () => {
    expect(
      getSendMessageButtonError({
        content: 'Body',
        buttons: [{ title: 'A', url: 'https://a.test/x' }, { title: 'B' }],
      })
    ).toBe('MIXED');
  });

  it('flags a non-http url', () => {
    expect(
      getSendMessageButtonError({
        content: 'Body',
        buttons: [{ title: 'A', url: 'ftp://a.test' }],
      })
    ).toBe('INVALID_URL');
  });

  it('returns null for a valid all-link set', () => {
    expect(
      getSendMessageButtonError({
        content: 'Body',
        buttons: [
          { title: 'A', url: 'https://a.test/x' },
          { title: 'B', url: 'https://b.test/y' },
        ],
      })
    ).toBeNull();
  });
});
