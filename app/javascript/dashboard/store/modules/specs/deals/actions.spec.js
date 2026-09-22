import { actions } from '../../deals';
import types from '../../../mutation-types';
import DealsAPI from '../../../../api/deals';

vi.mock('../../../../api/deals');

const commit = vi.fn();
const state = { filters: {} };

describe('#actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    commit.mockClear();
  });

  describe('#get', () => {
    it('sends correct actions if API is success', async () => {
      const deals = [{ id: 1, title: 'Test Deal' }];
      DealsAPI.get.mockResolvedValue({ data: { data: deals } });
      await actions.get({ commit, state });
      expect(commit).toHaveBeenCalledWith(types.SET_DEALS_UI_FLAG, {
        isFetching: true,
      });
      expect(commit).toHaveBeenCalledWith(types.SET_DEALS, deals);
      expect(commit).toHaveBeenCalledWith(types.SET_DEALS_UI_FLAG, {
        isFetching: false,
      });
    });

    it('handles pagination meta', async () => {
      const meta = { current_page: 1, total_pages: 5, total_count: 50 };
      DealsAPI.get.mockResolvedValue({
        data: {
          data: [],
          meta: meta,
        },
      });
      await actions.get({ commit, state });
      expect(commit).toHaveBeenCalledWith(types.SET_DEALS_META, meta);
    });
  });

  describe('#create', () => {
    it('sends correct actions if API is success', async () => {
      const deal = { id: 1, title: 'New Deal' };
      DealsAPI.create.mockResolvedValue({ data: deal });
      await actions.create({ commit }, { title: 'New Deal' });
      expect(commit).toHaveBeenCalledWith(types.SET_DEALS_UI_FLAG, {
        isCreating: true,
      });
      expect(commit).toHaveBeenCalledWith(types.ADD_DEAL, deal);
      expect(commit).toHaveBeenCalledWith(types.SET_DEALS_UI_FLAG, {
        isCreating: false,
      });
    });

    it('throws error if API fails', async () => {
      DealsAPI.create.mockRejectedValue({
        response: { data: { message: 'Error' } },
      });
      await expect(actions.create({ commit }, {})).rejects.toThrow('Error');
      expect(commit).toHaveBeenCalledWith(types.SET_DEALS_UI_FLAG, {
        isCreating: false,
      });
    });
  });

  describe('#update', () => {
    it('sends correct actions if API is success', async () => {
      const deal = { id: 1, title: 'Updated Deal' };
      DealsAPI.update.mockResolvedValue({ data: deal });
      await actions.update({ commit }, deal);
      expect(commit).toHaveBeenCalledWith(types.SET_DEALS_UI_FLAG, {
        isUpdating: true,
      });
      expect(commit).toHaveBeenCalledWith(types.EDIT_DEAL, deal);
      expect(commit).toHaveBeenCalledWith(types.SET_DEALS_UI_FLAG, {
        isUpdating: false,
      });
    });
  });

  describe('#delete', () => {
    it('sends correct actions if API is success', async () => {
      DealsAPI.delete.mockResolvedValue({});
      await actions.delete({ commit }, 1);
      expect(commit).toHaveBeenCalledWith(types.SET_DEALS_UI_FLAG, {
        isDeleting: true,
      });
      expect(commit).toHaveBeenCalledWith(types.DELETE_DEAL, 1);
      expect(commit).toHaveBeenCalledWith(types.SET_DEALS_UI_FLAG, {
        isDeleting: false,
      });
    });
  });

  describe('#move', () => {
    const getters = { getDealById: () => ({ id: 1, stage_id: 1, stage: {} }) };

    it('sends correct actions if API is success', async () => {
      const deal = { id: 1, stage_id: 2 };
      DealsAPI.move.mockResolvedValue({ data: deal });
      await actions.move(
        { commit, getters },
        { id: 1, fromStageId: 1, stageId: 2, sort: 'created_at_desc' }
      );
      expect(commit).toHaveBeenCalledWith(types.SET_DEALS_UI_FLAG, {
        isMoving: true,
      });
      expect(commit).toHaveBeenCalledWith(types.EDIT_DEAL, deal);
      expect(commit).toHaveBeenCalledWith(types.SET_DEALS_UI_FLAG, {
        isMoving: false,
      });
    });

    // A ordem da coluna vem da data: o board recebe a ordenacao, nao o indice
    // em que o card foi solto.
    it('repositions the card on the board by the current sort', async () => {
      DealsAPI.move.mockResolvedValue({ data: { id: 1, stage_id: 2 } });
      await actions.move(
        { commit, getters },
        { id: 1, fromStageId: 1, stageId: 2, sort: 'created_at_asc' }
      );
      expect(commit).toHaveBeenCalledWith(types.MOVE_DEAL_ON_BOARD, {
        dealId: 1,
        fromStageId: 1,
        toStageId: 2,
        sort: 'created_at_asc',
      });
    });

    // `position` virou dado que ninguem le desde que a ordem passou a ser
    // por data; o move so troca a etapa.
    it('does not send a position to the API', async () => {
      DealsAPI.move.mockResolvedValue({ data: { id: 1, stage_id: 2 } });
      await actions.move(
        { commit, getters },
        { id: 1, fromStageId: 1, stageId: 2, sort: 'created_at_desc' }
      );
      expect(DealsAPI.move).toHaveBeenCalledWith(1, 2);
    });
  });
});
