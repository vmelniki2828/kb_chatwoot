<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRouter, useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import ReportsAPI from 'dashboard/api/reports';
import ReportHeader from './components/ReportHeader.vue';
import { messageStamp } from 'shared/helpers/timeHelper';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const route = useRoute();

const agentData = ref(null);
const loading = ref(false);

const userId = computed(() => route.params.id);
const from = computed(() => Number(route.query.from || 0));
const to = computed(() => Number(route.query.to || 0));

const agents = computed(() => store.getters['agents/getAgents'] || []);
const agent = computed(() => agents.value.find(a => String(a.id) === String(userId.value)));

const availabilityMap = {
  online: 'ACCEPTING',
  busy: 'NOT_ACCEPTING',
  offline: 'LOGGED_OUT',
};

function availabilityLabel(apiKey) {
  const key = availabilityMap[String(apiKey || '').toLowerCase()];
  return key ? t(`AGENT_ACTIVITY_REPORT.STATUSES.${key}`) : '—';
}

function availabilityColor(status) {
  if (status === 'online') return '#22c55e';
  if (status === 'busy') return '#eab308';
  return '#64748b';
}

function availabilityBgColor(status) {
  if (status === 'online') return 'rgba(34,197,94,0.1)';
  if (status === 'busy') return 'rgba(234,179,8,0.1)';
  return 'rgba(100,116,139,0.1)';
}

const formatDuration = totalSeconds => {
  const seconds = Number(totalSeconds || 0);
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return `${String(h).padStart(2, '0')}h ${String(m).padStart(2, '0')}m`;
};

const segments = computed(() => agentData.value?.segments || []);

const totals = computed(() => {
  const acc = { accepting: 0, not_accepting: 0, logged_out: 0 };
  segments.value.forEach(s => {
    const dur = Number(s.to || 0) - Number(s.from || 0);
    if (s.availability === 'online') acc.accepting += dur;
    else if (s.availability === 'busy') acc.not_accepting += dur;
    else if (s.availability === 'offline') acc.logged_out += dur;
  });
  return acc;
});

async function fetchDetail() {
  if (!from.value || !to.value || !userId.value) return;
  loading.value = true;
  try {
    const { data } = await ReportsAPI.getAgentActivity({
      from: from.value,
      to: to.value,
      userId: userId.value,
    });
    agentData.value = (data.payload || [])[0] || null;
  } catch {
    useAlert(t('REPORT.DATA_FETCHING_FAILED'));
  } finally {
    loading.value = false;
  }
}

function goBack() {
  router.push({
    name: 'agent_activity_reports',
    params: { accountId: route.params.accountId },
  });
}

onMounted(async () => {
  await store.dispatch('agents/get');
  fetchDetail();
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-center gap-3">
      <button
        class="flex items-center gap-1.5 text-sm text-n-slate-11 transition hover:text-n-slate-12"
        @click="goBack"
      >
        <span>←</span>
        {{ $t('AGENT_ACTIVITY_REPORT.BACK') }}
      </button>
    </div>
    <ReportHeader :header-title="$t('AGENT_ACTIVITY_REPORT.DETAIL_HEADER')" />
    <div v-if="agent" class="flex items-center gap-3 rounded-xl border border-n-weak bg-n-alpha-2 px-4 py-3">
      <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-woot-75 text-sm font-medium text-woot-600">
        {{ agent.name?.slice(0, 2).toUpperCase() }}
      </div>
      <div>
        <p class="mb-0 text-sm font-medium text-n-slate-12">{{ agent.name }}</p>
        <p class="mb-0 text-xs text-n-slate-11">{{ agent.email }}</p>
      </div>
    </div>
    <div v-if="loading" class="flex justify-center py-12 text-n-slate-11 text-sm">
      {{ $t('REPORT.LOADING_CHART') }}
    </div>
    <template v-else-if="agentData">
      <div class="flex flex-wrap gap-x-6 gap-y-2 rounded-xl border border-n-weak bg-n-alpha-2 px-4 py-3 text-sm">
        <span class="flex items-center gap-2">
          <span class="h-2.5 w-2.5 shrink-0 rounded-full" style="background-color: #22c55e" />
          <span class="text-n-slate-11">{{ $t('AGENT_ACTIVITY_REPORT.TOTALS.ACCEPTING') }}</span>
          <span class="font-semibold text-emerald-600 dark:text-emerald-400">{{ formatDuration(totals.accepting) }}</span>
        </span>
        <span class="flex items-center gap-2">
          <span class="h-2.5 w-2.5 shrink-0 rounded-full" style="background-color: #eab308" />
          <span class="text-n-slate-11">{{ $t('AGENT_ACTIVITY_REPORT.TOTALS.NOT_ACCEPTING') }}</span>
          <span class="font-semibold text-amber-600 dark:text-amber-400">{{ formatDuration(totals.not_accepting) }}</span>
        </span>
        <span class="flex items-center gap-2">
          <span class="h-2.5 w-2.5 shrink-0 rounded-full" style="background-color: #64748b" />
          <span class="text-n-slate-11">{{ $t('AGENT_ACTIVITY_REPORT.TOTALS.LOGGED_OUT') }}</span>
          <span class="font-semibold text-slate-500 dark:text-slate-400">{{ formatDuration(totals.logged_out) }}</span>
        </span>
      </div>
      <div class="overflow-x-auto rounded-xl border border-n-weak bg-white dark:bg-n-solid-1">
        <table class="w-full min-w-[600px] text-left text-sm">
          <thead class="border-b border-n-weak bg-n-alpha-2 text-n-slate-11">
            <tr>
              <th class="px-4 py-3 font-medium">{{ $t('AGENT_ACTIVITY_REPORT.COLUMNS.FROM') }}</th>
              <th class="px-4 py-3 font-medium">{{ $t('AGENT_ACTIVITY_REPORT.COLUMNS.TO') }}</th>
              <th class="px-4 py-3 font-medium">{{ $t('AGENT_ACTIVITY_REPORT.COLUMNS.STATUS') }}</th>
              <th class="px-4 py-3 font-medium">{{ $t('AGENT_ACTIVITY_REPORT.COLUMNS.DURATION') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="segment in segments"
              :key="`${segment.from}-${segment.to}-${segment.availability}`"
              class="border-b border-n-weak last:border-0 hover:bg-n-alpha-1 transition"
            >
              <td class="px-4 py-2.5 text-n-slate-12">
                {{ messageStamp(segment.from, 'LLL d, h:mm a') }}
              </td>
              <td class="px-4 py-2.5 text-n-slate-12">
                {{ messageStamp(segment.to, 'LLL d, h:mm a') }}
              </td>
              <td class="px-4 py-2.5">
                <span
                  class="inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium"
                  :style="{
                    backgroundColor: availabilityBgColor(segment.availability),
                    color: availabilityColor(segment.availability),
                  }"
                >
                  <span
                    class="h-1.5 w-1.5 rounded-full"
                    :style="{ backgroundColor: availabilityColor(segment.availability) }"
                  />
                  {{ availabilityLabel(segment.availability) }}
                </span>
              </td>
              <td class="px-4 py-2.5 tabular-nums text-n-slate-12">
                {{ formatDuration(Number(segment.to) - Number(segment.from)) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
    <div
      v-else
      class="rounded-xl border border-n-weak bg-n-alpha-2 px-4 py-10 text-center text-n-slate-11 text-sm"
    >
      {{ $t('AGENT_ACTIVITY_REPORT.EMPTY') }}
    </div>
  </div>
</template>
