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
  describe('MOVE_DEAL_ON_BOARD', () => {
    // Etapa 10 com um negocio do dia 1; etapa 20 com um do dia 20 e um de agosto.
    const buildBoard = () => ({
      board: {
        stages: [
          {
            id: 10,
            total_count: 1,
            total_value: 100,
            deals: [
              { id: 1, value: 100, created_at: '2026-09-01T10:00:00.000Z' },
            ],
          },
          {
            id: 20,
            total_count: 2,
            total_value: 50,
            deals: [
              { id: 2, value: 50, created_at: '2026-09-20T10:00:00.000Z' },
              { id: 3, value: 0, created_at: '2026-08-01T10:00:00.000Z' },
            ],
          },
        ],
      },
    });

    it('places the moved deal by the newest-first order, not at the drop point', () => {
      const state = buildBoard();

      mutations[types.MOVE_DEAL_ON_BOARD](state, {
        dealId: 1,
        fromStageId: 10,
        toStageId: 20,
        sort: 'created_at_desc',
      });

      expect(state.board.stages[1].deals.map(deal => deal.id)).toEqual([
        2, 1, 3,
      ]);
    });

    it('places the moved deal by the oldest-first order', () => {
      const state = buildBoard();

      mutations[types.MOVE_DEAL_ON_BOARD](state, {
        dealId: 1,
        fromStageId: 10,
        toStageId: 20,
        sort: 'created_at_asc',
      });

      expect(state.board.stages[1].deals.map(deal => deal.id)).toEqual([
        3, 1, 2,
      ]);
    });

    // No Kanban o draggable ja moveu o card para o array de destino, na posicao
    // em que foi solto, quando esta mutation roda.
    it('re-sorts a card that the drag already dropped into the target stage', () => {
      const state = buildBoard();
      const [dragged] = state.board.stages[0].deals.splice(0, 1);
      state.board.stages[1].deals.unshift(dragged);

      mutations[types.MOVE_DEAL_ON_BOARD](state, {
        dealId: 1,
        fromStageId: 10,
        toStageId: 20,
        sort: 'created_at_desc',
      });

      expect(state.board.stages[1].deals.map(deal => deal.id)).toEqual([
        2, 1, 3,
      ]);
    });

    // Reproduz o bug: o draggable ja pos o card no destino, e a mutation o
    // descontava e recontava na propria coluna de destino.
    it('moves the counters when the drag already placed the card in the target', () => {
      const state = buildBoard();
      const [dragged] = state.board.stages[0].deals.splice(0, 1);
      state.board.stages[1].deals.unshift(dragged);

      mutations[types.MOVE_DEAL_ON_BOARD](state, {
        dealId: 1,
        fromStageId: 10,
        toStageId: 20,
        sort: 'created_at_desc',
      });

      const [source, target] = state.board.stages;
      expect([source.total_count, source.total_value]).toEqual([0, 0]);
      expect([target.total_count, target.total_value]).toEqual([3, 150]);
    });

    it('keeps the counters when the card is dropped back into its own stage', () => {
      const state = buildBoard();

      mutations[types.MOVE_DEAL_ON_BOARD](state, {
        dealId: 2,
        fromStageId: 20,
        toStageId: 20,
        sort: 'created_at_desc',
      });

      const target = state.board.stages[1];
      expect(target.deals.map(deal => deal.id)).toEqual([2, 3]);
      expect([target.total_count, target.total_value]).toEqual([2, 50]);
    });

    it('moves the count and the value from one stage to the other', () => {
      const state = buildBoard();

      mutations[types.MOVE_DEAL_ON_BOARD](state, {
        dealId: 1,
        fromStageId: 10,
        toStageId: 20,
        sort: 'created_at_desc',
      });

      const [source, target] = state.board.stages;
      expect([source.total_count, source.total_value]).toEqual([0, 0]);
      expect([target.total_count, target.total_value]).toEqual([3, 150]);
    });
  });
});
