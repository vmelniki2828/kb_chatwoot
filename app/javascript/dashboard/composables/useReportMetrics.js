import { useMapGetter } from 'dashboard/composables/store';
import { formatTime } from '@chatwoot/utils';
import fromUnixTime from 'date-fns/fromUnixTime';
import format from 'date-fns/format';

/**
 * @param {string} [accountSummaryKey='getAccountSummary']
 * @param {string} [summarFetchingKey='getAccountSummaryFetchingStatus']
 */
export function useReportMetrics(
  accountSummaryKey = 'getAccountSummary',
  summarFetchingKey = 'getAccountSummaryFetchingStatus'
) {
  const accountSummary = useMapGetter(accountSummaryKey);
  const fetchingStatus = useMapGetter(summarFetchingKey);

  const calculateTrend = key => {
    if (!hasPreviousValue(key)) return 0;
    const diff =
      accountSummary.value[key] - accountSummary.value.previous[key];
    return Math.round((diff / accountSummary.value.previous[key]) * 100);
  };

  const hasPreviousValue = key => {
    const baseline = accountSummary.value.previous?.[key];
    return baseline !== undefined && baseline !== null && baseline !== 0;
  };

  const percentVersusBase = (key, baselineValue) => {
    if (baselineValue === undefined || baselineValue === null) return null;
    if (!baselineValue) return null;
    const diff = accountSummary.value[key] - baselineValue;
    return Math.round((diff / baselineValue) * 100);
  };

  const comparisonPeriodLabel = (since, until) => {
    if (!since || !until) return '';
    try {
      return `${format(fromUnixTime(since), 'dd MMM')} – ${format(fromUnixTime(until), 'dd MMM')}`;
    } catch {
      return '';
    }
  };

  const comparisonTrendDetails = key => {
    const list = accountSummary.value.comparison_periods;
    if (!Array.isArray(list) || !list.length) return [];

    return list
      .map((comp, index) => {
        const pct = percentVersusBase(key, comp[key]);
        if (pct === null) return null;
        return {
          percent: pct,
          since: comp.since,
          until: comp.until,
          index,
          label: comparisonPeriodLabel(comp.since, comp.until),
        };
      })
      .filter(Boolean);
  };

  const isAverageMetricType = key => {
    return [
      'avg_first_response_time',
      'avg_resolution_time',
      'avg_chat_duration_with_bot',
      'avg_chat_duration_operators_only',
      'reply_time',
    ].includes(key);
  };

  const displayMetric = key => {
    if (isAverageMetricType(key)) {
      return formatTime(accountSummary.value[key]);
    }
    return Number(accountSummary.value[key] || '').toLocaleString();
  };

  return {
    calculateTrend,
    hasPreviousValue,
    comparisonTrendDetails,
    isAverageMetricType,
    displayMetric,
    fetchingStatus,
  };
}
