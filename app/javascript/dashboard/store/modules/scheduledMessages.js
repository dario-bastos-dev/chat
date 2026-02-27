import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import ScheduledMessagesAPI from '../../api/scheduledMessages';
import { throwErrorMessage } from '../utils/api';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isDeleting: false,
    isUpdating: false,
  },
};

export const getters = {
  getScheduledMessages($state) {
    return $state.records;
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  get: async function getScheduledMessages({ commit }, conversationId) {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isFetching: true });
    try {
      const response =
        await ScheduledMessagesAPI.getForConversation(conversationId);
      commit(types.SET_SCHEDULED_MESSAGES, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isFetching: false });
    }
  },
  create: async function createScheduledMessage(
    { commit },
    { conversationId, macrosObj }
  ) {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isCreating: true });
    try {
      const response = await ScheduledMessagesAPI.createForConversation(
        conversationId,
        macrosObj
      );
      commit(types.ADD_SCHEDULED_MESSAGE, response.data.payload);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { conversationId, id, ...updateObj }) => {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isUpdating: true });
    try {
      const response = await ScheduledMessagesAPI.updateForConversation(
        conversationId,
        id,
        updateObj
      );
      commit(types.EDIT_SCHEDULED_MESSAGE, response.data.payload);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isUpdating: false });
    }
  },
  delete: async ({ commit }, { conversationId, id }) => {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isDeleting: true });
    try {
      await ScheduledMessagesAPI.deleteForConversation(conversationId, id);
      commit(types.DELETE_SCHEDULED_MESSAGE, id);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_SCHEDULED_MESSAGES_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.ADD_SCHEDULED_MESSAGE]: MutationHelpers.setSingleRecord,
  [types.SET_SCHEDULED_MESSAGES]: MutationHelpers.set,
  [types.EDIT_SCHEDULED_MESSAGE]: MutationHelpers.update,
  [types.DELETE_SCHEDULED_MESSAGE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
