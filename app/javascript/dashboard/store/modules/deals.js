import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import DealsAPI from '../../api/deals';
import PipelinesAPI from '../../api/pipelines';

const DEALS_PER_STAGE = 20;

export const state = {
  records: [],
  currentDeal: null,
  // Estado do Kanban: cada etapa carrega a sua propria pagina e conhece o
  // total real vindo do banco, independente de quantos negocios ja carregou.
  board: {
    stages: [],
    loadingStageIds: [],
    currency: 'BRL',
    weightedForecast: 0,
  },
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
  getBoardStages(_state) {
    return _state.board.stages;
  },
  isStageLoading: _state => stageId =>
    _state.board.loadingStageIds.includes(stageId),
  getBoardTotal(_state) {
    return _state.board.stages.reduce(
      (sum, stage) => sum + (stage.total_count || 0),
      0
    );
  },
  getBoardValue(_state) {
    return _state.board.stages.reduce(
      (sum, stage) => sum + Number(stage.total_value || 0),
      0
    );
  },
  getBoardCurrency(_state) {
    return _state.board.currency;
  },
  getWeightedForecast(_state) {
    return _state.board.weightedForecast;
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

  fetchBoard: async function fetchBoard({ commit }, { pipelineId, filters = {} }) {
    commit(types.SET_DEALS_UI_FLAG, { isFetching: true });
    try {
      const response = await PipelinesAPI.board(pipelineId, {
        per_stage: DEALS_PER_STAGE,
        ...filters,
      });
      commit(types.SET_DEAL_BOARD, response.data);
      return response.data;
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isFetching: false });
    }
  },

  loadMoreForStage: async function loadMoreForStage(
    { commit, state: _state },
    { stageId, filters = {} }
  ) {
    const stage = _state.board.stages.find(s => s.id === stageId);
    if (!stage) return;

    commit(types.SET_STAGE_LOADING, { stageId, isLoading: true });
    try {
      const page = Math.floor(stage.deals.length / DEALS_PER_STAGE) + 1;
      const response = await DealsAPI.get({
        ...filters,
        stageId,
        page,
        perPage: DEALS_PER_STAGE,
      });
      commit(types.APPEND_STAGE_DEALS, {
        stageId,
        deals: response.data.data || [],
      });
    } finally {
      commit(types.SET_STAGE_LOADING, { stageId, isLoading: false });
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
      commit(types.REMOVE_DEAL_FROM_BOARD, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isDeleting: false });
    }
  },

  move: async function moveDeal({ commit, getters }, { id, stageId, position }) {
    commit(types.SET_DEALS_UI_FLAG, { isMoving: true });

    // Optimistic Update: atualiza localmente no Vuex para evitar o efeito "ioiô" no Kanban
    const deal = getters.getDealById(id);
    if (deal) {
      const optimisticDeal = {
        ...deal,
        stage_id: stageId,
        stage: { ...deal.stage, id: stageId },
        position: position
      };
      commit(types.EDIT_DEAL, optimisticDeal);
    }
    commit(types.MOVE_DEAL_ON_BOARD, { dealId: id, toStageId: stageId, position });

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

  [types.SET_DEAL_BOARD](_state, payload) {
    _state.board.stages = (payload.stages || []).map(stage => ({
      ...stage,
      deals: stage.deals || [],
    }));
    _state.board.loadingStageIds = [];
    _state.board.currency = payload.currency || 'BRL';
    _state.board.weightedForecast = Number(payload.weighted_forecast || 0);
  },

  [types.APPEND_STAGE_DEALS](_state, { stageId, deals }) {
    const stage = _state.board.stages.find(s => s.id === stageId);
    if (!stage) return;

    const known = new Set(stage.deals.map(deal => deal.id));
    stage.deals.push(...deals.filter(deal => !known.has(deal.id)));
  },

  [types.SET_STAGE_LOADING](_state, { stageId, isLoading }) {
    const ids = _state.board.loadingStageIds.filter(id => id !== stageId);
    _state.board.loadingStageIds = isLoading ? [...ids, stageId] : ids;
  },

  // Move o card entre colunas na hora, ajustando os totais das duas pontas,
  // para o Kanban nao piscar esperando a resposta da API.
  [types.MOVE_DEAL_ON_BOARD](_state, { dealId, toStageId, position }) {
    let moved = null;

    _state.board.stages.forEach(stage => {
      const index = stage.deals.findIndex(deal => deal.id === dealId);
      if (index === -1) return;

      [moved] = stage.deals.splice(index, 1);
      stage.total_count = Math.max((stage.total_count || 1) - 1, 0);
      stage.total_value = Number(stage.total_value || 0) - Number(moved.value || 0);
    });

    if (!moved) return;

    const target = _state.board.stages.find(stage => stage.id === toStageId);
    if (!target) return;

    const updated = {
      ...moved,
      stage_id: toStageId,
      stage: { ...moved.stage, id: toStageId },
    };
    target.deals.splice(position ?? target.deals.length, 0, updated);
    target.total_count = (target.total_count || 0) + 1;
    target.total_value = Number(target.total_value || 0) + Number(moved.value || 0);
  },

  [types.REMOVE_DEAL_FROM_BOARD](_state, dealId) {
    _state.board.stages.forEach(stage => {
      const index = stage.deals.findIndex(deal => deal.id === dealId);
      if (index === -1) return;

      const [removed] = stage.deals.splice(index, 1);
      stage.total_count = Math.max((stage.total_count || 1) - 1, 0);
      stage.total_value = Number(stage.total_value || 0) - Number(removed.value || 0);
    });
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
