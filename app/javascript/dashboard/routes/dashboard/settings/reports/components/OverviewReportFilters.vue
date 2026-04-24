<script setup>
import { ref, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import subDays from 'date-fns/subDays';
import differenceInCalendarDays from 'date-fns/differenceInCalendarDays';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import V4Button from 'dashboard/components-next/button/Button.vue';
import {
  generateReportURLParams,
  parseReportURLParams,
  MAX_COMPARISON_PERIODS,
} from '../helpers/reportFilterHelper';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';

defineProps({
  disabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['filterChange']);

const route = useRoute();
const router = useRouter();

const customDateRange = ref([subDays(new Date(), 6), new Date()]);
const selectedDateRange = ref(DATE_RANGE_TYPES.LAST_7_DAYS);
const businessHoursSelected = ref(false);

const comparisonRanges = ref([]);

const comparisonPeriodsPayload = () =>
  comparisonRanges.value.map(cr => ({
    from: getUnixStartOfDay(cr.dates[0]),
    to: getUnixEndOfDay(cr.dates[1]),
  }));

const addComparisonPeriod = () => {
  if (comparisonRanges.value.length >= MAX_COMPARISON_PERIODS) return;
  const [pStart, pEnd] = customDateRange.value;
  const days = Math.max(differenceInCalendarDays(pEnd, pStart), 1);
  const end = subDays(pStart, 1);
  const start = subDays(end, days);
  comparisonRanges.value = [
    ...comparisonRanges.value,
    {
      dates: [start, end],
      rangeType: DATE_RANGE_TYPES.CUSTOM_RANGE,
    },
  ];
  emitChange();
};

const removeComparisonPeriod = index => {
  comparisonRanges.value = comparisonRanges.value.filter((_, i) => i !== index);
  emitChange();
};

const onComparisonDatesChanged = (index, value) => {
  const [startDate, endDate, rangeType] = value;
  const row = comparisonRanges.value[index];
  if (!row) return;
  row.dates = [startDate, endDate];
  row.rangeType = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  emitChange();
};

const updateURLParams = () => {
  const comparisonPayload = comparisonPeriodsPayload();
  const params = generateReportURLParams({
    from: getUnixStartOfDay(customDateRange.value[0]),
    to: getUnixEndOfDay(customDateRange.value[1]),
    businessHours: businessHoursSelected.value,
    range: selectedDateRange.value,
    comparisonPeriods: comparisonPayload,
  });

  const nextQuery = { ...route.query, ...params };
  if (!comparisonPayload.length) {
    delete nextQuery.comparison_periods;
  }
  router.replace({ query: nextQuery });
};

const emitChange = () => {
  updateURLParams();
  emit('filterChange', {
    from: getUnixStartOfDay(customDateRange.value[0]),
    to: getUnixEndOfDay(customDateRange.value[1]),
    businessHours: businessHoursSelected.value,
    comparisonPeriods: comparisonPeriodsPayload(),
  });
};

const onDateRangeChange = value => {
  const [startDate, endDate, rangeType] = value;
  customDateRange.value = [startDate, endDate];
  selectedDateRange.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  emitChange();
};

const onBusinessHoursToggle = () => {
  emitChange();
};

const initializeFromURL = () => {
  const urlParams = parseReportURLParams(route.query);

  if (urlParams.range) {
    selectedDateRange.value = urlParams.range;
  }

  if (urlParams.from && urlParams.to) {
    customDateRange.value = [
      new Date(urlParams.from * 1000),
      new Date(urlParams.to * 1000),
    ];
  }

  if (urlParams.businessHours) {
    businessHoursSelected.value = urlParams.businessHours;
  }

  if (urlParams.comparisonPeriods?.length) {
    comparisonRanges.value = urlParams.comparisonPeriods.map(p => ({
      dates: [new Date(p.from * 1000), new Date(p.to * 1000)],
      rangeType: DATE_RANGE_TYPES.CUSTOM_RANGE,
    }));
  } else {
    comparisonRanges.value = [];
  }
};

onMounted(() => {
  initializeFromURL();
  emitChange();
});
</script>

<template>
  <div
    class="flex w-full flex-col gap-2"
    :class="{ 'pointer-events-none opacity-50': disabled }"
  >
    <div class="flex shrink-0 items-center gap-1.5">
      <span class="text-sm whitespace-nowrap text-n-slate-11">
        {{ $t('REPORT.BUSINESS_HOURS') }}
      </span>
      <ToggleSwitch
        v-model="businessHoursSelected"
        @change="onBusinessHoursToggle"
      />
    </div>
    <div
      class="flex w-full min-w-0 flex-col flex-wrap items-stretch gap-1 md:flex-row md:items-center md:gap-1.5"
    >
      <div class="min-w-0 flex-1 md:min-w-[12rem]">
        <WootDatePicker
          v-model:date-range="customDateRange"
          v-model:range-type="selectedDateRange"
          @date-range-changed="onDateRangeChange"
        />
      </div>
      <div
        v-for="(cr, idx) in comparisonRanges"
        :key="idx"
        class="flex min-w-0 flex-1 items-center gap-1 md:min-w-[12rem]"
      >
        <div class="min-w-0 flex-1">
          <WootDatePicker
            v-model:date-range="cr.dates"
            v-model:range-type="cr.rangeType"
            panel-align="end"
            @date-range-changed="v => onComparisonDatesChanged(idx, v)"
          />
        </div>
        <V4Button
          v-tooltip.top="$t('REPORT.COMPARISON.REMOVE')"
          size="xs"
          variant="faded"
          color="slate"
          icon="i-ph-x"
          class="shrink-0"
          @click="removeComparisonPeriod(idx)"
        />
      </div>
    </div>
    <V4Button
      v-if="comparisonRanges.length < MAX_COMPARISON_PERIODS"
      :label="$t('REPORT.COMPARISON.ADD')"
      size="xs"
      variant="faded"
      color="blue"
      icon="i-ph-plus"
      class="self-start"
      @click="addComparisonPeriod"
    />
  </div>
</template>
