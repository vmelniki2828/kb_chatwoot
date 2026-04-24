import SummaryReportsAPI from 'dashboard/api/summaryReports';
import camelcaseKeys from 'camelcase-keys';

const typeMap = {
  inbox: {
    flagKey: 'isFetchingInboxSummaryReports',
    apiMethod: 'getInboxReports',
    mutationKey: 'setInboxSummaryReport',
    comparisonsKey: 'setInboxSummaryComparisons',
  },
  agent: {
    flagKey: 'isFetchingAgentSummaryReports',
    apiMethod: 'getAgentReports',
    mutationKey: 'setAgentSummaryReport',
    comparisonsKey: 'setAgentSummaryComparisons',
  },
  team: {
    flagKey: 'isFetchingTeamSummaryReports',
    apiMethod: 'getTeamReports',
    mutationKey: 'setTeamSummaryReport',
    comparisonsKey: 'setTeamSummaryComparisons',
  },
  label: {
    flagKey: 'isFetchingLabelSummaryReports',
    apiMethod: 'getLabelReports',
    mutationKey: 'setLabelSummaryReport',
    comparisonsKey: 'setLabelSummaryComparisons',
  },
};

async function fetchSummaryReports(type, params, { commit }) {
  const config = typeMap[type];
  if (!config) return;

  let error = null;
  try {
    commit('setUIFlags', { [config.flagKey]: true });
    const response = await SummaryReportsAPI[config.apiMethod](params);
    commit(config.mutationKey, camelcaseKeys(response.data, { deep: true }));

    const periods = params.comparisonPeriods || [];
    if (periods.length) {
      const comparisonResponses = await Promise.all(
        periods.map(p =>
          SummaryReportsAPI[config.apiMethod]({
            since: p.from,
            until: p.to,
            businessHours: params.businessHours,
            labelIds: params.labelIds,
          })
        )
      );
      commit(
        config.comparisonsKey,
        comparisonResponses.map((r, i) => ({
          from: periods[i].from,
          to: periods[i].to,
          data: camelcaseKeys(r.data, { deep: true }),
        }))
      );
    } else {
      commit(config.comparisonsKey, []);
    }
  } catch (e) {
    error = e;
  } finally {
    commit('setUIFlags', { [config.flagKey]: false });
  }
  if (error) throw error;
}

export const initialState = {
  inboxSummaryReports: [],
  agentSummaryReports: [],
  teamSummaryReports: [],
  labelSummaryReports: [],
  inboxSummaryComparisons: [],
  agentSummaryComparisons: [],
  teamSummaryComparisons: [],
  labelSummaryComparisons: [],
  uiFlags: {
    isFetchingInboxSummaryReports: false,
    isFetchingAgentSummaryReports: false,
    isFetchingTeamSummaryReports: false,
    isFetchingLabelSummaryReports: false,
  },
};

export const getters = {
  getInboxSummaryReports(state) {
    return state.inboxSummaryReports;
  },
  getAgentSummaryReports(state) {
    return state.agentSummaryReports;
  },
  getTeamSummaryReports(state) {
    return state.teamSummaryReports;
  },
  getLabelSummaryReports(state) {
    return state.labelSummaryReports;
  },
  getInboxSummaryComparisons(state) {
    return state.inboxSummaryComparisons;
  },
  getAgentSummaryComparisons(state) {
    return state.agentSummaryComparisons;
  },
  getTeamSummaryComparisons(state) {
    return state.teamSummaryComparisons;
  },
  getLabelSummaryComparisons(state) {
    return state.labelSummaryComparisons;
  },
  getUIFlags(state) {
    return state.uiFlags;
  },
};

export const actions = {
  fetchInboxSummaryReports({ commit }, params) {
    return fetchSummaryReports('inbox', params, { commit });
  },

  fetchAgentSummaryReports({ commit }, params) {
    return fetchSummaryReports('agent', params, { commit });
  },

  fetchTeamSummaryReports({ commit }, params) {
    return fetchSummaryReports('team', params, { commit });
  },

  fetchLabelSummaryReports({ commit }, params) {
    return fetchSummaryReports('label', params, { commit });
  },
};

export const mutations = {
  setInboxSummaryReport(state, data) {
    state.inboxSummaryReports = data;
  },
  setAgentSummaryReport(state, data) {
    state.agentSummaryReports = data;
  },
  setTeamSummaryReport(state, data) {
    state.teamSummaryReports = data;
  },
  setLabelSummaryReport(state, data) {
    state.labelSummaryReports = data;
  },
  setInboxSummaryComparisons(state, data) {
    state.inboxSummaryComparisons = data;
  },
  setAgentSummaryComparisons(state, data) {
    state.agentSummaryComparisons = data;
  },
  setTeamSummaryComparisons(state, data) {
    state.teamSummaryComparisons = data;
  },
  setLabelSummaryComparisons(state, data) {
    state.labelSummaryComparisons = data;
  },
  setUIFlags(state, uiFlag) {
    state.uiFlags = { ...state.uiFlags, ...uiFlag };
  },
};

export default {
  namespaced: true,
  state: initialState,
  getters,
  actions,
  mutations,
};
