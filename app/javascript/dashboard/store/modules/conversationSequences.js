import types from '../mutation-types';
import ConversationSequencesAPI from '../../api/conversationSequences';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isUpdating: false,
  },
};

export const getters = {
  getSequences($state) {
    return $state.records;
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  get: async function getSequences({ commit }, conversationId) {
    commit(types.SET_CONVERSATION_SEQUENCES_UI_FLAG, { isFetching: true });
    try {
      const response =
        await ConversationSequencesAPI.getSequences(conversationId);
      commit(types.SET_CONVERSATION_SEQUENCES, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_CONVERSATION_SEQUENCES_UI_FLAG, { isFetching: false });
    }
  },
  attach: async function attachSequence(
    { commit, dispatch },
    { conversationId, messageSequenceId }
  ) {
    commit(types.SET_CONVERSATION_SEQUENCES_UI_FLAG, { isUpdating: true });
    try {
      await ConversationSequencesAPI.attach(conversationId, messageSequenceId);
      await dispatch('get', conversationId);
    } catch (error) {
      throw error;
    } finally {
      commit(types.SET_CONVERSATION_SEQUENCES_UI_FLAG, { isUpdating: false });
    }
  },
  detach: async function detachSequence(
    { commit, dispatch },
    { conversationId, conversationSequenceId }
  ) {
    commit(types.SET_CONVERSATION_SEQUENCES_UI_FLAG, { isUpdating: true });
    try {
      await ConversationSequencesAPI.detach(
        conversationId,
        conversationSequenceId
      );
      await dispatch('get', conversationId);
    } catch (error) {
      throw error;
    } finally {
      commit(types.SET_CONVERSATION_SEQUENCES_UI_FLAG, { isUpdating: false });
    }
  },
};

export const mutations = {
  [types.SET_CONVERSATION_SEQUENCES_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.SET_CONVERSATION_SEQUENCES]($state, data) {
    $state.records = data;
  },
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
