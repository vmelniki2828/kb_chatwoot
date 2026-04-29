<script>
import V4Button from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import ReportFilters from './ReportFilters.vue';
import ReportContainer from '../ReportContainer.vue';
import { GROUP_BY_FILTER } from '../constants';
import { generateFileName } from '../../../../../helper/downloadHelper';
import ReportHeader from './ReportHeader.vue';

export default {
  components: {
    ReportHeader,
    V4Button,
    ReportFilters,
    ReportContainer,
  },
  props: {
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
    downloadButtonLabel: {
      type: String,
      default: 'Download Reports',
    },
    reportTitle: {
      type: String,
      default: 'Download Reports',
    },
    hasBackButton: {
      type: Boolean,
      default: false,
    },
    selectedItem: {
      type: Object,
      default: null,
    },
  },
  data() {
    return {
      from: 0,
      to: 0,
      selectedFilter: this.selectedItem,
      groupBy: GROUP_BY_FILTER[1],
      businessHours: false,
      comparisonPeriods: [],
      selectedLabelIds:
        this.type === 'label' && this.selectedItem?.id
          ? [this.selectedItem.id]
          : [],
    };
  },
  computed: {
    filterType() {
      const pluralMap = {
        agent: 'agents',
        team: 'teams',
        inbox: 'inboxes',
        label: 'labels',
      };
      return pluralMap[this.type] || this.type;
    },
    filterItemsList() {
      return this.$store.getters[this.getterKey] || [];
    },
    isAgentType() {
      return this.type === 'agent';
    },
    reportKeys() {
      return {
        CONVERSATIONS: 'conversations_count',
        ...(!this.isAgentType && {
          INCOMING_MESSAGES: 'incoming_messages_count',
        }),
        OUTGOING_MESSAGES: 'outgoing_messages_count',
        FIRST_RESPONSE_TIME: 'avg_first_response_time',
        RESOLUTION_TIME: 'avg_resolution_time',
        CHAT_DURATION_WITH_BOT: 'avg_chat_duration_with_bot',
        CHAT_DURATION_OPERATORS_ONLY: 'avg_chat_duration_operators_only',
        RESOLUTION_COUNT: 'resolutions_count',
        REPLY_TIME: 'reply_time',
      };
    },
    labelIdsForApi() {
      if (this.type !== 'label' || !this.selectedLabelIds?.length) {
        return undefined;
      }
      return this.selectedLabelIds;
    },
  },
  watch: {
    selectedItem: {
      immediate: true,
      handler(newItem, oldItem) {
        if (this.type !== 'label' || !newItem?.id) return;
        if (!oldItem || newItem.id !== oldItem.id) {
          this.selectedLabelIds = [newItem.id];
        }
      },
    },
  },
  mounted() {
    this.$store.dispatch(this.actionKey);
  },
  methods: {
    fetchAllData() {
      if (this.selectedFilter) {
        const { from, to, groupBy, businessHours } = this;
        const labelIds = this.labelIdsForApi;
        this.$store.dispatch('fetchAccountSummary', {
          from,
          to,
          type: this.type,
          id: this.selectedFilter.id,
          groupBy: groupBy.period,
          businessHours,
          labelIds,
          comparisonPeriods: this.comparisonPeriods,
        });
        this.fetchChartData();
      }
    },
    fetchChartData() {
      const labelIds = this.labelIdsForApi;
      Object.keys(this.reportKeys).forEach(async key => {
        try {
          const { from, to, groupBy, businessHours } = this;
          this.$store.dispatch('fetchAccountReport', {
            metric: this.reportKeys[key],
            from,
            to,
            type: this.type,
            id: this.selectedFilter.id,
            groupBy: groupBy.period,
            businessHours,
            labelIds,
            comparisonPeriods: this.comparisonPeriods,
          });
        } catch {
          useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
        }
      });
    },
    downloadReports() {
      const { from, to, type, businessHours } = this;
      const dispatchMethods = {
        agent: 'downloadAgentReports',
        label: 'downloadLabelReports',
        inbox: 'downloadInboxReports',
        team: 'downloadTeamReports',
      };
      if (dispatchMethods[type]) {
        const fileName = generateFileName({ type, to, businessHours });
        const params = { from, to, fileName, businessHours };
        if (type === 'label' && this.selectedLabelIds?.length) {
          params.labelIds = this.selectedLabelIds;
        }
        this.$store.dispatch(dispatchMethods[type], params);
      }
    },
    onFilterChange(payload) {
      const { from, to, businessHours, groupBy, comparisonPeriods } = payload;
      this.from = from;
      this.to = to;
      this.businessHours = businessHours;
      this.comparisonPeriods = comparisonPeriods || [];

      if (groupBy) {
        this.groupBy = groupBy;
      } else {
        this.groupBy = GROUP_BY_FILTER[1];
      }

      if (payload.labelIds?.length) {
        this.selectedLabelIds = payload.labelIds;
        const first = this.filterItemsList.find(
          l => l.id === payload.labelIds[0]
        );
        if (first) this.selectedFilter = first;
      } else {
        const filterValue = payload[this.filterType];
        if (filterValue) {
          this.selectedFilter = Array.isArray(filterValue)
            ? filterValue[0]
            : filterValue;
        } else {
          this.selectedFilter = null;
        }
      }

      this.fetchAllData();
    },
  },
};
</script>

<template>
  <ReportHeader :header-title="reportTitle" :has-back-button="hasBackButton">
    <V4Button
      :label="downloadButtonLabel"
      icon="i-ph-file-arrow-down"
      size="sm"
      @click="downloadReports"
    />
  </ReportHeader>

  <ReportFilters
    v-if="filterItemsList"
    :filter-type="filterType"
    :selected-item="selectedFilter"
    :multi-label-filter="type === 'label'"
    :selected-label-ids="selectedLabelIds"
    @update:selected-label-ids="selectedLabelIds = $event"
    @filter-change="onFilterChange"
  />
  <ReportContainer
    v-if="filterItemsList.length"
    :group-by="groupBy"
    :main-from="from"
    :main-to="to"
    :comparison-periods="comparisonPeriods"
    :report-keys="reportKeys"
  />
</template>
