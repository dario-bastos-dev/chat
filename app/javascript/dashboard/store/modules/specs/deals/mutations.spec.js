import { mutations } from '../../deals';
import types from '../../../mutation-types';

describe('#mutations', () => {
  it('SET_DEALS_UI_FLAG sets uiFlags', () => {
    const state = { uiFlags: { isFetching: false } };
    mutations[types.SET_DEALS_UI_FLAG](state, { isFetching: true });
    expect(state.uiFlags).toEqual({ isFetching: true });
  });

  it('SET_DEALS sets records', () => {
    const state = { records: [] };
    mutations[types.SET_DEALS](state, [{ id: 1 }]);
    expect(state.records).toEqual([{ id: 1 }]);
  });

  it('SET_DEALS_META sets meta', () => {
    const state = { meta: {} };
    mutations[types.SET_DEALS_META](state, {
      current_page: 1,
      total_pages: 5,
      total_count: 50,
    });
    expect(state.meta).toEqual({
      currentPage: 1,
      totalPages: 5,
      totalCount: 50,
    });
  });

  it('ADD_DEAL adds a record', () => {
    const state = { records: [] };
    mutations[types.ADD_DEAL](state, { id: 1 });
    expect(state.records).toEqual([{ id: 1 }]);
  });

  it('EDIT_DEAL updates a record', () => {
    const state = { records: [{ id: 1, name: 'Old' }] };
    mutations[types.EDIT_DEAL](state, { id: 1, name: 'New' });
    expect(state.records).toEqual([{ id: 1, name: 'New' }]);
  });

  it('DELETE_DEAL removes a record', () => {
    const state = { records: [{ id: 1 }] };
    mutations[types.DELETE_DEAL](state, 1);
    expect(state.records).toEqual([]);
  });

  it('SET_CURRENT_DEAL sets currentDeal', () => {
    const state = { currentDeal: null };
    mutations[types.SET_CURRENT_DEAL](state, { id: 1 });
    expect(state.currentDeal).toEqual({ id: 1 });
  });

  it('SET_DEALS_FILTERS updates filters', () => {
    const state = { filters: { status: 'open' } };
    mutations[types.SET_DEALS_FILTERS](state, { assigneeId: 1 });
    expect(state.filters).toEqual({ status: 'open', assigneeId: 1 });
  });

  it('CLEAR_DEALS_FILTERS resets filters', () => {
    const state = { filters: { status: 'won', assigneeId: 1 } };
    mutations[types.CLEAR_DEALS_FILTERS](state);
    expect(state.filters).toEqual({
      pipelineId: null,
      stageId: null,
      status: 'open',
      assigneeId: null,
    });
  });
});
