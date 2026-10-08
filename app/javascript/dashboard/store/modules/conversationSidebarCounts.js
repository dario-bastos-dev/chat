import ConversationAPI from '../../api/conversations';
import types from '../mutation-types';
import { createMetaDebouncers, getMetaDebounceKey } from './conversationStats';

export const state = {
  allCount: 0,
  mentionsCount: 0,
  participatingCount: 0,
  unattendedCount: 0,
};

const fetchSidebarCounts = async commit => {
  try {
    const response = await ConversationAPI.getSidebarCounts();
    commit(types.SET_CONVERSATION_SIDEBAR_COUNTS, response.data.payload);
  } catch (error) {
    // Ignore errors so the sidebar can continue rendering without counts.
  }
};

const sidebarCountsDebouncers = createMetaDebouncers(fetchSidebarCounts);

export const getters = {
  getCounts: $state => $state,
};

export const actions = {
  get: ({ commit }) => fetchSidebarCounts(commit),
  // Realtime events arrive in bursts from every agent's session, so refetches
  // back off as the account grows, like the conversation tab counts.
  refresh: ({ commit, state: $state }) =>
    sidebarCountsDebouncers[getMetaDebounceKey($state.allCount)](commit),
};

export const mutations = {
  [types.SET_CONVERSATION_SIDEBAR_COUNTS]($state, payload = {}) {
    $state.allCount = payload.all_count || 0;
    $state.mentionsCount = payload.mentions_count || 0;
    $state.participatingCount = payload.participating_count || 0;
    $state.unattendedCount = payload.unattended_count || 0;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
