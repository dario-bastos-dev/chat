import types from '../../../mutation-types';
import { mutations } from '../../conversationUnreadCounts';

describe('#mutations', () => {
  describe('#SET_CONVERSATION_UNREAD_COUNTS', () => {
    it('normalizes unread count payload', () => {
      const state = {
        inboxes: {},
        labels: {},
        teams: {},
        folders: {},
      };

      mutations[types.SET_CONVERSATION_UNREAD_COUNTS](state, {
        all_count: '3',
        inboxes: {
          1: '2',
          2: 0,
          3: 'invalid',
        },
        labels: {
          4: 5,
          5: -1,
        },
        teams: {
          6: '7',
          7: 0,
        },
        mentions_count: '8',
        participating_count: 9,
        unattended_count: 0,
        folders: {
          10: '11',
          12: -1,
        },
      });

      expect(state).toEqual({
        inboxes: { 1: 2 },
        labels: { 4: 5 },
        teams: { 6: 7 },
        folders: { 10: 11 },
      });
    });

    it('clears counts when payload is empty', () => {
      const state = {
        inboxes: { 1: 2 },
        labels: { 4: 5 },
        teams: { 6: 7 },
        folders: { 11: 12 },
      };

      mutations[types.SET_CONVERSATION_UNREAD_COUNTS](state, {});

      expect(state).toEqual({
        inboxes: {},
        labels: {},
        teams: {},
        folders: {},
      });
    });
  });
});
