<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRouter, useRoute } from 'vue-router';
import { useAlert, useTrack } from 'dashboard/composables';
import ReportsAPI from 'dashboard/api/reports';
import ReportFilters from './components/ReportFilters.vue';
import ReportHeader from './components/ReportHeader.vue';
import AgentActivityTimeline from './components/AgentActivityTimeline.vue';
import { REPORTS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import { messageStamp } from 'shared/helpers/timeHelper';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const route = useRoute();

const agentActivity = ref([]);
const loading = ref(false);
const from = ref(0);
const to = ref(0);
const viewFrom = ref(0);
const viewTo = ref(0);
const selectedUserId = ref('');
const selectedScale = ref('daily');

const HOUR_SECONDS = 60 * 60;
const DAY_SECONDS = 24 * HOUR_SECONDS;
const WEEK_SECONDS = 7 * DAY_SECONDS;
const MONTH_SECONDS_APPROX = 30 * DAY_SECONDS;
const TARGET_TICKS = 6;

const agents = computed(() => store.getters['agents/getAgents'] || []);

const SCALE_TO_SECONDS = {
  hourly: DAY_SECONDS,
  daily: 14 * DAY_SECONDS,
  weekly: 8 * WEEK_SECONDS,
  monthly: 6 * MONTH_SECONDS_APPROX,
};

const availableScales = computed(() => [
  { key: 'hourly', label: t('AGENT_ACTIVITY_REPORT.SCALE.HOURLY') },
  { key: 'daily', label: t('AGENT_ACTIVITY_REPORT.SCALE.DAILY') },
  { key: 'weekly', label: t('AGENT_ACTIVITY_REPORT.SCALE.WEEKLY') },
  { key: 'monthly', label: t('AGENT_ACTIVITY_REPORT.SCALE.MONTHLY') },
]);

const toDate = value => new Date(Number(value || 0) * 1000);
const toTimestamp = date => Math.floor(date.getTime() / 1000);
const clamp = (value, min, max) => Math.min(Math.max(value, min), max);

const startOfHour = value => { const d = toDate(value); d.setMinutes(0, 0, 0); return toTimestamp(d); };
const startOfDay = value => { const d = toDate(value); d.setHours(0, 0, 0, 0); return toTimestamp(d); };
const startOfWeek = value => { const d = toDate(value); const day = (d.getDay() + 6) % 7; d.setDate(d.getDate() - day); d.setHours(0, 0, 0, 0); return toTimestamp(d); };
const startOfMonth = value => { const d = toDate(value); d.setDate(1); d.setHours(0, 0, 0, 0); return toTimestamp(d); };
const addMonths = (timestamp, count) => { const d = toDate(timestamp); d.setMonth(d.getMonth() + count); return toTimestamp(d); };

const visibleWindowSeconds = computed(() => {
  const full = Math.max(1, Number(to.value || 0) - Number(from.value || 0));
  return Math.min(SCALE_TO_SECONDS[selectedScale.value] || full, full);
});

const canMovePrevious = computed(() => viewFrom.value > from.value);
const canMoveNext = computed(() => viewTo.value < to.value);

const syncViewport = ({ anchorToEnd = true } = {}) => {
  const f = Number(from.value || 0);
  const end = Number(to.value || 0);
  if (!f || !end || end <= f) return;
  const range = end - f;
  const window = Math.min(visibleWindowSeconds.value, range);
  const baseEnd = anchorToEnd ? end : clamp(viewTo.value || end, f + window, end);
  viewTo.value = baseEnd;
  viewFrom.value = baseEnd - window;
};

const shiftViewport = direction => {
  const span = Math.max(1, viewTo.value - viewFrom.value);
  const moveBy = Math.max(1, Math.floor(span / 2));
  const f = Number(from.value || 0);
  const end = Number(to.value || 0);
  const targetFrom = clamp(viewFrom.value + direction * moveBy, f, end - span);
  viewFrom.value = targetFrom;
  viewTo.value = targetFrom + span;
};

const resetViewport = () => syncViewport({ anchorToEnd: true });

const onScaleChange = value => {
  selectedScale.value = value;
  syncViewport({ anchorToEnd: false });
};

const pickStep = (target, candidates) =>
  candidates.find(c => c >= target) || candidates[candidates.length - 1];

const timelineResolution = computed(() => {
  const duration = Math.max(1, Number(viewTo.value || 0) - Number(viewFrom.value || 0));
  if (duration <= 2 * DAY_SECONDS) return 'hourly';
  if (duration <= 62 * DAY_SECONDS) return 'daily';
  if (duration <= 370 * DAY_SECONDS) return 'weekly';
  return 'monthly';
});

const timelineStart = computed(() => {
  const start = Math.max(0, Number(viewFrom.value || from.value || 0));
  if (timelineResolution.value === 'hourly') return startOfHour(start);
  if (timelineResolution.value === 'daily') return startOfDay(start);
  if (timelineResolution.value === 'weekly') return startOfWeek(start);
  return startOfMonth(start);
});

const timelineEnd = computed(() => {
  const rawEnd = Math.max(timelineStart.value + 1, Number(viewTo.value || to.value || 0));
  if (timelineResolution.value === 'hourly') return Math.max(rawEnd, startOfHour(rawEnd) + HOUR_SECONDS);
  if (timelineResolution.value === 'daily') return Math.max(rawEnd, startOfDay(rawEnd) + DAY_SECONDS);
  if (timelineResolution.value === 'weekly') return Math.max(rawEnd, startOfWeek(rawEnd) + WEEK_SECONDS);
  return Math.max(rawEnd, addMonths(startOfMonth(rawEnd), 1));
});

const timelineTicks = computed(() => {
  const start = timelineStart.value;
  const end = timelineEnd.value;
  if (!start || !end || end <= start) return [];

  if (timelineResolution.value === 'monthly') {
    const monthSpan = Math.max(1, (end - start) / MONTH_SECONDS_APPROX);
    const stepMonths = pickStep(monthSpan / TARGET_TICKS, [1, 2, 3, 6, 12]);
    const values = [];
    let cursor = startOfMonth(start);
    while (cursor <= end) { values.push(cursor); cursor = addMonths(cursor, stepMonths); }
    if (values[values.length - 1] !== end) values.push(end);
    return values.map((value, index) => ({
      value,
      x: (index / Math.max(values.length - 1, 1)) * 100,
      label: messageStamp(value, 'MMM yyyy'),
    }));
  }

  const baseStep =
    timelineResolution.value === 'hourly'
      ? pickStep((end - start) / TARGET_TICKS, [HOUR_SECONDS, 2 * HOUR_SECONDS, 4 * HOUR_SECONDS, 6 * HOUR_SECONDS, 12 * HOUR_SECONDS, DAY_SECONDS])
      : timelineResolution.value === 'daily'
        ? pickStep((end - start) / TARGET_TICKS, [DAY_SECONDS, 2 * DAY_SECONDS, 3 * DAY_SECONDS, 7 * DAY_SECONDS, 14 * DAY_SECONDS])
        : pickStep((end - start) / TARGET_TICKS, [WEEK_SECONDS, 2 * WEEK_SECONDS, 4 * WEEK_SECONDS, 8 * WEEK_SECONDS]);

  const values = [];
  let cursor = start;
  while (cursor <= end) { values.push(cursor); cursor += baseStep; }
  if (values[values.length - 1] !== end) values.push(end);

  const format = timelineResolution.value === 'hourly' ? 'h a' : 'MMM d';
  return values.map((value, index) => ({
    value,
    x: (index / Math.max(values.length - 1, 1)) * 100,
    label: messageStamp(value, format),
  }));
});

const buildClippedSegments = rawSegments => {
  const start = timelineStart.value;
  const end = timelineEnd.value;
  return (rawSegments || [])
    .map(segment => {
      const clippedFrom = Math.max(Number(segment.from || 0), start);
      const clippedTo = Math.min(Number(segment.to || 0), end);
      return { ...segment, from: clippedFrom, to: clippedTo, duration: Math.max(0, clippedTo - clippedFrom) };
    })
    .filter(s => s.duration > 0);
};

const buildTotals = segments => {
  const totals = { accepting: 0, not_accepting: 0, logged_out: 0 };
  segments.forEach(s => {
    if (s.availability === 'online') totals.accepting += s.duration;
    else if (s.availability === 'busy') totals.not_accepting += s.duration;
    else if (s.availability === 'offline') totals.logged_out += s.duration;
  });
  return totals;
};

const reportRows = computed(() =>
  agentActivity.value.map(row => {
    const segments = buildClippedSegments(row.segments);
    return { ...row, displaySegments: segments, displayTotals: buildTotals(segments) };
  })
);

async function fetchEvents() {
  if (!from.value || !to.value) return;
  loading.value = true;
  try {
    const { data } = await ReportsAPI.getAgentActivity({
      from: from.value,
      to: to.value,
      userId: selectedUserId.value || undefined,
    });
    agentActivity.value = data.payload || [];
  } catch {
    useAlert(t('REPORT.DATA_FETCHING_FAILED'));
    agentActivity.value = [];
  } finally {
    loading.value = false;
  }
}

function onFilterChange({ from: f, to: end }) {
  if (from.value && to.value) {
    useTrack(REPORTS_EVENTS.FILTER_REPORT, {
      filterType: 'date',
      reportType: 'agent_activity',
    });
  }
  from.value = f;
  to.value = end;
  syncViewport({ anchorToEnd: true });
  fetchEvents();
}

function onAgentFilterChange() {
  fetchEvents();
}

function openDetail(userId) {
  router.push({
    name: 'agent_activity_detail',
    params: { accountId: route.params.accountId, id: userId },
    query: { from: from.value, to: to.value },
  });
}

onMounted(() => store.dispatch('agents/get'));
</script>

<template>
  <div class="flex flex-col gap-4">
    <ReportHeader :header-title="$t('AGENT_ACTIVITY_REPORT.HEADER')" />
    <p class="text-sm text-n-slate-11">
      {{ $t('AGENT_ACTIVITY_REPORT.INTRO') }}
    </p>
    <ReportFilters
      :show-entity-filter="false"
      :show-group-by="false"
      :show-business-hours="false"
      :show-comparison="false"
      @filter-change="onFilterChange"
    />
    <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:gap-4">
      <label class="shrink-0 text-sm font-medium text-n-slate-12">
        {{ $t('AGENT_ACTIVITY_REPORT.AGENT_FILTER') }}
      </label>
      <select
        v-model="selectedUserId"
        class="w-full max-w-md rounded-lg border border-n-weak bg-n-alpha-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="onAgentFilterChange"
      >
        <option value="">{{ $t('AGENT_ACTIVITY_REPORT.ALL_AGENTS') }}</option>
        <option v-for="a in agents" :key="a.id" :value="String(a.id)">
          {{ a.name }}
        </option>
      </select>
    </div>
    <p class="text-xs text-n-slate-10">{{ $t('AGENT_ACTIVITY_REPORT.LIMIT_NOTE') }}</p>
    <div v-if="loading" class="flex justify-center py-12 text-sm text-n-slate-11">
      {{ $t('REPORT.LOADING_CHART') }}
    </div>
    <div
      v-else-if="!reportRows.length"
      class="rounded-xl border border-n-weak bg-n-alpha-2 px-4 py-10 text-center text-sm text-n-slate-11"
    >
      {{ $t('AGENT_ACTIVITY_REPORT.EMPTY') }}
    </div>
    <div v-else class="grid gap-3">
      <div
        v-for="row in reportRows"
        :key="row.user_id"
        class="rounded-xl border border-n-weak bg-n-alpha-2 p-4"
      >
        <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
          <div>
            <p class="mb-0 text-sm font-medium text-n-slate-12">{{ row.agent_name }}</p>
            <p class="mb-0 text-xs text-n-slate-11">{{ row.email }}</p>
          </div>
          <button
            class="flex items-center gap-1.5 rounded-lg border border-n-weak px-3 py-1.5 text-xs text-n-slate-11 transition hover:border-n-brand hover:text-n-brand"
            @click="openDetail(row.user_id)"
          >
            {{ $t('AGENT_ACTIVITY_REPORT.DETAILS_BUTTON') }}
            <span class="text-[10px] opacity-60">↗</span>
          </button>
        </div>
        <AgentActivityTimeline
          :segments="row.displaySegments"
          :timeline-start="timelineStart"
          :timeline-end="timelineEnd"
          :timeline-ticks="timelineTicks"
          :user-id="row.user_id"
          :can-move-previous="canMovePrevious"
          :can-move-next="canMoveNext"
          :selected-scale="selectedScale"
          :available-scales="availableScales"
          :display-totals="row.displayTotals"
          @previous="shiftViewport(-1)"
          @next="shiftViewport(1)"
          @reset="resetViewport"
          @scale-change="onScaleChange"
        />
      </div>
    </div>
  </div>
</template>
