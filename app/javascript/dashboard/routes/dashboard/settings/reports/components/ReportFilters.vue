<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import subDays from 'date-fns/subDays';
import differenceInDays from 'date-fns/differenceInDays';
import differenceInCalendarDays from 'date-fns/differenceInCalendarDays';
import ActiveFilterChip from './Filters/v3/ActiveFilterChip.vue';
import V4Button from 'dashboard/components-next/button/Button.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import { GROUP_BY_FILTER } from '../constants';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';
import {
  generateReportURLParams,
  parseReportURLParams,
  MAX_COMPARISON_PERIODS,
} from '../helpers/reportFilterHelper';

const props = defineProps({
  filterType: {
    type: String,
    required: false,
    default: '',
    validator: value =>
      ['teams', 'inboxes', 'labels', 'agents', ''].includes(value),
  },
  selectedItem: {
    type: Object,
    default: null,
  },
  showGroupBy: {
    type: Boolean,
    default: true,
  },
  showBusinessHours: {
    type: Boolean,
    default: true,
  },
  showEntityFilter: {
    type: Boolean,
    default: true,
  },
  showComparison: {
    type: Boolean,
    default: true,
  },
  multiLabelFilter: {
    type: Boolean,
    default: false,
  },
  selectedLabelIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['filterChange', 'update:selectedLabelIds']);

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const buildReportFilterList = (items, type) => {
  if (!Array.isArray(items)) return [];

  return items.map(item => ({
    id: item.id,
    name: item.name || item.title,
    type,
  }));
};

const getReportFilterKey = filterType => {
  const keyMap = {
    teams: 'team_id',
    inboxes: 'inbox_id',
    labels: 'label_id',
    agents: 'agent_id',
  };
  return keyMap[filterType] || '';
};

const getFilterKey = () => getReportFilterKey(props.filterType);

const showSubDropdownMenu = ref(false);
const showGroupByDropdown = ref(false);
const activeFilterType = ref('');
const customDateRange = ref([subDays(new Date(), 6), new Date()]);
const selectedDateRange = ref(DATE_RANGE_TYPES.LAST_7_DAYS);
const businessHoursSelected = ref(false);
const groupBy = ref(GROUP_BY_FILTER[1]);
const groupByfilterItemsList = ref([{ id: 1, name: 'Day' }]);

const comparisonRanges = ref([]);

const comparisonPeriodsPayload = () => {
  if (!props.showComparison) return [];

  return comparisonRanges.value.map(cr => ({
    from: getUnixStartOfDay(cr.dates[0]),
    to: getUnixEndOfDay(cr.dates[1]),
  }));
};

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

const appliedFilters = ref(
  props.showEntityFilter
    ? { [getFilterKey()]: props.selectedItem?.id || null }
    : {}
);

const filterSource = computed(() => {
  const sources = {
    teams: store.getters['teams/getTeams'],
    inboxes: store.getters['inboxes/getInboxes'],
    labels: store.getters['labels/getLabels'],
    agents: store.getters['agents/getAgents'],
  };
  return sources[props.filterType] || [];
});

const from = computed(() => getUnixStartOfDay(customDateRange.value[0]));
const to = computed(() => getUnixEndOfDay(customDateRange.value[1]));

const daysDifference = computed(() => {
  return differenceInDays(customDateRange.value[1], customDateRange.value[0]);
});

/** Показывать «Group by»: длинные периоды (неделя/месяц) или короткие (день/час). */
const MAX_DAY_SPAN_FOR_HOURLY_GROUPING = 13;

const isGroupByPossible = computed(() => {
  if (!props.showGroupBy) return false;
  const days = daysDifference.value;
  return days >= 29 || days <= MAX_DAY_SPAN_FOR_HOURLY_GROUPING;
});

const GROUP_BY_OPTIONS = computed(() => ({
  WEEK: [
    { id: 1, name: t('REPORT.GROUPING_OPTIONS.DAY') },
    { id: 2, name: t('REPORT.GROUPING_OPTIONS.WEEK') },
  ],
  MONTH: [
    { id: 1, name: t('REPORT.GROUPING_OPTIONS.DAY') },
    { id: 2, name: t('REPORT.GROUPING_OPTIONS.WEEK') },
    { id: 3, name: t('REPORT.GROUPING_OPTIONS.MONTH') },
  ],
  YEAR: [
    { id: 2, name: t('REPORT.GROUPING_OPTIONS.WEEK') },
    { id: 3, name: t('REPORT.GROUPING_OPTIONS.MONTH') },
    { id: 4, name: t('REPORT.GROUPING_OPTIONS.YEAR') },
  ],
}));

const fetchFilterItems = () => {
  const days = daysDifference.value;
  if (days <= MAX_DAY_SPAN_FOR_HOURLY_GROUPING) {
    return [
      { id: 1, name: t('REPORT.GROUPING_OPTIONS.DAY') },
      { id: 5, name: t('REPORT.GROUPING_OPTIONS.HOUR') },
    ];
  }
  if (days >= 364) return GROUP_BY_OPTIONS.value.YEAR;
  if (days >= 90) return GROUP_BY_OPTIONS.value.MONTH;
  if (days >= 29) return GROUP_BY_OPTIONS.value.WEEK;
  return [{ id: 1, name: t('REPORT.GROUPING_OPTIONS.DAY') }];
};

const filterOptions = computed(() =>
  buildReportFilterList(filterSource.value, props.filterType)
);

const labelMultiSelectOptions = computed(() =>
  filterOptions.value.map(o => ({ value: o.id, label: o.name }))
);

const filterPlaceholder = computed(() => {
  const placeholders = {
    teams: 'TEAM_REPORTS.FILTERS.INPUT_PLACEHOLDER.TEAMS',
    inboxes: 'INBOX_REPORTS.FILTERS.INPUT_PLACEHOLDER.INBOXES',
    labels: 'LABEL_REPORTS.FILTERS.INPUT_PLACEHOLDER.LABELS',
    agents: 'AGENT_REPORTS.FILTERS.INPUT_PLACEHOLDER.AGENTS',
  };
  return t(placeholders[props.filterType] || '');
});

const defaultFilterLabel = computed(() => {
  const labelKeys = {
    teams: 'TEAM_REPORTS.FILTER_DROPDOWN_LABEL',
    inboxes: 'INBOX_REPORTS.FILTER_DROPDOWN_LABEL',
    labels: 'LABEL_REPORTS.FILTER_DROPDOWN_LABEL',
    agents: 'AGENT_REPORTS.FILTER_DROPDOWN_LABEL',
  };
  return t(labelKeys[props.filterType] || 'FORMS.MULTISELECT.SELECT_ONE');
});

const selectedFilterName = computed(() => {
  const filterKey = getFilterKey();
  const selectedId = appliedFilters.value[filterKey];

  if (!selectedId) {
    return defaultFilterLabel.value;
  }

  const selectedItem = filterOptions.value.find(item => item.id === selectedId);
  return selectedItem?.name || defaultFilterLabel.value;
});

const updateURLParams = () => {
  const comparisonPayload = comparisonPeriodsPayload();
  const params = generateReportURLParams({
    from: from.value,
    to: to.value,
    businessHours: businessHoursSelected.value,
    groupBy: isGroupByPossible.value ? groupBy.value.id : null,
    range: selectedDateRange.value,
    comparisonPeriods: comparisonPayload,
  });

  const nextQuery = { ...route.query, ...params };
  if (!comparisonPayload.length) {
    delete nextQuery.comparison_periods;
  }
  router.replace({ query: nextQuery });
};

const labelIdsForPayload = () => {
  const fromProp = props.selectedLabelIds || [];
  if (fromProp.length) return [...fromProp];
  if (route.params.id) return [Number(route.params.id)];
  return [];
};

const emitChange = (options = {}) => {
  const { labelIdsOverride } = options;
  const payload = {
    from: from.value,
    to: to.value,
    businessHours: businessHoursSelected.value,
  };

  if (props.showGroupBy) {
    // Always emit groupBy, default to day when range is too short
    payload.groupBy = isGroupByPossible.value
      ? groupBy.value
      : GROUP_BY_FILTER[1];
  }

  payload.comparisonPeriods = comparisonPeriodsPayload();

  if (props.showEntityFilter) {
    if (props.multiLabelFilter && props.filterType === 'labels') {
      const ids =
        labelIdsOverride !== undefined
          ? labelIdsOverride
          : labelIdsForPayload();
      if (ids.length) {
        payload.labels = { id: ids[0] };
        payload.labelIds = ids;
      }
    } else {
      const filterKey = getFilterKey();
      const selectedValue = appliedFilters.value[filterKey];

      if (selectedValue) {
        payload[props.filterType] =
          props.filterType === 'agents'
            ? [{ id: selectedValue }]
            : { id: selectedValue };
      }
    }
  }

  updateURLParams();
  emit('filterChange', payload);
};

const onMultiLabelIdsUpdate = ids => {
  emit('update:selectedLabelIds', ids);
  emitChange({ labelIdsOverride: ids });
};

const closeActiveFilterDropdown = () => {
  showSubDropdownMenu.value = false;
  activeFilterType.value = '';
};

const openActiveFilterDropdown = filterType => {
  showGroupByDropdown.value = false;
  activeFilterType.value = filterType;
  showSubDropdownMenu.value = !showSubDropdownMenu.value;
};

const addFilter = item => {
  const filterKey = getFilterKey();
  appliedFilters.value[filterKey] = item.id;
  closeActiveFilterDropdown();
  emitChange();

  // Navigate to the new entity's route
  const routeNameMap = {
    teams: 'team_reports_show',
    inboxes: 'inbox_reports_show',
    labels: 'label_reports_show',
    agents: 'agent_reports_show',
  };

  const routeName = routeNameMap[props.filterType];
  if (routeName) {
    router.push({
      name: routeName,
      params: { ...route.params, id: item.id },
      query: route.query,
    });
  }
};

const onDateRangeChange = value => {
  const [startDate, endDate, rangeType] = value;
  customDateRange.value = [startDate, endDate];
  selectedDateRange.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  groupByfilterItemsList.value = fetchFilterItems();
  const filterItems = groupByfilterItemsList.value.filter(
    item => item.id === groupBy.value.id
  );
  if (filterItems.length === 0) {
    groupBy.value = GROUP_BY_FILTER[groupByfilterItemsList.value[0].id];
  }
  emitChange();
};

const onBusinessHoursToggle = () => {
  emitChange();
};

const onGroupByFilterChange = payload => {
  groupBy.value = GROUP_BY_FILTER[payload.id];
  showGroupByDropdown.value = false;
  emitChange();
};

const toggleGroupByDropdown = () => {
  showGroupByDropdown.value = !showGroupByDropdown.value;
};

const closeGroupByDropdown = () => {
  showGroupByDropdown.value = false;
};

const initializeFromURL = () => {
  const urlParams = parseReportURLParams(route.query);

  // Set the range type first
  if (urlParams.range) {
    selectedDateRange.value = urlParams.range;
  }

  // Restore dates from URL if available
  if (urlParams.from && urlParams.to) {
    customDateRange.value = [
      new Date(urlParams.from * 1000),
      new Date(urlParams.to * 1000),
    ];
  }

  if (urlParams.businessHours) {
    businessHoursSelected.value = urlParams.businessHours;
  }

  if (urlParams.groupBy) {
    const groupByValue = GROUP_BY_FILTER[urlParams.groupBy];
    if (groupByValue) {
      groupBy.value = groupByValue;
    }
  }

  // Initialize entity filter from route params (not URL query)
  if (
    props.showEntityFilter &&
    route.params.id &&
    !(props.multiLabelFilter && props.filterType === 'labels')
  ) {
    const filterKey = getFilterKey();
    appliedFilters.value[filterKey] = Number(route.params.id);
  }

  if (!props.showComparison) {
    comparisonRanges.value = [];
  } else if (urlParams.comparisonPeriods?.length) {
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
  groupByfilterItemsList.value = fetchFilterItems();
  const validIds = groupByfilterItemsList.value.filter(
    item => item.id === groupBy.value.id
  );
  if (validIds.length === 0) {
    groupBy.value = GROUP_BY_FILTER[groupByfilterItemsList.value[0].id];
  }
  emitChange();
});
</script>

<template>
  <div class="flex w-full flex-col gap-3">
    <div
      v-if="showBusinessHours || isGroupByPossible"
      class="flex flex-wrap items-center gap-x-4 gap-y-2"
    >
      <div
        v-if="showBusinessHours"
        class="flex shrink-0 items-center gap-1.5"
      >
        <span class="text-sm whitespace-nowrap text-n-slate-11">
          {{ $t('REPORT.BUSINESS_HOURS') }}
        </span>
        <ToggleSwitch
          v-model="businessHoursSelected"
          @change="onBusinessHoursToggle"
        />
      </div>
      <ActiveFilterChip
        v-if="isGroupByPossible"
        :id="groupBy?.id"
        :name="
          groupByfilterItemsList.find(item => item.id === groupBy?.id)?.name ||
          $t('REPORT.GROUP_BY_FILTER_DROPDOWN_LABEL')
        "
        type="groupBy"
        :options="groupByfilterItemsList"
        :active-filter-type="showGroupByDropdown ? 'groupBy' : ''"
        :show-menu="showGroupByDropdown"
        :placeholder="$t('REPORT.GROUP_BY_FILTER_DROPDOWN_LABEL')"
        :enable-search="false"
        :show-clear-filter="false"
        @toggle-dropdown="toggleGroupByDropdown"
        @close-dropdown="closeGroupByDropdown"
        @add-filter="onGroupByFilterChange"
        @remove-filter="() => {}"
      />
    </div>

    <div class="flex w-full flex-col gap-2 lg:flex-row lg:items-start">
      <div class="flex min-w-0 flex-1 flex-col gap-2">
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
          <template v-if="showComparison">
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
          </template>
        </div>
        <V4Button
          v-if="showComparison && comparisonRanges.length < MAX_COMPARISON_PERIODS"
          :label="$t('REPORT.COMPARISON.ADD')"
          size="xs"
          variant="faded"
          color="blue"
          icon="i-ph-plus"
          class="self-start"
          @click="addComparisonPeriod"
        />
      </div>

      <div class="flex min-w-0 flex-wrap items-center gap-2 lg:max-w-[50%]">
        <ActiveFilterChip
          v-if="
            showEntityFilter &&
            !(multiLabelFilter && filterType === 'labels')
          "
          :id="appliedFilters[getFilterKey()]"
          :name="selectedFilterName"
          :type="filterType"
          :options="filterOptions"
          :active-filter-type="activeFilterType"
          :show-menu="showSubDropdownMenu"
          :placeholder="filterPlaceholder"
          :show-clear-filter="false"
          enable-search
          @toggle-dropdown="openActiveFilterDropdown"
          @close-dropdown="closeActiveFilterDropdown"
          @add-filter="addFilter"
        />
        <TagMultiSelectComboBox
          v-else-if="
            showEntityFilter && multiLabelFilter && filterType === 'labels'
          "
          class="min-w-0 flex-1 max-w-xl"
          :model-value="selectedLabelIds"
          :options="labelMultiSelectOptions"
          :placeholder="$t('LABEL_REPORTS.OVERVIEW_MULTI_LABEL_PLACEHOLDER')"
          :search-placeholder="
            $t('LABEL_REPORTS.FILTERS.INPUT_PLACEHOLDER.LABELS')
          "
          @update:model-value="onMultiLabelIdsUpdate"
        />
      </div>
    </div>
  </div>
</template>
