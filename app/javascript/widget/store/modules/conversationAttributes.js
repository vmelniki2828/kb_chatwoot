import {
  SET_CONVERSATION_ATTRIBUTES,
  UPDATE_CONVERSATION_ATTRIBUTES,
  CLEAR_CONVERSATION_ATTRIBUTES,
} from '../types';
import { getConversationAPI } from '../../api/conversation';

const normalizeConversationId = id => {
  if (id === null || id === undefined || id === '') return '';
  return String(id);
};

const state = {
  id: '',
  status: '',
};

export const getters = {
  getConversationParams: $state => $state,
};

export const actions = {
  getAttributes: async ({ commit }) => {
    try {
      const { data } = await getConversationAPI();
      const { contact_last_seen_at: lastSeen } = data;
      commit(SET_CONVERSATION_ATTRIBUTES, data);
      commit('conversation/setMetaUserLastSeenAt', lastSeen, { root: true });
    } catch (error) {
      // Ignore error
    }
  },
  update({ commit }, data) {
    commit(UPDATE_CONVERSATION_ATTRIBUTES, data);
  },
  clearConversationAttributes: ({ commit }) => {
    commit('CLEAR_CONVERSATION_ATTRIBUTES');
  },
};

export const mutations = {
  [SET_CONVERSATION_ATTRIBUTES]($state, data) {
    $state.id = normalizeConversationId(data.id);
    $state.status = data.status;
  },
  [UPDATE_CONVERSATION_ATTRIBUTES]($state, data) {
    const incomingId = normalizeConversationId(data.id);
    if (incomingId !== '' && incomingId === $state.id) {
      $state.status = data.status;
    }
  },
  [CLEAR_CONVERSATION_ATTRIBUTES]($state) {
    $state.id = '';
    $state.status = '';
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
