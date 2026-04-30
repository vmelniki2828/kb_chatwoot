<script setup>
import { computed } from 'vue';
import { useMemoize } from '@vueuse/core';
import format from 'date-fns/format';
import { getQuantileIntervals } from '@chatwoot/utils';
import { groupHeatmapByDay } from 'helpers/ReportsDataHelper';
import { useI18n } from 'vue-i18n';
import { useHeatmapTooltip } from './composables/useHeatmapTooltip';
import HeatmapTooltip from './HeatmapTooltip.vue';

const props = defineProps({
  heatmapData: {
    type: Array,
    default: () => [],
  },
  numberOfRows: {
    type: Number,
    default: 7,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  colorScheme: {
    type: String,
    default: 'blue',
    validator: value => ['blue', 'green'].includes(value),
  },
});

const { t } = useI18n();

const HOURS = Array.from({ length: 24 }, (_, i) => i);

const HOUR_LABELS = [
  '12:00 am', '1:00 am', '2:00 am', '3:00 am', '4:00 am', '5:00 am',
  '6:00 am', '7:00 am', '8:00 am', '9:00 am', '10:00 am', '11:00 am',
  '12:00 pm', '1:00 pm', '2:00 pm', '3:00 pm', '4:00 pm', '5:00 pm',
  '6:00 pm', '7:00 pm', '8:00 pm', '9:00 pm', '10:00 pm', '11:00 pm',
];

const SHOW_HOUR_LABEL_INDICES = new Set([0, 3, 6, 9, 12, 15, 18, 21]);

const dataByDay = computed(() => {
  return groupHeatmapByDay(props.heatmapData);
});

const dateKeys = computed(() => {
  return Array.from(dataByDay.value.keys());
});

const matrix = computed(() => {
  return HOURS.map(hour => {
    return dateKeys.value.map(dateKey => {
      const dayData = dataByDay.value.get(dateKey) ?? [];
      const cell = dayData.find(d => new Date(d.timestamp * 1000).getHours() === hour);
      return cell ? cell.value : 0;
    });
  });
});

const quantileRange = computed(() => {
  const flat = props.heatmapData.map(d => d.value);
  return getQuantileIntervals(flat, [0.2, 0.4, 0.6, 0.8, 0.9, 0.99]);
});

const COLOR_SCHEMES = {
  blue: [
    'bg-n-blue-3 border border-n-blue-4/30',
    'bg-n-blue-5 border border-n-blue-6/30',
    'bg-n-blue-7 border border-n-blue-8/30',
    'bg-n-blue-8 border border-n-blue-9/30',
    'bg-n-blue-10 border border-n-blue-8/30',
    'bg-n-blue-11 border border-n-blue-10/30',
  ],
  green: [
    'bg-n-teal-3 border border-n-teal-4/30',
    'bg-n-teal-5 border border-n-teal-6/30',
    'bg-n-teal-7 border border-n-teal-8/30',
    'bg-n-teal-8 border border-n-teal-9/30',
    'bg-n-teal-10 border border-n-teal-8/30',
    'bg-n-teal-11 border border-n-teal-10/30',
  ],
};

const getHeatmapLevelClass = useMemoize((value, quantileRangeArray, colorScheme) => {
  if (!value) return 'border border-n-container bg-n-slate-2 dark:bg-n-slate-1/30';
  let level = [...quantileRangeArray, Infinity].findIndex(range => value <= range && value > 0);
  if (level > 6) level = 5;
  if (level === 0) return 'border border-n-container bg-n-slate-2 dark:bg-n-slate-1/30';
  return COLOR_SCHEMES[colorScheme][level - 1];
});

function getHeatmapClass(value) {
  return getHeatmapLevelClass(value, quantileRange.value, props.colorScheme);
}

function formatDateKey(dateKey) {
  return format(new Date(dateKey), 'dd MMM');
}

const tooltip = useHeatmapTooltip();
</script>

<template>
  <div class="w-full overflow-x-auto">
    <div class="flex flex-row min-w-[500px]">
      <div class="flex flex-col flex-shrink-0 w-16 mt-6">
        <template v-if="isLoading">
          <div
            v-for="i in 24"
            :key="i"
            class="h-5 mb-[3px] rounded-sm bg-n-slate-3 dark:bg-n-slate-1 animate-loader-pulse"
          />
        </template>
        <template v-else>
          <div
            v-for="(hour, i) in HOURS"
            :key="hour"
            class="h-5 mb-[3px] flex items-center justify-end pr-2 text-[9px] font-semibold text-n-slate-11"
          >
            <span v-if="SHOW_HOUR_LABEL_INDICES.has(i)">{{ HOUR_LABELS[i] }}</span>
          </div>
        </template>
      </div>

      <div class="flex flex-row gap-[3px] flex-1">
        <template v-if="isLoading">
          <div
            v-for="col in numberOfRows"
            :key="col"
            class="flex flex-col gap-[3px] flex-1"
          >
            <div class="h-6 rounded-sm bg-n-slate-3 dark:bg-n-slate-1 animate-loader-pulse mb-0.5" />
            <div
              v-for="row in 24"
              :key="row"
              class="h-5 rounded-sm bg-n-slate-3 dark:bg-n-slate-1 animate-loader-pulse"
            />
          </div>
        </template>
        <template v-else>
          <div
            v-for="(dateKey, colIdx) in dateKeys"
            :key="dateKey"
            class="flex flex-col gap-[3px] flex-1 min-w-[36px]"
          >
            <div class="h-6 flex items-center justify-center text-[9px] font-semibold text-n-slate-11 whitespace-nowrap">
              {{ formatDateKey(dateKey) }}
            </div>
            <div
              v-for="(hour, rowIdx) in HOURS"
              :key="hour"
              class="h-5 rounded-sm cursor-pointer"
              :class="getHeatmapClass(matrix[rowIdx][colIdx])"
              @mouseenter="tooltip.show($event, matrix[rowIdx][colIdx])"
              @mouseleave="tooltip.hide"
            />
          </div>
        </template>
      </div>
    </div>

    <HeatmapTooltip
      :visible="tooltip.visible.value"
      :x="tooltip.x.value"
      :y="tooltip.y.value"
      :value="tooltip.value.value"
    />
  </div>
</template>
