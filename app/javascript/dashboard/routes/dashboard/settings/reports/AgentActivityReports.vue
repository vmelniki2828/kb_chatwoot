<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert, useTrack } from 'dashboard/composables';
import ReportsAPI from 'dashboard/api/reports';
import ReportFilters from './components/ReportFilters.vue';
import ReportHeader from './components/ReportHeader.vue';
import { messageStamp } from 'shared/helpers/timeHelper';
import { REPORTS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';

const { t } = useI18n();
const store = useStore();
const agentActivity = ref([]);
const loading = ref(false);
const from = ref(0);
const to = ref(0);
const selectedUserId = ref('');

const agents = computed(() => store.getters['agents/getAgents'] || []);

function availabilityLabel(apiKey) {
  if (!apiKey) {
    return '—';
  }
  const key = String(apiKey).toUpperCase();
  return t(`PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.${key}`);
}

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
  fetchEvents();
}

function onAgentFilterChange() {
  fetchEvents();
}

const formatDuration = totalSeconds => {
  const seconds = Number(totalSeconds || 0);
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return `${String(h).padStart(2, '0')}h ${String(m).padStart(2, '0')}m`;
};

const HOUR_SECONDS = 60 * 60;
const DAY_SECONDS = 24 * HOUR_SECONDS;
const WEEK_SECONDS = 7 * DAY_SECONDS;
const MONTH_SECONDS_APPROX = 30 * DAY_SECONDS;
const TARGET_TICKS = 6;

const pickStep = (target, candidates) =>
  candidates.find(candidate => candidate >= target) || candidates[candidates.length - 1];

const toDate = value => new Date(Number(value || 0) * 1000);
const toTimestamp = date => Math.floor(date.getTime() / 1000);

const startOfHour = value => {
  const date = toDate(value);
  date.setMinutes(0, 0, 0);
  return toTimestamp(date);
};

const startOfDay = value => {
  const date = toDate(value);
  date.setHours(0, 0, 0, 0);
  return toTimestamp(date);
};

const startOfWeek = value => {
  const date = toDate(value);
  const day = (date.getDay() + 6) % 7;
  date.setDate(date.getDate() - day);
  date.setHours(0, 0, 0, 0);
  return toTimestamp(date);
};

const startOfMonth = value => {
  const date = toDate(value);
  date.setDate(1);
  date.setHours(0, 0, 0, 0);
  return toTimestamp(date);
};

const addMonths = (timestamp, count) => {
  const date = toDate(timestamp);
  date.setMonth(date.getMonth() + count);
  return toTimestamp(date);
};

const timelineResolution = computed(() => {
  const duration = Math.max(1, Number(to.value || 0) - Number(from.value || 0));
  if (duration <= 2 * DAY_SECONDS) return 'hourly';
  if (duration <= 62 * DAY_SECONDS) return 'daily';
  if (duration <= 370 * DAY_SECONDS) return 'weekly';
  return 'monthly';
});

const timelineStart = computed(() => {
  const start = Math.max(0, Number(from.value || 0));
  if (timelineResolution.value === 'hourly') return startOfHour(start);
  if (timelineResolution.value === 'daily') return startOfDay(start);
  if (timelineResolution.value === 'weekly') return startOfWeek(start);
  return startOfMonth(start);
});

const timelineEnd = computed(() => {
  const rawEnd = Math.max(timelineStart.value + 1, Number(to.value || 0));
  if (timelineResolution.value === 'hourly') {
    return Math.max(rawEnd, startOfHour(rawEnd) + HOUR_SECONDS);
  }
  if (timelineResolution.value === 'daily') {
    return Math.max(rawEnd, startOfDay(rawEnd) + DAY_SECONDS);
  }
  if (timelineResolution.value === 'weekly') {
    return Math.max(rawEnd, startOfWeek(rawEnd) + WEEK_SECONDS);
  }
  return Math.max(rawEnd, addMonths(startOfMonth(rawEnd), 1));
});

const timelineDuration = computed(() =>
  Math.max(1, timelineEnd.value - timelineStart.value)
);

const buildDisplaySegments = rawSegments => {
  const start = timelineStart.value;
  const end = timelineEnd.value;
  return (rawSegments || [])
    .map(segment => {
      const fromValue = Number(segment.from || 0);
      const toValue = Number(segment.to || 0);
      const clippedFrom = Math.max(fromValue, start);
      const clippedTo = Math.min(toValue, end);
      return {
        ...segment,
        from: clippedFrom,
        to: clippedTo,
        duration: Math.max(0, clippedTo - clippedFrom),
      };
    })
    .filter(segment => segment.duration > 0);
};

const buildDisplayTotals = segments => {
  const totals = { accepting: 0, not_accepting: 0, logged_out: 0 };
  segments.forEach(segment => {
    if (segment.availability === 'online') {
      totals.accepting += segment.duration;
    } else if (segment.availability === 'busy') {
      totals.not_accepting += segment.duration;
    } else if (segment.availability === 'offline') {
      totals.logged_out += segment.duration;
    }
  });
  return totals;
};

const reportRows = computed(() =>
  agentActivity.value.map(row => {
    const segments = buildDisplaySegments(row.segments);
    return {
      ...row,
      displaySegments: segments,
      displayTotals: buildDisplayTotals(segments),
    };
  })
);

const timelineTicks = computed(() => {
  const start = timelineStart.value;
  const end = timelineEnd.value;
  if (!start || !end || end <= start) {
    return [];
  }

  if (timelineResolution.value === 'monthly') {
    const monthSpan = Math.max(1, (end - start) / MONTH_SECONDS_APPROX);
    const stepMonths = pickStep(monthSpan / TARGET_TICKS, [1, 2, 3, 6, 12]);
    const values = [];
    let cursor = startOfMonth(start);

    while (cursor <= end) {
      values.push(cursor);
      cursor = addMonths(cursor, stepMonths);
    }
    if (values[values.length - 1] !== end) {
      values.push(end);
    }

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
  while (cursor <= end) {
    values.push(cursor);
    cursor += baseStep;
  }
  if (values[values.length - 1] !== end) {
    values.push(end);
  }

  const format =
    timelineResolution.value === 'hourly'
      ? 'h a'
      : timelineResolution.value === 'daily'
        ? 'MMM d'
        : 'MMM d';

  return values.map((value, index) => ({
    value,
    x: (index / Math.max(values.length - 1, 1)) * 100,
    label: messageStamp(value, format),
  }));
});

const timelineSegments = segments =>
  (segments || []).map(segment => {
    const start = timelineStart.value;
    const duration = timelineDuration.value;
    const segStart = Number(segment.from || start);
    const segEnd = Number(segment.to || segStart);
    const left = ((segStart - start) / duration) * 100;
    const width = ((segEnd - segStart) / duration) * 100;
    return {
      ...segment,
      left: Math.max(0, Math.min(left, 100)),
      width: Math.max(0.5, Math.min(width, 100)),
      color: availabilityColor(segment.availability),
    };
  });

const tickLabelStyle = (tick, index, total) => {
  if (index === 0) {
    return { left: '0%', transform: 'translateX(0)' };
  }
  if (index === total - 1) {
    return { left: '100%', transform: 'translateX(-100%)' };
  }
  return { left: `${tick.x}%`, transform: 'translateX(-50%)' };
};

function availabilityColor(status) {
  if (status === 'online') {
    return '#16a34a';
  }
  if (status === 'busy') {
    return '#dc2626';
  }
  return '#64748b';
}

onMounted(() => {
  store.dispatch('agents/get');
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <ReportHeader :header-title="$t('AGENT_ACTIVITY_REPORT.HEADER')" />
    <p class="text-n-slate-11 text-sm">
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
      <label class="text-sm font-medium text-n-slate-12 shrink-0">
        {{ $t('AGENT_ACTIVITY_REPORT.AGENT_FILTER') }}
      </label>
      <select
        v-model="selectedUserId"
        class="w-full max-w-md rounded-lg border border-n-weak bg-n-alpha-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="onAgentFilterChange"
      >
        <option value="">
          {{ $t('AGENT_ACTIVITY_REPORT.ALL_AGENTS') }}
        </option>
        <option v-for="a in agents" :key="a.id" :value="String(a.id)">
          {{ a.name }}
        </option>
      </select>
    </div>
    <p class="text-n-slate-10 text-xs">{{ $t('AGENT_ACTIVITY_REPORT.LIMIT_NOTE') }}</p>
    <div
      v-if="loading"
      class="flex justify-center py-12 text-n-slate-11 text-sm"
    >
      {{ $t('REPORT.LOADING_CHART') }}
    </div>
    <div
      v-else-if="!reportRows.length"
      class="rounded-xl border border-n-weak bg-n-alpha-2 px-4 py-10 text-center text-n-slate-11 text-sm"
    >
      {{ $t('AGENT_ACTIVITY_REPORT.EMPTY') }}
    </div>
    <div v-else class="grid gap-4">
      <div
        v-for="row in reportRows"
        :key="row.user_id"
        class="rounded-xl border border-n-weak bg-n-alpha-2 p-4"
      >
        <div class="flex flex-wrap items-center justify-between gap-2">
          <div>
            <p class="mb-0 text-sm font-medium text-n-slate-12">
              {{ row.agent_name }}
            </p>
            <p class="mb-0 text-xs text-n-slate-11">
              {{ row.email }}
            </p>
          </div>
        </div>
        <div class="mt-3 rounded-xl border border-n-weak bg-n-alpha-2 p-4 dark:bg-n-solid-1">
          <div class="mb-3 text-xs font-semibold tracking-wide text-n-slate-11 uppercase">
            {{ $t('AGENT_ACTIVITY_REPORT.TIMELINE.TITLE') }}
          </div>
          <div class="rounded-lg border border-n-weak bg-n-solid-2 p-3 dark:bg-n-solid-3">
            <svg
              viewBox="0 0 100 18"
              class="block h-7 w-full min-w-0"
              preserveAspectRatio="none"
              aria-hidden="true"
            >
              <line x1="0" y1="9" x2="100" y2="9" stroke="#475569" stroke-width="1.2" />
              <line
                v-for="tick in timelineTicks"
                :key="`${row.user_id}-axis-${tick.value}`"
                :x1="tick.x"
                y1="5"
                :x2="tick.x"
                y2="13"
                stroke="#64748b"
                stroke-width="0.35"
              />
              <line
                v-for="segment in timelineSegments(row.displaySegments)"
                :key="`${row.user_id}-bar-${segment.from}-${segment.to}`"
                :x1="segment.left"
                y1="9"
                :x2="Math.min(segment.left + segment.width, 100)"
                y2="9"
                :stroke="segment.color"
                stroke-width="3"
                stroke-linecap="butt"
              />
            </svg>
            <div class="relative mt-2 h-8 overflow-hidden">
              <span
                v-for="(tick, index) in timelineTicks"
                :key="`${row.user_id}-tick-${tick.value}`"
                class="absolute top-0 text-[11px] font-medium leading-tight text-slate-400 whitespace-nowrap"
                :style="tickLabelStyle(tick, index, timelineTicks.length)"
              >
                {{ tick.label }}
              </span>
            </div>
          </div>
          <div class="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs">
            <span class="flex items-center gap-1">
              <span class="h-2 w-2 rounded-full bg-emerald-500" />
              <span class="text-emerald-500" style="color: #10b981">
                {{ $t('AGENT_ACTIVITY_REPORT.TOTALS.ACCEPTING') }}:
              </span>
              <span class="font-medium text-emerald-500" style="color: #10b981">
                {{ formatDuration(row.displayTotals.accepting) }}
              </span>
            </span>
            <span class="flex items-center gap-1 text-red-500">
              <span class="h-2 w-2 rounded-full bg-red-600" />
              {{ $t('AGENT_ACTIVITY_REPORT.TOTALS.NOT_ACCEPTING') }}:
              {{ formatDuration(row.displayTotals.not_accepting) }}
            </span>
            <span class="flex items-center gap-1 text-slate-500">
              <span class="h-2 w-2 rounded-full bg-slate-500" />
              {{ $t('AGENT_ACTIVITY_REPORT.TOTALS.LOGGED_OUT') }}:
              {{ formatDuration(row.displayTotals.logged_out) }}
            </span>
          </div>
        </div>
        <div class="mt-3 overflow-x-auto rounded-lg border border-n-weak bg-white dark:bg-n-solid-1">
          <table class="w-full min-w-[660px] text-left text-sm">
            <thead class="border-b border-n-weak bg-n-alpha-2 text-n-slate-11">
              <tr>
                <th class="px-3 py-2 font-medium">{{ $t('AGENT_ACTIVITY_REPORT.COLUMNS.FROM') }}</th>
                <th class="px-3 py-2 font-medium">{{ $t('AGENT_ACTIVITY_REPORT.COLUMNS.TO') }}</th>
                <th class="px-3 py-2 font-medium">{{ $t('AGENT_ACTIVITY_REPORT.COLUMNS.STATUS') }}</th>
                <th class="px-3 py-2 font-medium">{{ $t('AGENT_ACTIVITY_REPORT.COLUMNS.DURATION') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="segment in row.displaySegments"
                :key="`${row.user_id}-${segment.from}-${segment.to}-${segment.availability}`"
                class="border-b border-n-weak last:border-0"
              >
                <td class="px-3 py-2 text-n-slate-12">
                  {{ messageStamp(segment.from, 'LLL d, h:mm a') }}
                </td>
                <td class="px-3 py-2 text-n-slate-12">
                  {{ messageStamp(segment.to, 'LLL d, h:mm a') }}
                </td>
                <td class="px-3 py-2 text-n-slate-12">
                  {{ availabilityLabel(segment.availability) }}
                </td>
                <td class="px-3 py-2 text-n-slate-12">
                  {{ formatDuration(segment.duration) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>
