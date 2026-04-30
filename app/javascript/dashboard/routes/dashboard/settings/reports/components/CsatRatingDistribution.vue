<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { Bar } from 'vue-chartjs';
import {
  Chart as ChartJS,
  Title,
  Tooltip,
  BarElement,
  CategoryScale,
  LinearScale,
} from 'chart.js';
import { CSAT_RATINGS } from 'shared/constants/messages';

ChartJS.register(Title, Tooltip, BarElement, CategoryScale, LinearScale);

const props = defineProps({
  ratingPercentage: {
    type: Object,
    default: () => ({}),
  },
  ratingCount: {
    type: Object,
    default: () => ({}),
  },
  totalResponseCount: {
    type: Number,
    default: 0,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();

const fontFamily =
  'Inter,-apple-system,system-ui,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif';

const sortedRatings = computed(() =>
  [...CSAT_RATINGS].sort((a, b) => a.value - b.value)
);

const chartData = computed(() => ({
  labels: sortedRatings.value.map(r => String(r.value)),
  datasets: [
    {
      data: sortedRatings.value.map(r => props.ratingCount[r.value] || 0),
      backgroundColor: sortedRatings.value.map(r => r.color),
      borderRadius: 6,
      borderSkipped: false,
      barPercentage: 0.6,
    },
  ],
}));

const chartOptions = computed(() => ({
  responsive: true,
  maintainAspectRatio: false,
  animation: { duration: 0 },
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        title: context => {
          const rating = sortedRatings.value[context[0].dataIndex];
          return t(rating.translationKey);
        },
        label: context => {
          const rating = sortedRatings.value[context.dataIndex];
          const pct = props.ratingPercentage[rating.value] || 0;
          return ` ${context.parsed.y} (${pct}%)`;
        },
      },
    },
  },
  scales: {
    x: {
      ticks: { fontFamily },
      grid: { drawOnChartArea: false },
      border: { display: false },
    },
    y: {
      ticks: {
        fontFamily,
        beginAtZero: true,
        stepSize: 1,
        precision: 0,
      },
      grid: { drawOnChartArea: false },
      border: { display: false },
    },
  },
}));
</script>

<template>
  <div
    class="shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 px-6 py-5"
  >
    <span class="text-sm font-medium text-n-slate-11">
      {{ $t('CSAT_REPORTS.METRIC.RATING_DISTRIBUTION') }}
    </span>

    <div v-if="isLoading" class="mt-4 h-40">
      <div class="flex items-end gap-3 h-full">
        <div
          v-for="n in 5"
          :key="n"
          class="flex-1 rounded bg-n-slate-3 animate-pulse"
          :style="{ height: `${20 + n * 10}%` }"
        />
      </div>
    </div>

    <div v-else class="mt-4 h-40">
      <Bar :data="chartData" :options="chartOptions" />
    </div>
  </div>
</template>
