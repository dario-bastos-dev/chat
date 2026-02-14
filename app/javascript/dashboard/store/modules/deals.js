import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import DealsAPI from '../../api/deals';

export const state = {
  records: [],
  currentDeal: null,
  meta: {
    currentPage: 1,
    totalPages: 1,
    totalCount: 0,
  },
  filters: {
    pipelineId: null,
    stageId: null,
    status: 'open',
    assigneeId: null,
  },
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isMoving: false,
  },
};

export const getters = {
  getDeals(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getMeta(_state) {
    return _state.meta;
  },
  getFilters(_state) {
    return _state.filters;
  },
  getCurrentDeal(_state) {
    return _state.currentDeal;
  },
  getDealById: _state => id => {
    return _state.records.find(record => record.id === Number(id));
  },
  getDealsByStage: _state => stageId => {
    return _state.records
      .filter(deal => deal.stage_id === stageId || deal.stage?.id === stageId)
      .sort((a, b) => a.position - b.position);
  },
  getOpenDeals(_state) {
    return _state.records.filter(deal => deal.status === 'open');
  },
  getTotalValue(_state) {
    return _state.records
      .filter(deal => deal.status === 'open')
      .reduce((sum, deal) => sum + parseFloat(deal.value || 0), 0);
  },
};

export const actions = {
  get: async function getDeals({ commit, state: _state }, params = {}) {
    commit(types.SET_DEALS_UI_FLAG, { isFetching: true });
    try {
      const filters = { ..._state.filters, ...params };
      const response = await DealsAPI.get(filters);
      commit(types.SET_DEALS, response.data.data || response.data);
      if (response.data.meta) {
        commit(types.SET_DEALS_META, response.data.meta);
      }
      return response.data;
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isFetching: false });
    }
  },

  show: async function showDeal({ commit }, dealId) {
    commit(types.SET_DEALS_UI_FLAG, { isFetching: true });
    try {
      const response = await DealsAPI.show(dealId);
      commit(types.SET_CURRENT_DEAL, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createDeal({ commit }, dealData) {
    commit(types.SET_DEALS_UI_FLAG, { isCreating: true });
    try {
      const response = await DealsAPI.create(dealData);
      commit(types.ADD_DEAL, response.data);
      return response.data;
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateDeal({ commit }, { id, ...updateData }) {
    commit(types.SET_DEALS_UI_FLAG, { isUpdating: true });
    try {
      const response = await DealsAPI.update(id, updateData);
      commit(types.EDIT_DEAL, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteDeal({ commit }, id) {
    commit(types.SET_DEALS_UI_FLAG, { isDeleting: true });
    try {
      await DealsAPI.delete(id);
      commit(types.DELETE_DEAL, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isDeleting: false });
    }
  },

  move: async function moveDeal({ commit }, { id, stageId, position }) {
    commit(types.SET_DEALS_UI_FLAG, { isMoving: true });
    try {
      const response = await DealsAPI.move(id, stageId, position);
      commit(types.EDIT_DEAL, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isMoving: false });
    }
  },

  assign: async function assignDeal({ commit }, { id, assigneeId }) {
    commit(types.SET_DEALS_UI_FLAG, { isUpdating: true });
    try {
      const response = await DealsAPI.assign(id, assigneeId);
      commit(types.EDIT_DEAL, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isUpdating: false });
    }
  },

  win: async function winDeal({ commit }, id) {
    commit(types.SET_DEALS_UI_FLAG, { isUpdating: true });
    try {
      const response = await DealsAPI.win(id);
      commit(types.EDIT_DEAL, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isUpdating: false });
    }
  },

  lose: async function loseDeal({ commit }, { id, lostReason }) {
    commit(types.SET_DEALS_UI_FLAG, { isUpdating: true });
    try {
      const response = await DealsAPI.lose(id, lostReason);
      commit(types.EDIT_DEAL, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isUpdating: false });
    }
  },

  setCurrentDeal({ commit }, deal) {
    commit(types.SET_CURRENT_DEAL, deal);
  },

  setFilters({ commit }, filters) {
    commit(types.SET_DEALS_FILTERS, filters);
  },

  clearFilters({ commit }) {
    commit(types.CLEAR_DEALS_FILTERS);
  },
};

export const mutations = {
  [types.SET_DEALS_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_DEALS](_state, deals) {
    _state.records = deals;
  },

  [types.SET_DEALS_META](_state, meta) {
    _state.meta = {
      currentPage: meta.current_page,
      totalPages: meta.total_pages,
      totalCount: meta.total_count,
    };
  },

  [types.ADD_DEAL]: MutationHelpers.create,
  [types.EDIT_DEAL]: MutationHelpers.update,
  [types.DELETE_DEAL]: MutationHelpers.destroy,

  [types.SET_CURRENT_DEAL](_state, deal) {
    _state.currentDeal = deal;
  },

  [types.SET_DEALS_FILTERS](_state, filters) {
    _state.filters = {
      ..._state.filters,
      ...filters,
    };
  },

  [types.CLEAR_DEALS_FILTERS](_state) {
    _state.filters = {
      pipelineId: null,
      stageId: null,
      status: 'open',
      assigneeId: null,
    };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
