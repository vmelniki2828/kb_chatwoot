export const MAX_COMPARISON_PERIODS = 1;

export const generateReportURLParams = ({
  from,
  to,
  businessHours,
  groupBy,
  range,
  comparisonPeriods,
}) => {
  const params = {};

  if (from) params.from = from;
  if (to) params.to = to;

  if (businessHours) params.business_hours = 'true';
  if (groupBy) params.group_by = groupBy;

  if (range) params.range = range;

  if (comparisonPeriods?.length) {
    params.comparison_periods = JSON.stringify(
      comparisonPeriods.slice(0, MAX_COMPARISON_PERIODS).map(p => ({
        since: p.from,
        until: p.to,
      }))
    );
  }

  return params;
};

export const parseReportURLParams = query => {
  const { from, to, business_hours, group_by, range, comparison_periods } =
    query;

  return {
    from: from ? Number(from) : null,
    to: to ? Number(to) : null,
    businessHours: business_hours === 'true',
    groupBy: group_by ? Number(group_by) : null,
    range: range || null,
    comparisonPeriods: parseComparisonPeriodsQueryValue(comparison_periods),
  };
};

export const parseComparisonPeriodsQueryValue = raw => {
  if (!raw || typeof raw !== 'string') return [];

  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];

    return parsed
      .slice(0, MAX_COMPARISON_PERIODS)
      .map(p => ({
        from: Number(p.since ?? p.from),
        to: Number(p.until ?? p.to),
      }))
      .filter(p => p.from > 0 && p.to > 0);
  } catch {
    return [];
  }
};

// Parse filter params from URL (agent_id, inbox_id, team_id, sla_policy_id, label, rating)
export const parseFilterURLParams = query => {
  return {
    agent_id: query.agent_id ? Number(query.agent_id) : null,
    inbox_id: query.inbox_id ? Number(query.inbox_id) : null,
    team_id: query.team_id ? Number(query.team_id) : null,
    sla_policy_id: query.sla_policy_id ? Number(query.sla_policy_id) : null,
    label: query.label || null,
    rating: query.rating ? Number(query.rating) : null,
  };
};

// Generate filter URL params (only include non-null values)
export const generateFilterURLParams = filters => {
  const params = {};
  if (filters.agent_id) params.agent_id = filters.agent_id;
  if (filters.inbox_id) params.inbox_id = filters.inbox_id;
  if (filters.team_id) params.team_id = filters.team_id;
  if (filters.sla_policy_id) params.sla_policy_id = filters.sla_policy_id;
  if (filters.label) params.label = filters.label;
  if (filters.rating) params.rating = filters.rating;
  return params;
};

// Merge date range and filter params for complete URL
export const generateCompleteURLParams = ({
  from,
  to,
  range,
  filters = {},
  comparisonPeriods,
}) => {
  const dateParams = generateReportURLParams({
    from,
    to,
    range,
    comparisonPeriods,
  });
  const filterParams = generateFilterURLParams(filters);
  return { ...dateParams, ...filterParams };
};
