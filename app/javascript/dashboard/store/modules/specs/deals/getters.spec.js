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

  it('getTotalValue returns sum of values of open deals', () => {
    const state = {
      records: [
        { id: 1, status: 'open', value: 100 },
        { id: 2, status: 'won', value: 200 },
        { id: 3, status: 'lost', value: 50 },
        { id: 4, status: 'open', value: 50.5 },
      ],
    };
    expect(getters.getTotalValue(state)).toEqual(150.5);
  });
});
