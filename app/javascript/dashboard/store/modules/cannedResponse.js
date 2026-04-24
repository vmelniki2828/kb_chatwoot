import { throwErrorMessage } from 'dashboard/store/utils/api';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import CannedResponseAPI from '../../api/cannedResponse';

function normalizeCannedLabelIds(raw) {
  if (raw == null) return [];
  const arr = Array.isArray(raw) ? raw : Object.values(raw);
  return arr
    .map(id => Number(id))
    .filter(id => Number.isInteger(id) && id > 0);
}

const state = {
  records: [],
  uiFlags: {
    fetchingList: false,
    fetchingItem: false,
    creatingItem: false,
    updatingItem: false,
    deletingItem: false,
    importingTable: false,
  },
};

const getters = {
  getCannedResponses(_state) {
    return _state.records;
  },
  getSortedCannedResponses(_state) {
    return sortOrder =>
      [..._state.records].sort((a, b) => {
        if (sortOrder === 'asc') {
          return a.short_code.localeCompare(b.short_code);
        }
        return b.short_code.localeCompare(a.short_code);
      });
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

const actions = {
  getCannedResponse: async function getCannedResponse(
    { commit },
    { searchKey } = {}
  ) {
    commit(types.default.SET_CANNED_UI_FLAG, { fetchingList: true });
    try {
      const response = await CannedResponseAPI.get({ searchKey });
      commit(types.default.SET_CANNED, response.data);
      commit(types.default.SET_CANNED_UI_FLAG, { fetchingList: false });
    } catch (error) {
      commit(types.default.SET_CANNED_UI_FLAG, { fetchingList: false });
    }
  },

  createCannedResponse: async function createCannedResponse(
    { commit },
    cannedObj
  ) {
    commit(types.default.SET_CANNED_UI_FLAG, { creatingItem: true });
    try {
      const payload = {
        canned_response: {
          ...cannedObj,
          label_ids: normalizeCannedLabelIds(cannedObj.label_ids),
        },
      };
      const response = await CannedResponseAPI.create(payload);
      commit(types.default.ADD_CANNED, response.data);
      commit(types.default.SET_CANNED_UI_FLAG, { creatingItem: false });
      return response.data;
    } catch (error) {
      commit(types.default.SET_CANNED_UI_FLAG, { creatingItem: false });
      return throwErrorMessage(error);
    }
  },

  updateCannedResponse: async function updateCannedResponse(
    { commit },
    { id, ...updateObj }
  ) {
    commit(types.default.SET_CANNED_UI_FLAG, { updatingItem: true });
    try {
      const payload = {
        canned_response: {
          ...updateObj,
          label_ids: normalizeCannedLabelIds(updateObj.label_ids),
        },
      };
      const response = await CannedResponseAPI.update(id, payload);
      commit(types.default.EDIT_CANNED, response.data);
      commit(types.default.SET_CANNED_UI_FLAG, { updatingItem: false });
      return response.data;
    } catch (error) {
      commit(types.default.SET_CANNED_UI_FLAG, { updatingItem: false });
      return throwErrorMessage(error);
    }
  },

  importCannedResponsesTable: async function importCannedResponsesTable(
    { commit, dispatch },
    file
  ) {
    commit(types.default.SET_CANNED_UI_FLAG, { importingTable: true });
    try {
      const response = await CannedResponseAPI.importTable(file);
      await dispatch('getCannedResponse');
      commit(types.default.SET_CANNED_UI_FLAG, { importingTable: false });
      return response.data;
    } catch (error) {
      commit(types.default.SET_CANNED_UI_FLAG, { importingTable: false });
      return throwErrorMessage(error);
    }
  },

  deleteCannedResponse: async function deleteCannedResponse({ commit }, id) {
    commit(types.default.SET_CANNED_UI_FLAG, { deletingItem: true });
    try {
      await CannedResponseAPI.delete(id);
      commit(types.default.DELETE_CANNED, id);
      commit(types.default.SET_CANNED_UI_FLAG, { deletingItem: true });
      return id;
    } catch (error) {
      commit(types.default.SET_CANNED_UI_FLAG, { deletingItem: true });
      return throwErrorMessage(error);
    }
  },
};

const mutations = {
  [types.default.SET_CANNED_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.default.SET_CANNED]: MutationHelpers.set,
  [types.default.ADD_CANNED]: MutationHelpers.create,
  [types.default.EDIT_CANNED]: MutationHelpers.update,
  [types.default.DELETE_CANNED]: MutationHelpers.destroy,
};

export default {
  state,
  getters,
  actions,
  mutations,
};
