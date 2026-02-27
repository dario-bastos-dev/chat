import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import MessageSequencesAPI from '../../api/messageSequences';
import { throwErrorMessage } from '../utils/api';

export const state = {
  records: [],
  uiFlags: {
    isFetchingItem: false,
    isFetching: false,
    isCreating: false,
    isDeleting: false,
    isUpdating: false,
  },
};

export const getters = {
  getMessageSequences($state) {
    return $state.records;
  },
  getMessageSequence: $state => id => {
    return $state.records.find(record => record.id === Number(id));
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  get: async function getMessageSequences({ commit }) {
    commit(types.SET_MESSAGE_SEQUENCES_UI_FLAG, { isFetching: true });
    try {
      const response = await MessageSequencesAPI.get();
      commit(types.SET_MESSAGE_SEQUENCES, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_MESSAGE_SEQUENCES_UI_FLAG, { isFetching: false });
    }
  },
  getSingle: async function getMessageSequenceById({ commit }, id) {
    commit(types.SET_MESSAGE_SEQUENCES_UI_FLAG, { isFetchingItem: true });
    try {
      const response = await MessageSequencesAPI.show(id);
      commit(types.ADD_MESSAGE_SEQUENCE, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_MESSAGE_SEQUENCES_UI_FLAG, { isFetchingItem: false });
    }
  },
  create: async function createMessageSequence({ commit }, sequenceObj) {
    commit(types.SET_MESSAGE_SEQUENCES_UI_FLAG, { isCreating: true });
    try {
      const response = await MessageSequencesAPI.create(sequenceObj);
      commit(types.ADD_MESSAGE_SEQUENCE, response.data.payload);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_MESSAGE_SEQUENCES_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, payload) => {
    commit(types.SET_MESSAGE_SEQUENCES_UI_FLAG, { isUpdating: true });
    try {
      let id, data;
      if (payload instanceof FormData) {
        id = payload.get('id');
        data = payload;
      } else {
        id = payload.id;
        const { id: _id, ...rest } = payload;
        data = rest;
      }

      const response = await MessageSequencesAPI.update(id, data);
      commit(types.EDIT_MESSAGE_SEQUENCE, response.data.payload);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_MESSAGE_SEQUENCES_UI_FLAG, { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_MESSAGE_SEQUENCES_UI_FLAG, { isDeleting: true });
    try {
      await MessageSequencesAPI.delete(id);
      commit(types.DELETE_MESSAGE_SEQUENCE, id);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_MESSAGE_SEQUENCES_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_MESSAGE_SEQUENCES_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.ADD_MESSAGE_SEQUENCE]: MutationHelpers.setSingleRecord,
  [types.SET_MESSAGE_SEQUENCES]: MutationHelpers.set,
  [types.EDIT_MESSAGE_SEQUENCE]: MutationHelpers.update,
  [types.DELETE_MESSAGE_SEQUENCE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
