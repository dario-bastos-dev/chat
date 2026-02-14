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
      const errorMessage = error?.response?.data?.message;
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
      throw new Error(error);
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
      throw new Error(error);
    } finally {
      commit(types.SET_PIPELINES_UI_FLAG, { isDeleting: false });
    }
  },

  setCurrentPipeline({ commit }, pipeline) {
    commit(types.SET_CURRENT_PIPELINE, pipeline);
  },

  // Stage actions
  createStage: async function createStage(
    { commit, state: _state },
    { pipelineId, stageData }
  ) {
    try {
      const response = await PipelinesAPI.createStage(pipelineId, {
        stage: stageData,
      });
      // Refresh current pipeline to get updated stages
      const pipelineResponse = await PipelinesAPI.show(pipelineId);
      commit(types.SET_CURRENT_PIPELINE, pipelineResponse.data);
      commit(types.EDIT_PIPELINE, pipelineResponse.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    }
  },

  updateStage: async function updateStage(
    { commit },
    { pipelineId, stageId, stageData }
  ) {
    try {
      const response = await PipelinesAPI.updateStage(pipelineId, stageId, {
        stage: stageData,
      });
      // Refresh current pipeline to get updated stages
      const pipelineResponse = await PipelinesAPI.show(pipelineId);
      commit(types.SET_CURRENT_PIPELINE, pipelineResponse.data);
      commit(types.EDIT_PIPELINE, pipelineResponse.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    }
  },

  deleteStage: async function deleteStage({ commit }, { pipelineId, stageId }) {
    try {
      await PipelinesAPI.deleteStage(pipelineId, stageId);
      // Refresh current pipeline to get updated stages
      const pipelineResponse = await PipelinesAPI.show(pipelineId);
      commit(types.SET_CURRENT_PIPELINE, pipelineResponse.data);
      commit(types.EDIT_PIPELINE, pipelineResponse.data);
    } catch (error) {
      throw new Error(error);
    }
  },

  reorderStages: async function reorderStages(
    { commit },
    { pipelineId, stageIds }
  ) {
    try {
      await PipelinesAPI.reorderStages(pipelineId, stageIds);
      // Refresh current pipeline to get updated stages
      const pipelineResponse = await PipelinesAPI.show(pipelineId);
      commit(types.SET_CURRENT_PIPELINE, pipelineResponse.data);
      commit(types.EDIT_PIPELINE, pipelineResponse.data);
    } catch (error) {
      throw new Error(error);
    }
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
  [types.ADD_PIPELINE]: MutationHelpers.create,
  [types.EDIT_PIPELINE]: MutationHelpers.update,
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
