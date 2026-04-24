/* global axios */
import ApiClient from './ApiClient';

const getTimeOffset = () => -new Date().getTimezoneOffset() / 60;

class ReportsAPI extends ApiClient {
  constructor() {
    super('reports', { accountScoped: true, apiVersion: 'v2' });
  }

  getReports({
    metric,
    from,
    to,
    type = 'account',
    id,
    groupBy,
    businessHours,
    labelIds,
  }) {
    const params = {
      metric,
      since: from,
      until: to,
      type,
      id,
      group_by: groupBy,
      business_hours: businessHours,
      timezone_offset: getTimeOffset(),
    };
    if (labelIds?.length) {
      params.label_ids = labelIds;
    }
    return axios.get(`${this.url}`, { params });
  }

  // eslint-disable-next-line default-param-last
  getSummary(
    since,
    until,
    type = 'account',
    id,
    groupBy,
    businessHours,
    labelIds,
    comparisonPeriods
  ) {
    const params = {
      since,
      until,
      type,
      id,
      group_by: groupBy,
      business_hours: businessHours,
      timezone_offset: getTimeOffset(),
    };
    if (labelIds?.length) {
      params.label_ids = labelIds;
    }
    if (comparisonPeriods?.length) {
      params.comparison_periods = JSON.stringify(
        comparisonPeriods.map(p => ({ since: p.from, until: p.to }))
      );
    }
    return axios.get(`${this.url}/summary`, { params });
  }

  getConversationMetric(type = 'account', page = 1) {
    return axios.get(`${this.url}/conversations`, {
      params: {
        type,
        page,
      },
    });
  }

  getAgentReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/agents`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getConversationsSummaryReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/conversations_summary`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getConversationTrafficCSV({ daysBefore = 6 } = {}) {
    return axios.get(`${this.url}/conversation_traffic`, {
      params: { timezone_offset: getTimeOffset(), days_before: daysBefore },
    });
  }

  getLabelReports({ from: since, to: until, businessHours, labelIds }) {
    const params = { since, until, business_hours: businessHours };
    if (labelIds?.length) {
      params.label_ids = labelIds;
    }
    return axios.get(`${this.url}/labels`, { params });
  }

  getInboxReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/inboxes`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getTeamReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/teams`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getBotMetrics({ from, to } = {}) {
    return axios.get(`${this.url}/bot_metrics`, {
      params: { since: from, until: to },
    });
  }

  getBotSummary({ from, to, groupBy, businessHours, comparisonPeriods } = {}) {
    const params = {
      since: from,
      until: to,
      type: 'account',
      group_by: groupBy,
      business_hours: businessHours,
      timezone_offset: getTimeOffset(),
    };
    if (comparisonPeriods?.length) {
      params.comparison_periods = JSON.stringify(
        comparisonPeriods.map(p => ({ since: p.from, until: p.to }))
      );
    }
    return axios.get(`${this.url}/bot_summary`, { params });
  }

  getAgentActivity({ from: since, to: until, userId }) {
    const params = { since, until };
    if (userId) {
      params.user_id = userId;
    }
    return axios.get(`${this.url}/agent_activity`, { params });
  }
}

export default new ReportsAPI();
