import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import PipelinesAPI from '../../api/pipelines';

export const state = {
  records: [],
  currentPipeline: null,
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getPipelines(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getCurrentPipeline(_state) {
    return _state.currentPipeline;
  },
  getPipelineById: _state => id => {
    return _state.records.find(record => record.id === Number(id));
  },
  getDefaultPipeline(_state) {
    return (
      _state.records.find(record => record.is_default) || _state.records[0]
    );
  },
};

export const actions = {
  get: async function getPipelines({ commit }) {
    commit(types.SET_PIPELINES_UI_FLAG, { isFetching: true });
    try {
      const response = await PipelinesAPI.get();
      commit(types.SET_PIPELINES, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_PIPELINES_UI_FLAG, { isFetching: false });
    }
  },

  show: async function showPipeline({ commit }, pipelineId) {
    commit(types.SET_PIPELINES_UI_FLAG, { isFetching: true });
    try {
      const response = await PipelinesAPI.show(pipelineId);
      commit(types.SET_CURRENT_PIPELINE, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_PIPELINES_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createPipeline({ commit }, pipelineData) {
    commit(types.SET_PIPELINES_UI_FLAG, { isCreating: true });
    try {
      const response = await PipelinesAPI.create({ pipeline: pipelineData });
      commit(types.ADD_PIPELINE, response.data);
      return response.data;
    } catch (error) {
      const errorMessage = error?.response?.data?.message || error?.response?.data?.error || error?.message || error;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_PIPELINES_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updatePipeline({ commit }, { id, ...updateData }) {
    commit(types.SET_PIPELINES_UI_FLAG, { isUpdating: true });
    try {
      const response = await PipelinesAPI.update(id, { pipeline: updateData });
      commit(types.EDIT_PIPELINE, response.data);
      return response.data;
    } catch (error) {
      const errorMessage = error?.response?.data?.message || error?.response?.data?.error || error?.message || error;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_PIPELINES_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deletePipeline({ commit }, id) {
    commit(types.SET_PIPELINES_UI_FLAG, { isDeleting: true });
    try {
      await PipelinesAPI.delete(id);
      commit(types.DELETE_PIPELINE, id);
    } catch (error) {
      const errorMessage = error?.response?.data?.message || error?.response?.data?.error || error;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_PIPELINES_UI_FLAG, { isDeleting: false });
    }
  },

  setCurrentPipeline({ commit }, pipeline) {
    commit(types.SET_CURRENT_PIPELINE, pipeline);
  },

};

export const mutations = {
  [types.SET_PIPELINES_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_PIPELINES]: MutationHelpers.set,
  [types.ADD_PIPELINE](_state, pipeline) {
    MutationHelpers.create(_state, pipeline);
    if (pipeline.is_default) {
      _state.records.forEach(record => {
        if (record.id !== pipeline.id) {
          record.is_default = false;
        }
      });
    }
  },
  [types.EDIT_PIPELINE](_state, pipeline) {
    MutationHelpers.update(_state, pipeline);
    if (pipeline.is_default) {
      _state.records.forEach(record => {
        if (record.id !== pipeline.id) {
          record.is_default = false;
        }
      });
    }
  },
  [types.DELETE_PIPELINE]: MutationHelpers.destroy,

  [types.SET_CURRENT_PIPELINE](_state, pipeline) {
    _state.currentPipeline = pipeline;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
