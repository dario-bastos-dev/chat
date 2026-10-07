import axios from 'axios';
import { actions } from '../../conversationSidebarCounts';
import types from '../../../mutation-types';

const { invokedWaits } = vi.hoisted(() => ({ invokedWaits: [] }));

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

vi.mock('@chatwoot/utils', () => ({
  debounce:
    (fn, wait) =>
    (...args) => {
      invokedWaits.push(wait);
      return fn(...args);
    },
}));

const payload = {
  all_count: 3,
  mentions_count: 1,
  participating_count: 0,
  unattended_count: 2,
};

describe('#actions', () => {
  beforeEach(() => {
    commit.mockClear();
    invokedWaits.length = 0;
    axios.get.mockResolvedValue({ data: { payload } });
  });

  describe('#get', () => {
    it('fetches immediately and commits the counts', async () => {
      await actions.get({ commit, state: { allCount: 0 } });

      expect(invokedWaits).toEqual([]);
      expect(commit).toHaveBeenCalledWith(
        types.SET_CONVERSATION_SIDEBAR_COUNTS,
        payload
      );
    });

    it('ignores API errors', async () => {
      axios.get.mockRejectedValue({ message: 'Incorrect header' });

      await actions.get({ commit, state: { allCount: 0 } });

      expect(commit).not.toHaveBeenCalled();
    });
  });

  describe('#refresh', () => {
    it.each([
      [50, 1000],
      [500, 7500],
      [5000, 15000],
      [0, 15000],
    ])(
      'waits longer as the account grows (allCount %i -> %ims)',
      async (allCount, wait) => {
        await actions.refresh({ commit, state: { allCount } });

        expect(invokedWaits).toEqual([wait]);
        expect(commit).toHaveBeenCalledWith(
          types.SET_CONVERSATION_SIDEBAR_COUNTS,
          payload
        );
      }
    );
  });
});
