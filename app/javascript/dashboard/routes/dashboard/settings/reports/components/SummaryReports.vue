<script setup>
import OverviewReportFilters from './OverviewReportFilters.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import { formatTime } from '@chatwoot/utils';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Table from 'dashboard/components/table/Table.vue';
import { generateFileName } from 'dashboard/helper/downloadHelper';
import {
  useVueTable,
  createColumnHelper,
  getCoreRowModel,
} from '@tanstack/vue-table';
import { computed, onMounted, ref, h, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import SummaryReportLink from './SummaryReportLink.vue';
import fromUnixTime from 'date-fns/fromUnixTime';
import format from 'date-fns/format';

const props = defineProps({
  type: {
    type: String,
    default: 'account',
  },
  getterKey: {
    type: String,
    default: '',
  },
  actionKey: {
    type: String,
    default: '',
  },
  summaryKey: {
    type: String,
    default: '',
  },
  fetchItemsKey: {
    type: String,
    required: true,
  },
});

const store = useStore();
const { t } = useI18n();

const from = ref(0);
const to = ref(0);
const businessHours = ref(false);
const selectedLabelIds = ref([]);
const comparisonPeriods = ref([]);

const flagMap = {
  agent: 'isFetchingAgentSummaryReports',
  inbox: 'isFetchingInboxSummaryReports',
  team: 'isFetchingTeamSummaryReports',
  label: 'isFetchingLabelSummaryReports',
};

const uiFlags = useMapGetter('summaryReports/getUIFlags');
const isLoading = computed(() => uiFlags.value[flagMap[props.type]] ?? false);

const rowItems = useMapGetter([props.getterKey]) || [];
const reportMetrics = useMapGetter([props.summaryKey]) || [];

const comparisonsGetterName = computed(() => {
  const map = {
    inbox: 'summaryReports/getInboxSummaryComparisons',
    agent: 'summaryReports/getAgentSummaryComparisons',
    team: 'summaryReports/getTeamSummaryComparisons',
    label: 'summaryReports/getLabelSummaryComparisons',
  };
  return map[props.type];
});

const comparisonSlices = computed(
  () => store.getters[comparisonsGetterName.value] || []
);

const labelFilterOptions = computed(() => {
  if (props.type !== 'label') return [];
  return (rowItems.value || []).map(l => ({
    value: l.id,
    label: l.name ?? l.title,
  }));
});

const visibleRowItems = computed(() => {
  if (props.type !== 'label' || selectedLabelIds.value.length === 0) {
    return rowItems.value;
  }
  const idSet = new Set(selectedLabelIds.value);
  return rowItems.value.filter(row => idSet.has(row.id));
});

const getMetrics = id =>
  reportMetrics.value.find(metrics => metrics.id === Number(id)) || {};

const sliceRowMetrics = (slice, id) =>
  (slice?.data || []).find(m => m.id === Number(id)) || {};

const columnHelper = createColumnHelper();

const defaulSpanRender = cellProps =>
  h(
    'span',
    {
      class: cellProps.getValue() ? '' : 'text-n-slate-12',
    },
    cellProps.getValue()
  );

const renderTimePill = value =>
  value && value !== '--'
    ? h(
        'span',
        {
          class:
            'inline-flex items-center justify-center px-3 py-1 rounded-full bg-n-alpha-2 text-n-slate-12 text-xs font-medium whitespace-nowrap',
        },
        value
      )
    : h(
        'span',
        { class: 'text-n-slate-11 whitespace-nowrap' },
        value || '--'
      );

const renderTimeCell = cellProps => renderTimePill(cellProps.getValue());

const periodShortLabel = (fromUnix, toUnix) => {
  try {
    return `${format(fromUnixTime(fromUnix), 'dd MMM')} – ${format(
      fromUnixTime(toUnix),
      'dd MMM'
    )}`;
  } catch {
    return '';
  }
};

const columns = computed(() => {
  const base = [
    columnHelper.accessor('name', {
      header: t(`SUMMARY_REPORTS.${props.type.toUpperCase()}`),
      //width: 300,
      cell: cellProps => h(SummaryReportLink, cellProps),
    }),
    columnHelper.accessor('conversationsCount', {
      header: t('SUMMARY_REPORTS.CONVERSATIONS'),
      //width: 200,
      cell: defaulSpanRender,
    }),
    columnHelper.accessor('avgFirstResponseTime', {
      header: t('SUMMARY_REPORTS.AVG_FIRST_RESPONSE_TIME'),
      //width: 200,
      cell: renderTimeCell,
    }),
    columnHelper.accessor('avgResolutionTime', {
      header: t('SUMMARY_REPORTS.AVG_RESOLUTION_TIME'),
      //width: 200,
      cell: renderTimeCell,
    }),
    columnHelper.accessor('avgReplyTime', {
      header: t('SUMMARY_REPORTS.AVG_REPLY_TIME'),
      //width: 200,
      cell: renderTimeCell,
    }),
    columnHelper.accessor('resolutionsCount', {
      header: t('SUMMARY_REPORTS.RESOLUTION_COUNT'),
      //width: 200,
      cell: defaulSpanRender,
    }),
  ];

  comparisonSlices.value.forEach((slice, si) => {
    const rh = periodShortLabel(slice.from, slice.to);
    base.push(
      columnHelper.accessor(`cmp${si}_conversationsCount`, {
        id: `cmp${si}_conversationsCount`,
        header: `${t('SUMMARY_REPORTS.CONVERSATIONS')} (${rh})`,
        width: 200,
        cell: defaulSpanRender,
      }),
      columnHelper.accessor(`cmp${si}_avgFirstResponseTime`, {
        id: `cmp${si}_avgFirstResponseTime`,
        header: `${t('SUMMARY_REPORTS.AVG_FIRST_RESPONSE_TIME')} (${rh})`,
        width: 200,
        cell: renderTimeCell,
      }),
      columnHelper.accessor(`cmp${si}_avgResolutionTime`, {
        id: `cmp${si}_avgResolutionTime`,
        header: `${t('SUMMARY_REPORTS.AVG_RESOLUTION_TIME')} (${rh})`,
        width: 200,
        cell: renderTimeCell,
      }),
      columnHelper.accessor(`cmp${si}_avgReplyTime`, {
        id: `cmp${si}_avgReplyTime`,
        header: `${t('SUMMARY_REPORTS.AVG_REPLY_TIME')} (${rh})`,
        width: 200,
        cell: renderTimeCell,
      }),
      columnHelper.accessor(`cmp${si}_resolutionsCount`, {
        id: `cmp${si}_resolutionsCount`,
        header: `${t('SUMMARY_REPORTS.RESOLUTION_COUNT')} (${rh})`,
        width: 200,
        cell: defaulSpanRender,
      })
    );
  });

  return base;
});

const renderAvgTime = value => (value ? formatTime(value) : '--');

const renderCount = value => (value ? value.toLocaleString() : '--');

const tableData = computed(() =>
  visibleRowItems.value.map(row => {
    const rowMetrics = getMetrics(row.id);
    const {
      conversationsCount,
      avgFirstResponseTime,
      avgResolutionTime,
      avgReplyTime,
      resolvedConversationsCount,
    } = rowMetrics;
    const rowOut = {
      id: row.id,
      name: row.name ?? row.title,
      type: props.type,
      thumbnail: row.thumbnail,
      email: row.email,
      status: row.availability_status,
      conversationsCount: renderCount(conversationsCount),
      avgFirstResponseTime: renderAvgTime(avgFirstResponseTime),
      avgReplyTime: renderAvgTime(avgReplyTime),
      avgResolutionTime: renderAvgTime(avgResolutionTime),
      resolutionsCount: renderCount(resolvedConversationsCount),
    };

    comparisonSlices.value.forEach((slice, si) => {
      const m = sliceRowMetrics(slice, row.id);
      rowOut[`cmp${si}_conversationsCount`] = renderCount(m.conversationsCount);
      rowOut[`cmp${si}_avgFirstResponseTime`] = renderAvgTime(
        m.avgFirstResponseTime
      );
      rowOut[`cmp${si}_avgResolutionTime`] = renderAvgTime(
        m.avgResolutionTime
      );
      rowOut[`cmp${si}_avgReplyTime`] = renderAvgTime(m.avgReplyTime);
      rowOut[`cmp${si}_resolutionsCount`] = renderCount(
        m.resolvedConversationsCount
      );
    });

    return rowOut;
  })
);

const fetchReportsWithRetry = async () => {
  const params = {
    since: from.value,
    until: to.value,
    businessHours: businessHours.value,
  };
  if (props.type === 'label' && selectedLabelIds.value.length > 0) {
    params.labelIds = selectedLabelIds.value;
  }
  if (comparisonPeriods.value.length) {
    params.comparisonPeriods = comparisonPeriods.value;
  }
  try {
    await store.dispatch(props.actionKey, params);
  } catch {
    try {
      await store.dispatch(props.actionKey, params);
    } catch {
      useAlert(t('REPORT.SUMMARY_FETCHING_FAILED'));
    }
  }
};

const fetchAllData = () => {
  store.dispatch(props.fetchItemsKey);
  fetchReportsWithRetry();
};

onMounted(() => fetchAllData());

watch(
  selectedLabelIds,
  () => {
    if (props.type === 'label') {
      fetchReportsWithRetry();
    }
  },
  { deep: true }
);

const onFilterChange = updatedFilter => {
  from.value = updatedFilter.from;
  to.value = updatedFilter.to;
  businessHours.value = updatedFilter.businessHours;
  comparisonPeriods.value = updatedFilter.comparisonPeriods || [];
  fetchAllData();
};

const table = useVueTable({
  get data() {
    return tableData.value;
  },
  get columns() {
    return columns.value;
  },
  enableSorting: false,
  getCoreRowModel: getCoreRowModel(),
});

const downloadReports = () => {
  const dispatchMethods = {
    agent: 'downloadAgentReports',
    label: 'downloadLabelReports',
    inbox: 'downloadInboxReports',
    team: 'downloadTeamReports',
  };
  if (dispatchMethods[props.type]) {
    const fileName = generateFileName({
      type: props.type,
      to: to.value,
      businessHours: businessHours.value,
    });
    const params = {
      from: from.value,
      to: to.value,
      fileName,
      businessHours: businessHours.value,
    };
    if (props.type === 'label' && selectedLabelIds.value.length > 0) {
      params.labelIds = selectedLabelIds.value;
    }
    store.dispatch(dispatchMethods[props.type], params);
  }
};

defineExpose({ downloadReports });
</script>

<template>
  <OverviewReportFilters
    :disabled="isLoading"
    @filter-change="onFilterChange"
  />
  <div
    v-if="type === 'label'"
    class="flex flex-col gap-1 mt-4 w-full max-w-xl"
  >
    <TagMultiSelectComboBox
      v-model="selectedLabelIds"
      :options="labelFilterOptions"
      :placeholder="$t('LABEL_REPORTS.OVERVIEW_MULTI_LABEL_PLACEHOLDER')"
      :search-placeholder="$t('LABEL_REPORTS.FILTERS.INPUT_PLACEHOLDER.LABELS')"
    />
  </div>
  <div
    class="relative flex-1 overflow-auto px-2 py-2 mt-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
  >
    <Table :table="table" />
    <Transition
      enter-active-class="transition-opacity duration-300 ease-out"
      leave-active-class="transition-opacity duration-200 ease-in"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="isLoading"
        class="absolute inset-0 flex justify-center pt-[12.5rem] bg-n-solid-1/70 rounded-xl pointer-events-none"
      >
        <Spinner :size="32" class="text-n-brand" />
      </div>
    </Transition>
  </div>
</template>
