import { getters } from '../../deals';

describe('#getters', () => {
  it('getDeals returns records', () => {
    const state = { records: [{ id: 1 }] };
    expect(getters.getDeals(state)).toEqual([{ id: 1 }]);
  });

  it('getUIFlags returns uiFlags', () => {
    const state = { uiFlags: { isFetching: true } };
    expect(getters.getUIFlags(state)).toEqual({ isFetching: true });
  });

  it('getMeta returns meta', () => {
    const state = { meta: { totalCount: 10 } };
    expect(getters.getMeta(state)).toEqual({ totalCount: 10 });
  });

  it('getFilters returns filters', () => {
    const state = { filters: { status: 'open' } };
    expect(getters.getFilters(state)).toEqual({ status: 'open' });
  });

  it('getCurrentDeal returns currentDeal', () => {
    const state = { currentDeal: { id: 1 } };
    expect(getters.getCurrentDeal(state)).toEqual({ id: 1 });
  });

  it('getDealById returns deal by id', () => {
    const state = { records: [{ id: 1 }, { id: 2 }] };
    expect(getters.getDealById(state)(2)).toEqual({ id: 2 });
  });

  it('getDealsByStage returns deals filtered by stage and sorted by position', () => {
    const state = {
      records: [
        { id: 1, stage_id: 1, position: 2 },
        { id: 2, stage_id: 2, position: 1 },
        { id: 3, stage_id: 1, position: 1 },
      ],
    };
    expect(getters.getDealsByStage(state)(1)).toEqual([
      { id: 3, stage_id: 1, position: 1 },
      { id: 1, stage_id: 1, position: 2 },
    ]);
  });

  it('getOpenDeals returns only deals with status open', () => {
    const state = {
      records: [
        { id: 1, status: 'open' },
        { id: 2, status: 'won' },
        { id: 3, status: 'lost' },
      ],
    };
    expect(getters.getOpenDeals(state)).toEqual([{ id: 1, status: 'open' }]);
  });

  it('getBoardTotal sums the real per-stage totals, not the loaded page', () => {
    const state = {
      board: {
        stages: [
          { id: 1, total_count: 34, deals: [{ id: 1 }, { id: 2 }] },
          { id: 2, total_count: 8, deals: [{ id: 3 }] },
        ],
        loadingStageIds: [],
      },
    };
    expect(getters.getBoardTotal(state)).toEqual(42);
  });

  it('isStageLoading reflects the per-stage loading state', () => {
    const state = {
      board: { stages: [], loadingStageIds: [2] },
    };
    expect(getters.isStageLoading(state)(2)).toBe(true);
    expect(getters.isStageLoading(state)(1)).toBe(false);
  });
});
