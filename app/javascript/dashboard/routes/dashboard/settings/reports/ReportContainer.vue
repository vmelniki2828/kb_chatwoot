<script>
import { mapGetters } from 'vuex';
import { useReportMetrics } from 'dashboard/composables/useReportMetrics';
import {
  GROUP_BY_FILTER,
  METRIC_CHART,
  DEFAULT_BAR_CHART,
  DEFAULT_LINE_CHART,
} from './constants';
import fromUnixTime from 'date-fns/fromUnixTime';
import format from 'date-fns/format';
import { formatTime } from '@chatwoot/utils';
import ChartStats from './components/ChartElements/ChartStats.vue';
import BarChart from 'shared/components/charts/BarChart.vue';

const COMPARISON_PALETTE = [
  { bar: 'rgba(59, 130, 246, 0.55)', line: '#3b82f6' },
  { bar: 'rgba(245, 158, 11, 0.55)', line: '#f59e0b' },
];

export default {
  components: { ChartStats, BarChart },
  props: {
    groupBy: {
      type: Object,
      default: () => ({}),
    },
    comparisonPeriods: {
      type: Array,
      default: () => [],
    },
    mainFrom: {
      type: Number,
      default: 0,
    },
    mainTo: {
      type: Number,
      default: 0,
    },
    accountSummaryKey: {
      type: String,
      default: 'getAccountSummary',
    },
    summaryFetchingKey: {
      type: String,
      default: 'getAccountSummaryFetchingStatus',
    },
    reportKeys: {
      type: Object,
      default: () => ({
        CONVERSATIONS: 'conversations_count',
        INCOMING_MESSAGES: 'incoming_messages_count',
        OUTGOING_MESSAGES: 'outgoing_messages_count',
        FIRST_RESPONSE_TIME: 'avg_first_response_time',
        RESOLUTION_TIME: 'avg_resolution_time',
        CHAT_DURATION_WITH_BOT: 'avg_chat_duration_with_bot',
        CHAT_DURATION_OPERATORS_ONLY: 'avg_chat_duration_operators_only',
        RESOLUTION_COUNT: 'resolutions_count',
        REPLY_TIME: 'reply_time',
      }),
    },
  },
  setup(props) {
    const {
      calculateTrend,
      isAverageMetricType,
      comparisonTrendDetails,
    } = useReportMetrics(props.accountSummaryKey, props.summaryFetchingKey);
    return { calculateTrend, isAverageMetricType, comparisonTrendDetails };
  },
  computed: {
    ...mapGetters({
      accountReport: 'getAccountReports',
    }),
    showComparisonLegend() {
      return this.comparisonPeriods.length > 0;
    },
    metrics() {
      const reportKeys = Object.keys(this.reportKeys);
      const infoText = {
        FIRST_RESPONSE_TIME: this.$t(
          `REPORT.METRICS.FIRST_RESPONSE_TIME.INFO_TEXT`
        ),
        RESOLUTION_TIME: this.$t(`REPORT.METRICS.RESOLUTION_TIME.INFO_TEXT`),
        CHAT_DURATION_WITH_BOT: this.$t(
          `REPORT.METRICS.CHAT_DURATION_WITH_BOT.INFO_TEXT`
        ),
        CHAT_DURATION_OPERATORS_ONLY: this.$t(
          `REPORT.METRICS.CHAT_DURATION_OPERATORS_ONLY.INFO_TEXT`
        ),
      };
      return reportKeys.map(key => ({
        NAME: this.$t(`REPORT.METRICS.${key}.NAME`),
        KEY: this.reportKeys[key],
        DESC: this.$t(`REPORT.METRICS.${key}.DESC`),
        INFO_TEXT: infoText[key],
        TOOLTIP_TEXT: `REPORT.METRICS.${key}.TOOLTIP_TEXT`,
        trend: this.calculateTrend(this.reportKeys[key]),
        comparisonTrends: this.comparisonTrendDetails(this.reportKeys[key]),
      }));
    },
  },
  methods: {
    formatLegendRange(fromUnix, toUnix) {
      try {
        return `${format(fromUnixTime(fromUnix), 'dd MMM')} – ${format(
          fromUnixTime(toUnix),
          'dd MMM'
        )}`;
      } catch {
        return '';
      }
    },
    legendLabelForSeries(isPrimary, compIndex) {
      if (isPrimary) {
        if (this.mainFrom && this.mainTo) {
          return `${this.$t('REPORT.COMPARISON.LEGEND_BASE')}: ${this.formatLegendRange(
            this.mainFrom,
            this.mainTo
          )}`;
        }
        return this.$t('REPORT.COMPARISON.LEGEND_BASE');
      }
      const p = this.comparisonPeriods[compIndex];
      if (p?.from && p?.to) {
        return `${this.$t('REPORT.COMPARISON.LEGEND_EXTRA', {
          n: compIndex + 1,
        })}: ${this.formatLegendRange(p.from, p.to)}`;
      }
      return this.$t('REPORT.COMPARISON.LEGEND_EXTRA', {
        n: compIndex + 1,
      });
    },
    comparisonLegendItems() {
      const items = [
        {
          key: 'base',
          color: DEFAULT_LINE_CHART.borderColor,
          label: this.legendLabelForSeries(true, 0),
        },
      ];
      this.comparisonPeriods.forEach((_, idx) => {
        const pal = COMPARISON_PALETTE[idx % COMPARISON_PALETTE.length];
        items.push({
          key: `cmp-${idx}`,
          color: pal.line,
          label: this.legendLabelForSeries(false, idx),
        });
      });
      return items;
    },
    alignSeriesToPrimary(primary, other) {
      if (!primary?.length) return [];
      const len = primary.length;
      return Array.from({ length: len }, (_, i) => {
        if (other?.[i]) return other[i];
        return {
          timestamp: primary[i].timestamp,
          value: 0,
          count: 0,
        };
      });
    },
    bucketLabel(element) {
      if (this.groupBy?.period === GROUP_BY_FILTER[5].period) {
        return format(fromUnixTime(element.timestamp), 'dd MMM yyyy, HH:mm');
      }
      if (this.groupBy?.period === GROUP_BY_FILTER[2].period) {
        const weekDate = new Date(fromUnixTime(element.timestamp));
        const firstDay = weekDate.getDate() - weekDate.getDay();
        const lastDay = firstDay + 6;
        const weekFirstDate = new Date(weekDate.setDate(firstDay));
        const weekLastDate = new Date(weekDate.setDate(lastDay));
        return `${format(weekFirstDate, 'dd-MMM')} - ${format(
          weekLastDate,
          'dd-MMM'
        )}`;
      }
      if (this.groupBy?.period === GROUP_BY_FILTER[3].period) {
        return format(fromUnixTime(element.timestamp), 'MMM-yyyy');
      }
      if (this.groupBy?.period === GROUP_BY_FILTER[4].period) {
        return format(fromUnixTime(element.timestamp), 'yyyy');
      }
      return format(fromUnixTime(element.timestamp), 'dd-MMM');
    },
    getCollection(metric) {
      if (!this.accountReport.data[metric.KEY]) {
        return {};
      }
      const primaryData = this.accountReport.data[metric.KEY];
      const comparisonSeries =
        this.accountReport.comparisonSeries[metric.KEY] || [];
      const labels = primaryData.map(el => this.bucketLabel(el));

      const buildForTemplate = (template, sourceRows, style, legendLabel) => {
        const base = { ...template, yAxisID: 'y', label: legendLabel };
        if (template.type === 'bar') {
          return {
            ...base,
            backgroundColor: style.bar,
            comparisonPoints: sourceRows,
            data: sourceRows.map(element => element.value),
          };
        }
        if (template.type === 'line') {
          return {
            ...base,
            borderColor: style.line,
            pointBackgroundColor: style.line,
            comparisonPoints: sourceRows,
            data: sourceRows.map(element => element.count),
          };
        }
        return base;
      };

      const primaryStyle = {
        bar: DEFAULT_BAR_CHART.backgroundColor,
        line: DEFAULT_LINE_CHART.borderColor,
      };

      const datasets = [];
      METRIC_CHART[metric.KEY].datasets.forEach(template => {
        datasets.push(
          buildForTemplate(
            template,
            primaryData,
            primaryStyle,
            this.legendLabelForSeries(true, 0)
          )
        );
        comparisonSeries.forEach((series, idx) => {
          const aligned = this.alignSeriesToPrimary(primaryData, series);
          const pal = COMPARISON_PALETTE[idx % COMPARISON_PALETTE.length];
          datasets.push(
            buildForTemplate(
              template,
              aligned,
              { bar: pal.bar, line: pal.line },
              this.legendLabelForSeries(false, idx)
            )
          );
        });
      });

      return {
        labels,
        datasets,
      };
    },
    getChartOptions(metric) {
      const options = {
        scales: METRIC_CHART[metric.KEY].scales,
      };

      if (this.isAverageMetricType(metric.KEY)) {
        options.plugins = {
          tooltip: {
            callbacks: {
              label: ctx => {
                const row = ctx.dataset.comparisonPoints?.[ctx.dataIndex];
                const count = row?.count ?? 0;
                return this.$t(metric.TOOLTIP_TEXT, {
                  metricValue: formatTime(ctx.raw || 0),
                  conversationCount: count,
                });
              },
            },
          },
        };
      }

      return options;
    },
  },
};
</script>

<template>
  <div
    class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-2 px-6 py-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 mt-4"
  >
    <div
      v-for="metric in metrics"
      :key="metric.KEY"
      class="p-4 mb-3 rounded-md"
    >
      <ChartStats
        :metric="metric"
        :account-summary-key="accountSummaryKey"
        :summary-fetching-key="summaryFetchingKey"
      />
      <div class="mt-4 h-72">
        <woot-loading-state
          v-if="accountReport.isFetching[metric.KEY]"
          class="text-xs"
          :message="$t('REPORT.LOADING_CHART')"
        />
        <div v-else class="flex items-center justify-center h-72">
          <div v-if="accountReport.data[metric.KEY].length" class="h-full w-full">
            <div
              v-if="showComparisonLegend"
              class="mb-2 rounded-md bg-n-alpha-2 px-2 py-1.5 flex flex-wrap gap-x-3 gap-y-1 text-[11px] text-n-slate-11"
            >
              <span
                v-for="item in comparisonLegendItems()"
                :key="`${metric.KEY}-${item.key}`"
                class="inline-flex items-center gap-1.5"
              >
                <span class="h-2.5 w-2.5 rounded-sm" :style="{ backgroundColor: item.color }" />
                <span>{{ item.label }}</span>
              </span>
            </div>
            <BarChart
              :collection="getCollection(metric)"
              :chart-options="getChartOptions(metric)"
              :show-legend="false"
            />
          </div>
          <span v-else class="text-sm text-n-slate-10">
            {{ $t('REPORT.NO_ENOUGH_DATA') }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
