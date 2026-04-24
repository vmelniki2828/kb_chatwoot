<script setup>
import { useReportMetrics } from 'dashboard/composables/useReportMetrics';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { STATUS } from 'dashboard/store/constants';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  metric: {
    type: Object,
    default: () => ({}),
  },
  accountSummaryKey: {
    type: String,
    default: 'getAccountSummary',
  },
  summaryFetchingKey: {
    type: String,
    default: 'getAccountSummaryFetchingStatus',
  },
});

const { t } = useI18n();

const {
  calculateTrend,
  hasPreviousValue,
  displayMetric,
  isAverageMetricType,
  fetchingStatus,
} =
  useReportMetrics(props.accountSummaryKey, props.summaryFetchingKey);

const trendColor = (value, key) => {
  if (isAverageMetricType(key)) {
    return value > 0
      ? 'border-n-ruby-9 text-n-ruby-9'
      : 'border-n-teal-10 text-n-teal-10';
  }
  return value < 0
    ? 'border-n-ruby-9 text-n-ruby-9'
    : 'border-n-teal-10 text-n-teal-10';
};

const comparisonDotClass = index => {
  if (index % 2 === 0) return 'bg-n-brand';
  return 'bg-n-yellow-9';
};
</script>

<template>
  <div class="text-n-slate-11">
    <span class="text-sm">
      {{ metric.NAME }}
    </span>
    <div class="flex flex-col gap-1">
      <div class="flex items-end text-n-slate-12">
        <div v-if="fetchingStatus === STATUS.FETCHING">
          <Spinner />
        </div>
        <div
          v-else-if="fetchingStatus === STATUS.FAILED"
          class="text-n-ruby-10 text-sm"
        >
          {{ t('REPORT.SUMMARY_FETCHING_FAILED') }}
        </div>
        <div
          v-else-if="fetchingStatus === STATUS.FINISHED"
          class="text-xl font-medium"
        >
          {{ displayMetric(metric.KEY) }}
        </div>
        <div
          v-if="fetchingStatus === STATUS.FINISHED && hasPreviousValue(metric.KEY)"
          class="text-xs ml-4 flex items-center mb-0.5"
        >
          <div
            v-if="calculateTrend(metric.KEY) < 0"
            class="h-0 w-0 border-x-4 medium border-x-transparent border-t-[8px] mr-1"
            :class="trendColor(calculateTrend(metric.KEY), metric.KEY)"
          />
          <div
            v-else
            class="h-0 w-0 border-x-4 medium border-x-transparent border-b-[8px] mr-1"
            :class="trendColor(calculateTrend(metric.KEY), metric.KEY)"
          />
          <span
            class="font-medium"
            :class="trendColor(calculateTrend(metric.KEY), metric.KEY)"
          >
            {{ t('REPORT.COMPARISON.VS_PREVIOUS', { pct: calculateTrend(metric.KEY) }) }}
          </span>
        </div>
      </div>
      <template v-if="fetchingStatus === STATUS.FINISHED">
        <div
          v-for="ct in metric.comparisonTrends || []"
          :key="ct.index"
          class="text-xs flex items-center gap-2 text-n-slate-10 rounded-md bg-n-alpha-2 px-2 py-1"
        >
          <span class="h-2 w-2 rounded-sm shrink-0" :class="comparisonDotClass(ct.index)" />
          <span class="truncate max-w-[10rem]" :title="ct.label">
            {{ ct.label }}
          </span>
          <span class="flex items-center font-medium text-n-slate-12">
            <span
              v-if="ct.percent < 0"
              class="h-0 w-0 border-x-4 medium border-x-transparent border-t-[8px] mr-1"
              :class="trendColor(ct.percent, metric.KEY)"
            />
            <span
              v-else
              class="h-0 w-0 border-x-4 medium border-x-transparent border-b-[8px] mr-1"
              :class="trendColor(ct.percent, metric.KEY)"
            />
            <span :class="trendColor(ct.percent, metric.KEY)">
              {{ t('REPORT.COMPARISON.VS_PERIOD', { pct: ct.percent }) }}
            </span>
          </span>
        </div>
      </template>
    </div>
  </div>
</template>
