<script setup>
import { computed } from 'vue';
import { Bar } from 'vue-chartjs';
import {
  Chart as ChartJS,
  Title,
  Tooltip,
  BarElement,
  CategoryScale,
  LinearScale,
} from 'chart.js';

const props = defineProps({
  collection: {
    type: Object,
    default: () => ({}),
  },
  chartOptions: {
    type: Object,
    default: () => ({}),
  },
  showLegend: {
    type: Boolean,
    default: false,
  },
});

ChartJS.register(Title, Tooltip, BarElement, CategoryScale, LinearScale);

const fontFamily =
  'Inter,-apple-system,system-ui,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif';

const defaultChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  legend: {
    display: false,
    position: 'bottom',
    labels: {
      fontFamily,
      boxWidth: 12,
    },
  },
  animation: {
    duration: 0,
  },
  datasets: {
    bar: {
      barPercentage: 1.0,
      borderRadius: 6,
      borderSkipped: false,
    },
  },
  scales: {
    x: {
      ticks: {
        fontFamily: fontFamily,
      },
      grid: {
        drawOnChartArea: false,
      },
    },
    y: {
      type: 'linear',
      position: 'left',
      ticks: {
        fontFamily: fontFamily,
        beginAtZero: true,
        stepSize: 1,
      },
      grid: {
        drawOnChartArea: false,
      },
    },
  },
};

const options = computed(() => {
  const merged = { ...defaultChartOptions, ...props.chartOptions };
  merged.legend = {
    ...merged.legend,
    display: props.showLegend,
  };
  return merged;
});
</script>

<template>
  <Bar :data="collection" :options="options" />
</template>
